% MAIN  Entry point per l'utente finale: lancia l'ottimizzazione del caso
%   reale TSTO (lanciatore a due stadi, Falcon 9-like) con la
%   configurazione che ha raggiunto `feasible=1` in sessione (rif.
%   CLAUDE.md S11 Fase 5, run "requisito 5 minuti", 2026-09-06).
%
%   STATO DEL PROGETTO (onesto, release 0.1.0): il porting Fortran della
%   simulazione (source/native/ in TSTO) ha reso ogni valutazione ~150-
%   400x piu' veloce, ma il floor di valutazioni necessario per trovare
%   un punto feasible su questo problema (~200000, misurato) resta
%   troppo alto per il requisito applicativo di un'ottimizzazione
%   completa in ≤5 minuti sul PC target. Questo script riproduce
%   l'ULTIMO run riuscito (feasible=1 raggiunto), NON un run da 5 minuti:
%   **il tempo atteso e' dell'ordine di alcune ore** (misurato in
%   sessione: ~3h30m su una macchina di sviluppo Intel N100 a basso
%   consumo -- probabilmente piu' veloce sulla macchina target, ma
%   comunque non minuti). Vedi CLAUDE.md §11 Fase 5 per l'analisi
%   completa e le opzioni di sviluppo future (parallelizzazione della
%   popolazione, principale leva rimasta).
%
%   PREREQUISITI:
%   - Octave (testato su 9.4.0) con il pacchetto di sviluppo installato
%     (Debian/Ubuntu: `sudo apt install octave-dev gfortran`) per
%     compilare i kernel nativi in TSTO/source/native/ (vedi il README
%     in quella cartella). Senza compilazione lo script funziona
%     comunque ma ricade sulle funzioni Octave interpretate, ~150-400x
%     piu' lento (il run da ore diventa un run da giorni).
%   - Nient'altro: TSTO e' incluso in questo repository (cartella TSTO/,
%     vendorizzata via git subtree da https://github.com/volpegiocosa-rgb/TSTO)
%     -- un singolo clone/download di questa release contiene tutto.
%
%   USO:
%       octave main.m
%   (oppure `octave --no-gui main.m` per evitare la GUI, se installata)
%
%   OUTPUT: stampa a schermo f_best (=-Mpayload), feasible, n_eval,
%   n_iter, n_restarts, stop_reason a fine run (vedi solver.m per il
%   significato dei campi di 'result').

here = fileparts(mfilename('fullpath'));

% --- 1. Path: core generico del solver + adapter/dati del caso reale ---
addpath(here);
addpath(fullfile(here, 'core'));
addpath(fullfile(here, 'constraints'));
addpath(fullfile(here, 'io'));
addpath(fullfile(here, 'real_case'));

% --- 2. TSTO: inclusa in questo repository (vedi PREREQUISITI) ---
tsto_dir = fullfile(here, 'TSTO');
if ~isfolder(tsto_dir)
    error('main:noTsto', [ ...
        'Cartella TSTO non trovata in %s.\n' ...
        'Questa cartella dovrebbe essere inclusa nel repository/release ' ...
        '(vendorizzata da https://github.com/volpegiocosa-rgb/TSTO) -- ' ...
        'verifica di aver scaricato il codice sorgente completo, non solo main.m.'], tsto_dir);
end
addpath(fullfile(tsto_dir, 'source'), '-end');
addpath(fullfile(tsto_dir, 'source', 'native'), '-end');

if exist('eom_native', 'file') ~= 3
    warning('main:noNativeKernel', [ ...
        'Kernel Fortran compilato non trovato (TSTO/source/native/*.oct).\n' ...
        'La simulazione ricadra'' sulle funzioni Octave interpretate: ' ...
        'corretto ma ~150-400x piu'' lento (vedi TSTO/source/native/README.md ' ...
        'per compilarlo con mkoctfile).']);
end

% --- 3. Variabili di design, bounds, tolleranze: da design_variables.csv
%        e dal dataset TSTO nominale (reference_LV) -- stessa logica di
%        real_case/run_feasibility_floor_probe.m. ---
tsto_input_dir = fullfile(tsto_dir, 'input', 'reference_LV');
other = interface(tsto_input_dir);

n_design = 10;
csv_path = fullfile(here, 'real_case', 'design_variables.csv');
fid = fopen(csv_path, 'r');
if fid < 0
    error('main:noCsv', 'Impossibile aprire %s.', csv_path);
end
fgetl(fid);   % scarta la riga di intestazione
x_nom = zeros(n_design, 1);
lb    = zeros(n_design, 1);
ub    = zeros(n_design, 1);
row = 0;
while true
    line = fgetl(fid);
    if ~ischar(line)
        break;
    end
    line = strtrim(line);
    if isempty(line)
        continue;
    end
    row = row + 1;
    tok = strsplit(line);
    x_nom(row) = str2double(tok{4});
    lb(row)    = str2double(tok{5});
    ub(row)    = str2double(tok{6});
end
fclose(fid);
if row ~= n_design
    error('main:badCsv', ...
          '%s: attese %d righe dati, trovate %d.', csv_path, n_design, row);
end

bounds.lb = lb;
bounds.ub = ub;
other.opt_bounds.lb = lb;
other.opt_bounds.ub = ub;

% --- 4. Opzioni: budget ampio (nessun vincolo di 5 minuti, vedi header)
%        -- stesso identico seed/tol_con del run che ha raggiunto
%        feasible=1 in sessione. ---
opts = struct();
opts.other    = other;
opts.x0       = x_nom;
opts.max_time = Inf;
opts.seed     = 1;
opts.verbose  = 2;   % traccia iter/f_best/sigma/lambda/n_restarts

opts.tol_con = 0.03 * [other.MIS.perigee_altitude_target; ...
                        other.MIS.apogee_altitude_target; ...
                        other.MIS.target_orbital_inclination];

opts.max_eval = 200000;   % rif. header: ~3h30m su macchina di sviluppo

% --- 5. Lancio ---
fprintf('Avvio ottimizzazione TSTO (budget max_eval=%d, nessun limite di tempo).\n', opts.max_eval);
fprintf('Tempo atteso: ore, non minuti (vedi header di main.m). In corso...\n\n');

result = solver(@traj_cost, bounds, opts);

fprintf('\n=== RISULTATO ===\n');
fprintf('f_best (=-Mpayload) = %.6g  ->  Mpayload = %.6g kg\n', result.f_best, -result.f_best);
fprintf('feasible = %d\n', result.feasible);
fprintf('n_eval = %d  n_iter = %d  n_restarts = %d  stop_reason = %s\n', ...
    result.n_eval, result.n_iter, result.n_restarts, result.stop_reason);
