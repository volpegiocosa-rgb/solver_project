% DRIVER_GIANO  Esempio eseguibile di chiamata a giano.m (v1.0.0).
%
%   Caso Falcon 9-like (stessi valori REALI del dataset TSTO/input/
%   validation_test_2 usato per tutta la validazione di questo toolbox,
%   rif. giano-design.md), identico all'esempio di helper-giano.md --
%   qui come script eseguibile invece che come blocco di codice nel
%   manuale, cosi' chi scompatta la release ha subito qualcosa da
%   lanciare senza dover ricopiare nulla a mano.
%
%   Eseguito e verificato: feasible=1, Mpayload=16607.2 kg, apogeo
%   400000.0 m (centra il target) con budget max_eval=2000.
%
%   Uso: lanciare da Octave/MATLAB con questo file come working
%   directory (o comunque senza spostarlo dalla cartella giano/ del
%   pacchetto scompattato) -- il path viene impostato qui sotto in
%   automatico, nessuna configurazione manuale necessaria:
%     driver_giano
%
%   NOTA (coerente con CON-001, rif. giano-design.md): questo driver
%   legge/scrive file SOLO per impostare il path (addpath) -- giano.m
%   stessa, chiamata sotto, non legge ne' scrive nulla. cfg e' costruita
%   qui per intero da valori letterali, esattamente come dovrebbe fare
%   il programma chiamante nel proprio codice (rif. helper-giano.md,
%   sezione "Esempio completo", per la spiegazione campo per campo).

here = fileparts(mfilename('fullpath'));      % .../solver_project/giano
root = fullfile(here, '..');                  % .../solver_project

addpath(root);
addpath(here);
addpath(fullfile(root, 'core'));
addpath(fullfile(root, 'constraints'));
addpath(fullfile(root, 'io'));
addpath(fullfile(root, 'de'));
addpath(fullfile(root, 'TSTO', 'source'), '-end');
addpath(fullfile(root, 'TSTO', 'source', 'native'), '-end');

% === cfg: valori REALI del dataset validation_test_2 (Falcon 9-like) ===
cfg = struct();

cfg.LV = struct('Sref', 10.52, 'Mfairing', 1900, 'M0', 550000, ...
    'Minert1', 25600, 'Minert2', 4000, 'MProp1', 411000, 'MProp2', 107500, ...
    'Thrust1', 981000, 'Thrust2', 981000, 'MR1', 321.7, 'MR2', 287.5, ...
    'Aexit1', 0.665, 'Aexit2', 7.07, 'n_engine1', 9, 'n_engine2', 1, ...
    'Mpayload', 2000);

cfg.ENV = struct('Req', 6378137.0, 'Rpole', 6356752.314245, ...
    'f', 0.0033528106647475, 'omega_E', 7.292115e-5, 'mu', 3.986004418e14, ...
    'lat', 0.49850721, 'lon', -1.40631231, 'hpad', 0.0);

% atmosphere/aero_ascent: nel tuo programma tipicamente da tabelle CSV
% (US Standard Atmosphere 1976 per atmosphere, polare Cd(Mach,AoA) per
% aero_ascent); qui gli stessi valori reali del dataset di validazione.
alt = [0 1000 2000 5000 8000 11000 15000 20000 25000 30000 40000 50000 60000 80000 100000]';
cfg.atmosphere = struct('altitude', alt, ...
    'PAtm',   [101325.000 89874.568 79495.211 54019.904 35599.802 22632.060 ...
               12044.567 5474.889 2511.023 1171.866 277.521 75.945 20.314 0.886 0.018]', ...
    'rho',    [1.224999 1.111642 1.006490 0.736115 0.525167 0.363918 0.193674 ...
               0.088035 0.039466 0.018012 0.003851 0.000978 0.000288 0.000016 0.0000004]', ...
    'Vsound', [340.29 336.43 332.53 320.53 308.06 295.07 295.07 295.07 298.46 ...
               301.80 317.63 329.80 314.07 281.12 250.91]');
cfg.aero_ascent = struct('Mach', [0.0 0.5 0.8 1.0 1.2 2.0 3.0 5.0]', 'AoA', [0 2 5 10 15], ...
    'Cd', [0.30 0.31 0.34 0.42 0.55; 0.28 0.29 0.33 0.41 0.54; 0.30 0.32 0.36 0.45 0.60; ...
           0.55 0.57 0.62 0.73 0.90; 0.60 0.62 0.67 0.78 0.96; 0.45 0.47 0.51 0.61 0.76; ...
           0.35 0.37 0.41 0.50 0.64; 0.28 0.30 0.33 0.41 0.53]);

cfg.GUID = struct('AZ', 1.5707963, 'timeHS_Sep_control', 180, 'flux_HS_Sep', 1135);

% GUIDANCE_VARS: baseline "pristine" -- gia' in radianti (a differenza di
% cfg.design_variables sotto, che per le stesse 4 grandezze usa i gradi).
% plane_controller_kd/ki e pitch_at_transition restano fissi a questi
% valori per tutta l'ottimizzazione.
cfg.GUIDANCE_VARS = struct('zkick', 120, 'pitch_over_starting', 10, ...
    'pitch_c1', -1.0e-4, 'pitch_c2', -1.0e-2, 'transition_starting', 30, ...
    'pitch_rate_transition', 5.0e-3, 'pitch_at_transition', 1.4, ...
    'insertion_starting', 200, 'AoA_rate', 1.0e-3, ...
    'plane_controller_kp', 0.5, 'plane_controller_kd', 0.1, 'plane_controller_ki', 0.01);

