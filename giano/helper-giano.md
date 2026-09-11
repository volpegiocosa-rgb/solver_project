# helper-giano.md — Manuale utente di `giano.m` v1.0.0

> STATO: implementazione completa (Gate 1-7, rif. `giano-design.md`).
> Manca solo il packaging dello zip di release e la compilazione dei
> `.mexw64` su una macchina Windows con MATLAB (nessun MATLAB Windows
> disponibile in fase di sviluppo) — non necessaria per l'uso: `giano.m`
> funziona comunque tramite il percorso interpretato Octave/MATLAB, vedi
> più sotto.

## Cos'è

`giano.m` è la funzione di interfaccia che permette di richiamare
solver_project v3.0.0 (ottimizzatore CMA-ES+ARCH o DE+Deb, con o senza la
procedura di continuazione a stadi) e il simulatore TSTO da dentro un altro
programma Matlab, **senza che `giano.m` legga o scriva alcun file**. Tutti
i dati vanno passati come struct Matlab già costruite in memoria dal
programma chiamante.

## Come chiamarla

```matlab
out = giano(cfg);
```

Un solo argomento di ingresso (`cfg`), un solo struct di uscita (`out`).

## Requisiti

- Octave o MATLAB 2025a+ (MATLAB 2026b sulla macchina target dichiarata).
- Il path deve includere: `giano/` (questa cartella), la root di
  `solver_project` (`solver.m`, `solver_de.m`), `core/`, `constraints/`,
  `io/`, `de/`, `TSTO/source/` e `TSTO/source/native/`. Esempio:

```matlab
here = fileparts(mfilename('fullpath'));   % cartella del tuo script
addpath(fullfile(here, 'solver_project'));
addpath(fullfile(here, 'solver_project', 'giano'));
addpath(fullfile(here, 'solver_project', 'core'));
addpath(fullfile(here, 'solver_project', 'constraints'));
addpath(fullfile(here, 'solver_project', 'io'));
addpath(fullfile(here, 'solver_project', 'de'));
addpath(fullfile(here, 'solver_project', 'TSTO', 'source'), '-end');
addpath(fullfile(here, 'solver_project', 'TSTO', 'source', 'native'), '-end');
```

L'ordine `-end` su `TSTO/source` è importante: evita una collisione di
nome nota (`init_state.m`, presente sia in `core/` che, storicamente, in
`TSTO/source/` — oggi risolta spostando la versione TSTO in
`TSTO/source/private/`, ma l'ordine resta la convenzione sicura).

## Campi di `cfg`

Ogni file CSV che la pipeline originale leggeva da disco diventa qui una
sub-struct di `cfg`; ogni **riga** del CSV diventa un **campo nominato**
della sub-struct (accesso per nome, l'ordine con cui i campi vengono
assegnati in Matlab non ha alcuna importanza). **`giano.m` non legge mai
questi valori da un file**: è il programma chiamante a doverli fornire
già come struct, in qualunque modo preferisca costruirli (CSV proprio,
database, UI, valori letterali).

### Sub-struct "fisiche" (stesso contenuto dei CSV di `TSTO/input/<dataset>`)

| Sub-struct | Campi | Nota |
|---|---|---|
| `cfg.LV` | `Sref Mfairing M0 Minert1 Minert2 MProp1 MProp2 Thrust1 Thrust2 MR1 MR2 Aexit1 Aexit2 n_engine1 n_engine2 Mpayload` | valori per singolo motore; `Mpayload` qui è il nominale, sovrascritto da `cfg.design_variables.Mpayload` |
| `cfg.ENV` | `Req Rpole f omega_E mu lat lon hpad` | |
| `cfg.atmosphere` | `altitude PAtm rho Vsound` | vettori colonna, stessa lunghezza |
| `cfg.aero_ascent` | `Mach AoA Cd` | `Mach`/`AoA` vettori, `Cd` matrice `Cd(Mach,AoA)` |
| `cfg.GUID` | `AZ timeHS_Sep_control flux_HS_Sep` | |
| `cfg.GUIDANCE_VARS` | `zkick pitch_over_starting pitch_c1 pitch_c2 transition_starting pitch_rate_transition pitch_at_transition insertion_starting AoA_rate plane_controller_kp plane_controller_kd plane_controller_ki` | baseline "pristine"; `plane_controller_kd/ki` e `pitch_at_transition` NON sono variabili di design e restano fissi a questi valori |
| `cfg.MIS` | `apogee_altitude_target perigee_altitude_target target_orbital_inclination` | |

### `cfg.design_variables` — variabili di ricerca

Struct con **esattamente** questi 10 campi (contratto fisso con
`TSTO/source/traj_problem.m`, accesso per nome):

```
zkick, pitch_over_starting, pitch_c1, pitch_c2, transition_starting,
pitch_rate_transition, insertion_starting, AoA_rate,
plane_controller_kp, Mpayload
```

Ciascun campo è una struct con `.x0 .lb .ub` (e opzionalmente `.unit`,
solo documentale — la conversione gradi→radianti sulle 4 componenti
angolari, `pitch_c1/pitch_c2/pitch_rate_transition/AoA_rate`, è dedotta
automaticamente dal NOME del campo, non da `.unit`). Esempio:

```matlab
cfg.design_variables.zkick = struct('x0', 120, 'lb', 20, 'ub', 180, 'unit', 'm');
cfg.design_variables.Mpayload = struct('x0', 4000, 'lb', 4000, 'ub', 30000, 'unit', 'kg');
```

### `cfg.opts` — ottimizzatore, continuazione, log

| Campo | Significato | Obbligatorio |
|---|---|---|
| `solver_choice` | `1` = CMA-ES+ARCH (default) &#124; `2` = DE+Deb | no |
| `mode` | `'single'` &#124; `'continuation'` | no (default `'single'`) |
| `tol_con` | vettore 3x1 **assoluto** (perigeo, apogeo, inclinazione) | **sì**, sempre (TSTO ha sempre 3 vincoli di uguaglianza) |
| `seed`, `verbose`, `log_level` (0-3) | riproducibilità e diagnostica | no (default: seed=1/1, verbose=0, log_level=0) |
| `max_iter`, `max_eval`, `max_time`, `tol_fun`, `tol_x`, `sigma0`, `init_mode`, `multistart`, `restart_ipop`, `max_restarts`, `restart_mode`, `restart_jitter`, `polish_opt` | opzioni CMA-ES+ARCH | no, default calibrati (rif. `io/parse_opts.m`) |
| `pop_size`, `F`, `CR` | opzioni DE (solo se `solver_choice=2`) | no, default euristici (rif. `io/parse_opts_de.m`) |
| `n_stage`, `stage_eval`, `stage_iter`, `vary_seed`, `explore_every`, `back_off`, `ratio_guess`, `ratio_safety`, `push_max`, `bisect_tol`, `bisect_max`, `min_gain`, `patience`, `x0_retreat` | opzioni continuazione (solo se `mode='continuation'`) | no, default presi da `real_case/optimizer_settings.csv` |
| `tmax_phase`, `tmin`, `tmax`, `step_frac` | passthrough al simulatore TSTO (durata max per fase, passo min/max dell'integratore cinematico `rk5.m`) | no, default interni di `simulator.m` |

`log_level` governa `out.opt_log`: `0` = niente, `1` = un record per
valutazione (`f`, tempo), `2`/`3` = come 1 + (`x`, vincoli, propellente
residuo). Più alto è più pesante in memoria su run lunghi.

### `cfg.warm_state` (opzionale)

Solo per `mode='continuation'`. Alla prima chiamata si omette (o `[]`).
`giano.m` restituisce in `out.warm_state` lo stato aggiornato: sta al
programma chiamante deciderne la persistenza (workspace, file proprio,
database) e ripassarlo in `cfg.warm_state` alla chiamata successiva per
proseguire il ratchet — `giano.m` stessa non tocca mai il disco.

## Campi di `out`

| Campo | Contenuto |
|---|---|
| `out.RES` | traiettoria completa del punto migliore (`TSTO/interface_specification.md` §3, tutti i campi `theTimes/theMass/theApogeeAltitude/...`). `[]` solo se `mode='continuation'` e nessun punto è mai risultato feasible. |
| `out.opt_log` | diagnostica del processo, dettaglio secondo `cfg.opts.log_level`; in `mode='continuation'` ogni record ha anche un campo `.stage` (0=seed, 1..N=stadio, -1=verifica finale) |
| `out.x_best` | struct con i 10 campi di `cfg.design_variables` al punto migliore |
| `out.f_best`, `out.Mpayload` | obiettivo (`f_best = -Mpayload`) |
| `out.feasible` | per-vincolo, entro `cfg.opts.tol_con` |
| `out.n_eval` | totale valutazioni (in continuazione: seed + tutti gli stadi + verifica finale) |
| `out.n_iter` | `mode='single'`: generazioni del motore. `mode='continuation'`: numero di STADI eseguiti |
| `out.n_restarts` | `mode='single'`: restart IPOP del motore. `mode='continuation'`: `[]` (nessun totale univoco significativo, ogni stadio ha i propri — dettaglio in `out.stage_log`) |
| `out.stop_reason` | motivo di arresto |
| `out.stage_log` | SOLO `mode='continuation'`: matrice Sx6, una riga per stadio = `[stadio, lb_payload, x0_payload, payload_stadio, payload_dopo_push, feasible]` |
| `out.warm_state` | stato del ratchet aggiornato (solo `mode='continuation'`, altrimenti `[]`) |
| `out.giano_version` | `'1.0.0'` |

## Esempio completo

Esempio minimo, single-run CMA-ES+ARCH, con i valori REALI del dataset
`TSTO/input/validation_test_2` (lanciatore a due stadi tipo Falcon 9,
usato per tutta la validazione di questo toolbox — rif.
`giano-design.md`), qui trascritti come struct invece che letti da CSV.
In un uso reale, questi valori arriveranno dal tuo programma (CSV,
database, UI): qui sono letterali solo per rendere l'esempio
autosufficiente e VERIFICATO (eseguito, non solo scritto: converge a
`Mpayload≈19697 kg`, `feasible=1`, con budget sufficiente).

```matlab
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
% cfg.design_variables sotto, che per le stesse 4 grandezze usa i gradi,
% rif. tabella sopra). plane_controller_kd/ki e pitch_at_transition
% restano fissi a questi valori per tutta l'ottimizzazione.
cfg.GUIDANCE_VARS = struct('zkick', 120, 'pitch_over_starting', 10, ...
    'pitch_c1', -1.0e-4, 'pitch_c2', -1.0e-2, 'transition_starting', 30, ...
    'pitch_rate_transition', 5.0e-3, 'pitch_at_transition', 1.4, ...
    'insertion_starting', 200, 'AoA_rate', 1.0e-3, ...
    'plane_controller_kp', 0.5, 'plane_controller_kd', 0.1, 'plane_controller_ki', 0.01);

cfg.MIS = struct('apogee_altitude_target', 400000, ...
    'perigee_altitude_target', 400000, 'target_orbital_inclination', 0.49741883);

% design_variables: le 4 componenti angolari (pitch_c1/pitch_c2/
% pitch_rate_transition/AoA_rate) sono qui in GRADI (rif. tabella sopra).
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

out = giano(cfg);

fprintf('Mpayload = %.1f kg (feasible=%d)\n', out.Mpayload, out.feasible);
fprintf('Apogeo raggiunto = %.1f m\n', out.RES.theApogeeAltitude(end));
```

Eseguito con questi valori esatti: `feasible=1`, `Mpayload=16607.2 kg`,
`Apogeo raggiunto = 400000.0 m` (centra il target). Non è il tetto fisico
del lanciatore (misurato altrove, con budget più ampio o con
`mode='continuation'`, oltre i 19000 kg): a `max_eval=2000` è un buon
punto feasible, non un ottimo a convergenza.

Per la **continuazione** (ricerca del payload massimo per push successivi,
eventualmente su più chiamate):

```matlab
cfg.opts.mode      = 'continuation';
cfg.opts.n_stage   = 8;
cfg.opts.stage_eval = 2500;

out1 = giano(cfg);                    % prima chiamata: nessun warm_state
% ... salva out1.warm_state dove preferisci (workspace, file tuo, ecc.) ...

cfg.warm_state = out1.warm_state;     % seconda chiamata: riparte da li'
out2 = giano(cfg);
```

## Uso su Windows / MATLAB 2026b — nota sul fast-path nativo

La release include `tsto_native.dll` e i sorgenti shim MEX ma **non** i
`.mexw64` compilati (nessun MATLAB Windows disponibile in fase di
sviluppo). `giano.m` funziona comunque **senza alcun passo aggiuntivo**,
tramite il percorso interpretato Octave/MATLAB (più lento, corretto).

Per il fast-path nativo (molto più veloce, misurato ~150-400x sulle
singole funzioni fisiche nella build Linux equivalente), su Windows con
MATLAB 2026b, dalla cartella `TSTO/source/native/`:

```matlab
mex -setup C++   % una tantum, scegliere MinGW-w64
mex eom_mex.cpp libtsto_native.dll.a -output eom_native
mex phase_event_mex.cpp libtsto_native.dll.a -output phase_event_native
mex tsto_phases16_mex.cpp libtsto_native.dll.a -output tsto_phases16_native
```

Istruzioni complete (incluso il caso Visual Studio) in
`TSTO/source/native/WINDOWS_MEX_BUILD.md`, incluso nello zip di release.
`simulator.m` rileva automaticamente i `.mexw64` compilati (stesso
meccanismo già usato per i `.oct` su Octave/Linux): nessuna modifica a
`giano.m` necessaria dopo la compilazione.

## Errori comuni

| Identificativo | Causa |
|---|---|
| `giano:noConfig` | `cfg` mancante o non è una struct |
| `giano:missingField` | manca una delle sub-struct obbligatorie di primo livello di `cfg` |
| `giano:missingDesignVariable` | `cfg.design_variables` non contiene tutti e 10 i campi attesi (per nome esatto) |
| `giano:badDesignVariable` | un campo di `cfg.design_variables` non ha `.x0`/`.lb`/`.ub` |
| `giano:badDesignVariableBounds` | `lb > ub` per una variabile di design |
| `giano:missingTolCon` | `cfg.opts.tol_con` assente |
| `giano:badTolCon` | `cfg.opts.tol_con` non ha 3 componenti, o ne ha di ≤0 |
| `giano:badSolverChoice` | `cfg.opts.solver_choice` diverso da 1 o 2 |
| `giano:badMode` | `cfg.opts.mode` diverso da `'single'`/`'continuation'` |

Tutti gli errori includono un messaggio esplicito con il campo/valore
incriminato: nessun default silenzioso su ciò che altera il risultato
numerico (rif. `giano-design.md`, principio applicato in tutto il
progetto).