cfg.MIS = struct('apogee_altitude_target', 400000, ...
    'perigee_altitude_target', 400000, 'target_orbital_inclination', 0.49741883);

% design_variables: le 4 componenti angolari (pitch_c1/pitch_c2/
% pitch_rate_transition/AoA_rate) sono qui in GRADI (rif. helper-giano.md).
cfg.design_variables.zkick                 = struct('x0', 120, 'lb', 20,   'ub', 180);
cfg.design_variables.pitch_over_starting   = struct('x0', 10,  'lb', 5,    'ub', 40);
cfg.design_variables.pitch_c1              = struct('x0', -1,  'lb', -2.5, 'ub', -0.2);
cfg.design_variables.pitch_c2              = struct('x0', 0,   'lb', -1,   'ub', 0);
cfg.design_variables.transition_starting   = struct('x0', 30,  'lb', 5,    'ub', 60);
cfg.design_variables.pitch_rate_transition = struct('x0', 0,   'lb', 0,    'ub', 2.5);
cfg.design_variables.insertion_starting    = struct('x0', 200, 'lb', 5,    'ub', 300);
cfg.design_variables.AoA_rate              = struct('x0', 0,   'lb', -5,   'ub', 5);
cfg.design_variables.plane_controller_kp   = struct('x0', 0.5, 'lb', 0.25, 'ub', 0.75);
cfg.design_variables.Mpayload              = struct('x0', 4000, 'lb', 4000, 'ub', 30000);

cfg.opts = struct();
% assoluti: 3% dei target di missione (perigeo/apogeo [m], inclinazione [rad])
cfg.opts.tol_con = 0.03 * [cfg.MIS.perigee_altitude_target; ...
                            cfg.MIS.apogee_altitude_target; ...
                            cfg.MIS.target_orbital_inclination];
cfg.opts.seed      = 1;
cfg.opts.log_level = 1;
cfg.opts.max_eval  = 2000;

fprintf('Lancio giano() -- single-run CMA-ES+ARCH, max_eval=%d...\n', cfg.opts.max_eval);
out = giano(cfg);

fprintf('\n=== risultato ===\n');
fprintf('Mpayload    = %.1f kg\n', out.Mpayload);
fprintf('feasible    = %d\n', out.feasible);
fprintf('n_eval      = %d\n', out.n_eval);
fprintf('stop_reason = %s\n', out.stop_reason);
fprintf('Apogeo raggiunto       = %.1f m   (target %.1f m)\n', ...
    out.RES.theApogeeAltitude(end), cfg.MIS.apogee_altitude_target);
fprintf('Perigeo raggiunto      = %.1f m   (target %.1f m)\n', ...
    out.RES.thePerigeeAltitude(end), cfg.MIS.perigee_altitude_target);
fprintf('Inclinazione raggiunta = %.6f rad (target %.6f rad)\n', ...
    out.RES.theInclination(end), cfg.MIS.target_orbital_inclination);

% === plot pitch / AoA / incidence vs tempo, con confini di fase =========
% Confini di fase presi da theGuidFlag (fonte di verita', non un valore
% temporale assunto): una linea verticale tratteggiata per ogni cambio di
% fase, etichettata col numero di fase in cui si entra.
t     = out.RES.theTimes;
phase = out.RES.theGuidFlag;
pitch_deg = rad2deg(out.RES.thePitch);
aoa_deg   = rad2deg(out.RES.theAOA);
inc_deg   = rad2deg(out.RES.theIncidence);

phase_change_idx = find([true; diff(phase(:)) ~= 0]);

figure();

% xline() non e' disponibile in Octave (§2 CLAUDE.md: compatibilita'
% doppia Octave+MATLAB): confini di fase disegnati con line() + text(),
% funzionano identici su entrambe le piattaforme.
subplot(3,1,1);
plot(t, pitch_deg, '-');
hold on;
yl = [min(pitch_deg), max(pitch_deg)];
for k = 1:numel(phase_change_idx)
    i = phase_change_idx(k);
    line([t(i) t(i)], yl, 'LineStyle', '--', 'Color', 'k');
    text(t(i), yl(2), sprintf('%d', phase(i)), 'VerticalAlignment', 'top');
end
hold off;
ylabel('pitch [deg]');
title('Pitch, AoA, incidence vs tempo (linee tratteggiate = cambio fase, etichetta = fase entrante)');
grid on;

subplot(3,1,2);
plot(t, aoa_deg, '-');
hold on;
yl = [min(aoa_deg), max(aoa_deg)];
for k = 1:numel(phase_change_idx)
    line([t(phase_change_idx(k)) t(phase_change_idx(k))], yl, 'LineStyle', '--', 'Color', 'k');
end
hold off;
ylabel('AoA [deg]');
grid on;

subplot(3,1,3);
plot(t, inc_deg, '-');
hold on;
yl = [min(inc_deg), max(inc_deg)];
for k = 1:numel(phase_change_idx)
    line([t(phase_change_idx(k)) t(phase_change_idx(k))], yl, 'LineStyle', '--', 'Color', 'k');
end
hold off;
xlabel('t [s]');
ylabel('incidence [deg]');
grid on;
