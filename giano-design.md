# giano-design.md — Contratto e piano di sviluppo per `giano.m` v1.0.0

> Documento di progetto prodotto dalla skill `leggi-specifica` a partire da
> `road-to-3-1-0.md`. Contratto + piano a gate, come richiesto dalla
> specifica ("ogni punto è un gate che necessita la mia approvazione") e
> da CLAUDE.md §0 (una fase per sessione, conferma ai gate).
>
> **Stato avanzamento**: Gate 1 ✅, Gate 2 ✅, Gate 3 ✅ completati.
> - Gate 1: `giano/giano.m` con firma e contratto completo, validazione di
>   forma di `cfg` funzionante, `giano/helper-giano.md` bozza.
> - Gate 2: `giano/private/giano_build_other.m` (porting di
>   `TSTO/source/interface.m` a input-struct, zero file I/O). Verificato
>   **bit-esatto** (`isequaln`) contro `interface.m` sui 3 dataset TSTO
>   (`reference_LV`, `validation_test`, `validation_test_2`) con uno
>   script di verifica usa-e-getta (non incluso nel pacchetto, CON-002).
> - Gate 3: `giano/private/giano_design_var_order.m` (fonte unica
>   dell'ordine fisico a 10 variabili, condivisa fra la validazione in
>   `giano.m` e l'assemblaggio in `giano_build_design_vectors.m`) +
>   `giano/private/giano_build_design_vectors.m` (assembla x0/lb/ub per
>   NOME, deriva `ang_idx`/`i_payload` per nome — H3/H4/H10 risolti) +
>   validazione esplicita di `cfg.opts.tol_con` in `giano.m` (H1: nessun
>   default 3% implicito). Verificato: valori numerici identici
>   all'attuale `real_case/design_variables.csv`, **indipendenza
>   dall'ordine di assegnazione dei campi** dimostrata (struct con campi
>   in ordine invertito produce lo stesso output), guardia `lb>ub`
>   funzionante.
>
> - Gate 4: `giano/private/giano_eval_log.m` (accumulatore in memoria,
>   macchina a stati reset/append/get, stesso pattern `persistent` già
>   usato da `real_case/traj_cost.m` ma senza alcun file) +
>   `giano/private/giano_traj_cost.m` (porting di `real_case/traj_cost.m`:
>   clip ai bounds + conversione deg→rad via `other.opt_bounds`/
>   `other.ang_idx`, wrapper a 3 output su `traj_problem.m`, log
>   per-valutazione a verbosità configurabile via `other.log_level`).
>   Verificato end-to-end sul dataset reale `validation_test_2`
>   (TSTO nativo compilato): output identico a una chiamata diretta di
>   `traj_problem.m` sullo stesso punto, `opt_log` accumula 2 record
>   consecutivi con `eval_id` corretti e reset funzionante, **zero
>   differenze nell'intero albero del repository prima/dopo la chiamata**
>   (confrontato con `find`+`diff`) anche a `log_level=2`.
>
> - Gate 5a (sotto-tappa di Gate 5): `giano.m` completato per
>   `mode='single'` + `solver_choice=1` (CMA-ES+ARCH) — collega
>   `giano_build_other`/`giano_build_design_vectors`/`giano_traj_cost` a
>   `solver.m`, zero valori cablati (`bounds`/`opts` derivati interamente
>   da `cfg`). Combinazioni `mode='continuation'` e `solver_choice=2`
>   ancora respinte con `giano:notImplemented` (Gate 5b/5c).
>   **Verificato end-to-end sul simulatore TSTO reale** (dataset
>   `validation_test_2`, fast-path nativo, budget 60 eval): risultato
>   plausibile e coerente con la storia del progetto (`Mpayload=12235 kg`,
>   `feasible=1`, stesso ordine di grandezza del run "brute-force 12000
>   eval" già documentato in CLAUDE.md), run completo in 0.39s,
>   riproducibilità a parità di seed confermata su due chiamate separate,
>   **zero differenze nell'intero repository prima/dopo** un run reale
>   completo (non solo una singola valutazione come in Gate 4).
>
> - Gate 5b (sotto-tappa di Gate 5): aggiunto `solver_choice=2` (DE+Deb,
>   `solver_de.m`) — stesso wrapper/bounds/assemblaggio di `out` di Gate
>   5a, nessuna duplicazione di logica (`solver.m`/`solver_de.m`
>   condividono contratto e forma di `result` per costruzione).
>   Validazione esplicita di `solver_choice` (1|2, errore chiaro
>   altrimenti). `mode='continuation'` ancora respinto (Gate 5c).
>   **Verificato**: CMA-ES+ARCH invariato rispetto a Gate 5a (nessuna
>   regressione dal refactor), DE+Deb produce un run feasible reale
>   (`Mpayload=14359 kg`) sullo stesso dataset, `solver_choice` non
>   valido e `mode='continuation'` respinti con errori chiari, **zero
>   differenze filesystem** sull'intera suite di test (2 run reali + 2
>   percorsi d'errore).
>
> - Gate 5c: spezzato in 3 sotto-tappe (richiesta utente): **5c-1**
>   predictor-corrector "push-to-wall", **5c-2** corpo di un singolo
>   stadio, **5c-3** loop multi-stadio + `cfg.warm_state`/`out.warm_state`.
> - Gate 5c-1 ✅: `giano/private/giano_ratio_tsiolkovsky.m` (porting 1:1
>   di `local_ratio_tsiolkovsky`), `giano/private/giano_eval_feasibility.m`
>   (porting di `local_eval`, usa `giano_traj_cost` invece di
>   `real_case/traj_cost.m`) e `giano/private/giano_push_to_wall.m`
>   (porting 1:1 di `local_push_to_wall`). `giano_traj_cost.m` esteso con
>   un 4° output opzionale `prop_residual` (innocuo per `solver.m`/
>   `solver_de.m`, che ne richiedono solo 3). **Verificato**: sul dataset
>   reale, spinto dal nominale (Mpayload=4000 kg feasible) il predittore
>   converge a **19697.3 kg feasible**, con un punto +250 kg oltre
>   risultato infeasible — in linea, in modo indipendente, con il muro
>   fisico già misurato con uno sweep 1-D in una sessione precedente
>   (CLAUDE.md: "feasible fino a 19600 kg, primo infeasible a 19800").
>   Zero file I/O confermato.
>
> - Gate 5c-2 ✅: `giano/private/giano_continuation_stage.m` — corpo di
>   UN SOLO stadio (porting del corpo del `for s=1:n_stage` in
>   `real_case/run_continuation.m`, righe 184-321), function pura
>   (nessuna stampa a console, nessun I/O): riceve lo stato del ratchet
>   PRIMA dello stadio, lancia `engine` (`@solver`/`@solver_de`, Gate
>   5a/5b) sul budget dello stadio, valuta feasibility, applica
>   `giano_push_to_wall` (Gate 5c-1), aggiorna stallo/patience/ratchet, e
>   restituisce lo stato aggiornato + un flag `stopped`/`why` per il loop
>   chiamante (Gate 5c-3).
>   **Verificato con 4 scenari mirati** (engine reale sostituito da un
>   mock deterministico per isolare la logica di orchestrazione da quella
>   stocastica del motore, già validata in Gate 5a/5b): (A) punto
>   infeasible restituito dal motore → `stopped=1, why=no_feasible`,
>   stato completamente invariato; (B) punto feasible dal nominale →
>   push-to-wall converge a **19697.3 kg**, identico bit-per-bit al
>   risultato indipendente di Gate 5c-1, ratchet (`lb_pl`/`x_warm`)
>   aggiornato secondo le formule attese; (C) `ub` stretto (4200 kg) →
>   `stopped=1, why=ub_reached` esattamente alla soglia attesa; (D)
>   `best_pl` pre-impostato sopra il risultato raggiungibile, `n_stall`
>   preimpostato a `patience-1` → `stopped=1, why=patience` al terzo
>   stallo, nessun aggiornamento spurio di `best_pl`. Zero differenze
>   filesystem sull'intera suite.
>
> - Gate 5c-3 ✅ (chiude Gate 5c e l'intero Gate 5): creati
>   `giano/private/giano_stage_vec.m` (porting di `local_stage_vec`) e
>   `giano/private/giano_run_continuation.m` — orchestratore del loop
>   multi-stadio: seeding iniziale da `cfg.warm_state` (rivalutato per
>   feasibility, non semplicemente fidato), loop su `giano_continuation_stage`
>   (Gate 5c-2), raccolta di `stage_log`/`opt_log` (ogni record taggato
>   `.stage` — 0=seed, 1..n=stadio, -1=verifica finale — perche'
>   `giano_eval_log` si resetta ad ogni fase), verifica finale, esito in
>   `out.warm_state` (`[]` se non c'e' nulla di feasible da persistere).
>   `giano.m` collegato per `mode='continuation'`: default dei parametri
>   di continuazione presi da `real_case/optimizer_settings.csv`
>   (dichiarati, non nascosti), validazione esplicita di `cfg.opts.mode`.
>   **Verificato end-to-end sul simulatore reale** (2 chiamate separate,
>   budget minimo 2 stadi × 30 eval): RUN 1 (nessun `warm_state`) converge
>   a **Mpayload=19697.3 kg feasible** — lo stesso muro fisico già
>   cross-validato indipendentemente in Gate 5c-1/5c-2 — con `stage_log`
>   2×6 e `opt_log` correttamente taggato per fase; RUN 2, ripartendo dal
>   `warm_state` di RUN 1, non perde mai terreno (19697.5 kg) e costa
>   meno tempo (0.44s contro 0.79s). **Nessuna regressione**: `mode='single'`
>   restituisce lo stesso identico `f_best=-12235.4` di Gate 5a/5b,
>   `mode` non valido respinto con errore chiaro. **Zero differenze
>   filesystem** sull'intera suite (2 run reali di continuazione + 1 run
>   di regressione + 1 percorso d'errore).
>
> **Gate 5 (motore di ottimizzazione, tutte le sotto-tappe) COMPLETATO.**
>
> - Gate 6 ✅: `giano/private/giano_prepare_x.m` (clip+deg2rad estratto
>   da `giano_traj_cost.m` in un helper condiviso, per garantire che la
>   ri-simulazione veda ESATTAMENTE lo stesso punto valutato durante
>   l'ottimizzazione), `giano/private/giano_build_other_run.m` (porting
>   deliberatamente duplicato della sezione 1 di
>   `TSTO/source/traj_problem.m`, dichiarato: quel file non espone il
>   passo separatamente e non va modificato, essendo esterno) e
>   `giano/private/giano_full_res.m` (chiama `TSTO/source/simulator.m`
>   DIRETTAMENTE con `config.minimal_output=false` — mai usato durante il
>   loop principale, rif. H8 — e `config.silent=true`, necessario:
>   verificato leggendo `simulator.m` che altrimenti richiamerebbe
>   `plotter.m`/`write_log.m`, che SCRIVONO file). Collegato in `giano.m`
>   in entrambe le modalità (`[]` in continuazione se nessun punto e' mai
>   stato certificato feasible).
>   **Verificato sul simulatore reale**: `out.RES` ha tutti i campi attesi
>   da `interface_specification.md` §3 (`theTimes`, `theMass`,
>   `theApogeeAltitude`, `thePerigeeAltitude`, `theInclination`,
>   `funzione_costo`, `theGuidFlag`, ...); i residui calcolati
>   INDIPENDENTEMENTE da `RES` (target − `RES.theX(end)`) combaciano con
>   i `ceq` usati durante l'ottimizzazione a meno di ~1 mm (perigeo
>   0.49 mm, apogeo 1.47 mm, inclinazione 2.22e-16 rad) — stesso punto,
>   nessuna discrepanza fra il percorso di ottimizzazione e quello di
>   ri-simulazione. Testato anche il caso limite (`mode='continuation'`,
>   nessuno stadio, nessun seed) → `out.RES=[]` come da contratto. **Zero
>   differenze filesystem** sull'intera suite (inclusi i percorsi che
>   avrebbero potuto invocare `plotter.m`/`write_log.m`).
>
> - Gate 7 ✅ (assemblaggio finale): chiuso un gap trovato rileggendo il
>   codice, non solo per completare la documentazione — `cfg.opts.
>   tmax_phase/AbsTol/RelTol/tmin/tmax/step_frac` (H11) erano promessi
>   nell'header di `giano.m` fin dal Gate 1 ma MAI effettivamente
>   inoltrati a `traj_problem.m`/`simulator.m`. Cablato ora: `other.STEP.
>   frac` (letto direttamente da `kinematic_step.m`) e `other.sim_opts`
>   (passthrough a `traj_problem.m` in `giano_traj_cost.m`, e a
>   `simulator.m` in `giano_full_res.m`) — nessun campo impostato se il
>   chiamante non li fornisce, invariato altrimenti. Verificato: default
>   espliciti (`tmax_phase=1000`, `tmin=0.05`, `tmax=2`, `step_frac=0.05`,
>   identici agli interni di `simulator.m`) producono lo STESSO
>   `f_best`/RES di non impostarli affatto.
>   Aggiornato l'header "STATO" di `giano.m` (era ancora fermo al
>   placeholder di Gate 1). Completato `giano/helper-giano.md`: tabella
>   `out.*` con le sfumature per-modalità, elenco completo degli errori
>   con identificativo, ed **esempio end-to-end eseguito riga per riga**
>   (non solo scritto) con i valori REALI del dataset
>   `validation_test_2` (prima bozza aveva numeri fisici inventati e
>   produceva `feasible=0`/quota negativa — scartata dopo averla
>   eseguita, non pubblicata senza verifica): risultato `feasible=1`,
>   `Mpayload=16607.2 kg`, apogeo esattamente sul target.
>   **Regressione completa** (Gate 5a/5c-3/6) ri-eseguita dopo le
>   modifiche: nessun cambiamento nei risultati numerici già certificati.
>   Zero differenze filesystem su tutta la sessione.
>
> **`giano.m` v1.0.0 è funzionalmente completo.**
>
> - Pulizia post-Gate-7 (richiesta utente, "AbsTol/RelTol sono usati
>   realmente?"): confermato con grep mirato su `TSTO/source` che
>   **`AbsTol`/`RelTol` non sono mai letti da `simulator.m`** (unico
>   consumatore) dopo la sostituzione di `ode45` con `rk5.m` — `traj_problem.m`
>   li accetta e li inoltra solo per compatibilità con vecchi chiamanti,
>   ma non hanno più alcun effetto. Rimossi dal passthrough di `giano.m`
>   (erano promessi ma innocui/inutili); `tmax_phase/tmin/tmax/step_frac`
>   restano, questi sì effettivamente consumati. Sweep di pulizia su
>   tutti i 15 file di `giano/` (`giano.m` + 14 file in `private/`):
>   rimossa una soppressione `%#ok<ASGLU>` diventata stale (i 5 output di
>   `giano_build_design_vectors` sono TUTTI usati da quando Gate 5c ha
>   cablato `i_payload`), corretto un riferimento a un file di test mai
>   creato nel pacchetto (`giano_build_other.m`). Nessun'altra variabile
>   morta trovata. **Rieseguita l'intera regressione** (Gate 5a, DE, RES,
>   sim_opts): stessi identici risultati numerici di prima, zero
>   differenze filesystem.
>
> - Gate 8 ✅ (validazione end-to-end più ampia, suite unica): oltre alle
>   combinazioni già esercitate gate per gate, testate per la prima
>   volta: **3 chiamate consecutive concatenate via `warm_state`** in
>   `mode='continuation'` (non solo 2 come in Gate 5c-3) e la
>   combinazione **`mode='continuation'` + `solver_choice=2` (DE+Deb)**,
>   mai esercitata prima. Aggiunto anche un test con `cfg.warm_state`
>   deliberatamente infeasible (payload noto oltre il muro fisico),
>   per verificare il fallback cold-start senza crash.
>   **Risultati**: single/CMA-ES `Mpayload=16607.2 kg` — **identico**
>   all'esempio di `helper-giano.md` (stesso seed, conferma
>   determinismo cross-sessione); single/DE+Deb `15781.2 kg`;
>   continuation/CMA-ES su 3 chiamate concatenate **18344.1 → 22044.1 →
>   24652.7 kg**, monotono, l'ultimo valore a **meno di 3 kg** dal
>   miglior risultato mai certificato in tutta la storia del progetto
>   (24655.3 kg, CLAUDE.md "RELEASE 2.0.0") — conferma indipendente che
>   il porting in memoria riproduce la stessa qualità del meccanismo
>   originale su file; continuation/DE+Deb (nuova combinazione)
>   `17345.1 kg` feasible su entrambe le chiamate; `warm_state`
>   infeasible gestito senza eccezioni, fallback cold-start corretto.
>   **Zero differenze filesystem** sull'intera suite (~35s di
>   ottimizzazione reale combinata sul simulatore nativo).
>
> - Gate 9 ✅ (packaging): contenuto dello zip derivato da un'analisi di
>   dipendenza reale (non "a occhio"): grafo delle chiamate fra i file di
>   `TSTO/source` ricostruito con grep mirato, poi **verificato
>   eseguendo** — non solo ragionando — `giano.m` da una copia isolata
>   contenente SOLO il sottoinsieme proposto, senza alcun fallback verso
>   il resto del repository di sviluppo e **senza `TSTO/source/native`
>   sul path** (così si esercita anche il percorso interpretato puro,
>   lo stesso che un utente Windows avrebbe prima di compilare i
>   `.mexw64`): nessun errore "undefined function", conferma che il
>   fallback dichiarato in `helper-giano.md` funziona davvero, non solo
>   a parole.
>   **Composizione finale (80 file, ~514 KB)**: `giano/` (16: `giano.m`,
>   `helper-giano.md`, 14 in `private/`) + motore `solver_project`
>   (`solver.m`, `solver_de.m`, `core/`, `constraints/`, `io/`, `de/` —
>   29, esclusa `de/de_smoke_test.m`) + fisica TSTO (26 file `.m` di
>   `TSTO/source` + `TSTO/source/private/init_state.m`, esclusi
>   `interface.m`/`main.m`/`run_simulator.m`/`write_output_csv.m`/
>   `plotter.m`/`write_log.m` — non necessari al percorso di `giano.m`,
>   i primi tre sono CLI/demo, gli altri tre non vengono mai invocati
>   perché `giano.m` imposta sempre `config.silent=true`) + fast-path
>   Windows (8: `tsto_native.dll` + `libtsto_native.dll.a`, scaricati
>   dall'asset della release GitHub `v2.1.0` già esistente; i 3 sorgenti
>   shim MEX; `tsto_native.h`/`.def`; `WINDOWS_MEX_BUILD.md` — **nessun
>   `.mexw64`**, per GAP-001). Esclusi per costruzione (CON-002): tutto
>   `real_case/`, `benchmark/`, `external/`, `results/`, `TSTO/input`,
>   `TSTO/output`, `TSTO/docs`, i `.md` di documentazione TSTO,
>   `validate_tsto_native.m`, `test_standalone*`, `eom_core.f90` (sorgente
>   Fortran: non serve per usare la DLL già compilata).
>   Zip pronto in locale, **non ancora pubblicato**: la pubblicazione è
>   Gate 10, azione visibile pubblicamente, da confermare a parte.
>
> - Gate 10 ✅ (release GitHub): commit `7c03eb4` (18 file: `giano/`,
>   `giano-design.md`, `road-to-3-1-0.md`) pushato su `main`; release
>   `v3.1.0` pubblicata con l'asset
>   `giano-1.0.0-solver_project-3.1.0.zip` (80 file, 514176 byte).
>   URL: https://github.com/volpegiocosa-rgb/solver_project/releases/tag/v3.1.0
>
> **PIANO COMPLETATO (Gate 1-10, tutti verdi).**
>
> - Addendum post-release (richiesta utente): `helper-giano.md` ampliato
>   con il significato semantico di ogni campo di `cfg` (unità + cosa
>   rappresenta fisicamente), ripreso da `TSTO/interface_specification.md`
>   §2 e `TSTO/CLAUDE.md` §8 — nessuna delle due incluse nello zip, quindi
>   trascritto qui perché resti disponibile a chi ha solo il pacchetto
>   pubblicato. Nel farlo, corretta anche un'incoerenza residua
>   nell'esempio (un vecchio valore `Mpayload≈19697 kg`, mai aggiornato
>   dopo la correzione successiva a `16607.2 kg`, rimasto in un paragrafo
>   diverso da quello già corretto).
> - Aggiunto `giano/driver_giano.m` (richiesta utente): stesso esempio di
>   `helper-giano.md` (caso Falcon 9-like) ma come script eseguibile,
>   path auto-configurato rispetto alla propria posizione — chi scompatta
>   la release ha subito qualcosa da lanciare. Eseguito e verificato:
>   stesso risultato esatto già certificato (`Mpayload=16607.2 kg`,
>   `feasible=1`, apogeo/perigeo/inclinazione esattamente sul target),
>   zero differenze filesystem.
> - Zip di release **ricostruito e ri-pubblicato** sullo stesso tag
>   `v3.1.0` (asset sostituito, nessun nuovo tag: 0 download registrati
>   prima della sostituzione, correzioni nella stessa sessione di
>   pubblicazione) — 81 file, `driver_giano.m` incluso.

---

## Sintesi esecutiva

`road-to-3-1-0.md` chiede un toolbox informale (`giano.m` v1.0.0) che
impacchetti il solver 3.0.0 + TSTO per l'uso in un programma Matlab più
grande su Windows 10 / MATLAB 2026b, senza alcuna lettura/scrittura su file
da parte della function stessa. Dopo ricognizione completa della pipeline
reale (`solver.m`, `real_case/traj_cost.m`, `real_case/run_real_case.m`,
`real_case/run_continuation.m`, `TSTO/source/interface.m`,
`traj_problem.m`) e 4 domande di architettura risolte con l'utente, lo
scope è fissato: **tutte le funzionalità attuali** (entrambi i solver,
entrambe le modalità single-run/continuation), **un unico struct
aggregatore** come firma (ogni CSV diventa una struct/sub-struct, ogni riga
del CSV un campo nominato — non serve conoscere l'ordine delle righe),
**RES completo + log a verbosità variabile** come output, **zip senza
`.mexw64` compilati** (nessun MATLAB Windows disponibile in questo
ambiente).

---

## Perimetro e obiettivi

- **Dentro**: `giano.m` (v1.0.0) + subfunction, porting **senza I/O su
  file** della pipeline CMA-ES+ARCH / DE+Deb / continuation-ratchet già
  validata in `real_case/`, `helper-giano.md`, asset zip per release
  GitHub `v3.1.0`.
- **Fuori (per ora)**: qualunque nuova funzionalità di ottimizzazione non
  già presente in 3.0.0; compilazione reale dei `.mexw64` (nessun MATLAB
  Windows disponibile in questo ambiente — vedi GAP-001).

---

## Requisiti normalizzati

| ID | Requisito | Stato |
|---|---|---|
| FR-001 | `giano.m` espone in un'unica chiamata **tutte** le funzionalità di 3.0.0: CMA-ES+ARCH e DE+Deb, modalità single-run e continuation-ratchet | chiaro |
| FR-002 | Firma: un unico struct aggregatore `cfg`. Ogni CSV attuale diventa una struct/sub-struct di `cfg`; ogni **riga** del CSV diventa un **campo nominato** della struct (es. `cfg.design_variables.zkick.x0/.lb/.ub`, non una tabella posizionale) | chiaro |
| FR-003 | Output: `RES` completo (interface_specification.md §3) sul punto migliore + log di processo a verbosità configurabile (`opt_log`) | chiaro |
| CON-001 | `giano.m` non legge né scrive file | chiaro sul principio; risolto per il lato lettura da FR-002, per il lato scrittura serve un meccanismo di stato esplicito per la continuation (vedi H12) |
| CON-002 | Package sintetico: no test/doc/validazione nello zip | chiaro |
| INT-001 | Output conforme a `TSTO/interface_specification.md` §3 (`RES`) | chiaro, ma oggi `RES` completo è **disattivato** durante l'ottimizzazione (`config.minimal_output=true`) — serve una ri-simulazione finale sul best (H8) |
| DAT-001 | 7 struct TSTO (`LV, ENV, atmosphere, aero_ascent, GUID, GUIDANCE_VARS, MIS`) + `design_variables` (per-nome, non per-riga) + `opts` (solver+continuation+log) | chiaro |
| VER-001 | Piano deve includere validazione | chiaro, dettagliata sotto |
| ASM-001 | Target: Windows 10, MATLAB 2026b — mai testato (dev machine ha solo R2025a non licenziato) | dichiarato, non verificabile in questo ambiente |
| GAP-001 | `.mexw64` reali non esistono in nessuna release precedente (v2.1.0 lo dichiara esplicitamente) | **risolto per decisione utente**: zip senza `.mexw64`, con DLL+sorgenti+istruzioni; fallback interpretato Octave/MATLAB già funzionante e verificato |

---

## Ambiguità, TBD e conflitti — audit degli hardcoded

Tutti i 4 conflitti architetturali bloccanti sono stati chiusi dalle
risposte dell'utente. Resta l'audit dei valori oggi cablati nella pipeline
reale, richiesto esplicitamente ("se c'è ancora qualcosa di hardcoded,
dimmelo e se necessario lo passiamo in input"):

| ID | Hardcoded oggi | Dove | Proposta |
|---|---|---|---|
| H1 | `tol_con = 0.03 * target` (3% magic number) | `run_real_case.m` | diventa `cfg.opts.tol_con` esplicito (vettore assoluto), obbligatorio |
| H2 | `n_design = 10` | `run_real_case.m`, `optimizer_settings.csv` | derivato da `numel(fieldnames(cfg.design_variables))`, non più un settaggio da tenere sincronizzato a mano |
| H3 | `i_payload = 10` | `optimizer_settings.csv` (predittore Tsiolkovsky) | risolto per costruzione da FR-002: si accede a `cfg.design_variables.Mpayload` **per nome**, nessun indice da cercare |
| H4 | `ang_idx = [3,4,6,8]` (colonne deg→rad) | `traj_cost.m` | derivato scorrendo i campi di `cfg.design_variables` e convertendo quelli il cui `unit` inizia per `deg` — per nome, non per posizione |
| H5 | `dataset = 'validation_test_2'` (path CSV) | `optimizer_settings.csv` | **superato per costruzione**: con input a struct il concetto di "dataset" sparisce, è implicito nei valori di `cfg.MIS/ENV/...` |
| H6 | `other.log_level = 1` fisso | `run_real_case.m` | diventa `cfg.opts.log_level` (0-3), rediretto a `opt_log` in memoria invece che a `eval_log.csv` |
| H7 | `max_time=Inf`, `seed=1`, `verbose=1` fissi | `run_real_case.m` | tutti passano da `cfg.opts.*`, nessun valore fisso in `giano.m` |
| H8 | `config.minimal_output=true` sempre attivo durante l'ottimizzazione → mai prodotto `RES` completo | `traj_problem.m` | **nuova implementazione**: ri-simulazione finale (`minimal_output=false`) sul solo punto migliore, per soddisfare INT-001 |
| H9 | `plane_controller_kd/ki` fissi al nominale (non in `x`) | `traj_problem.m` | non è un magic number di progetto, è già una decisione documentata; il nominale arriva comunque da `cfg.GUIDANCE_VARS` (input, non cablato) |
| H10 | Mapping variabili di design → `other.GUI.*` | `traj_problem.m` / adapter `giano.m` | **RISOLTO dal chiarimento utente**: ogni riga CSV è un campo nominato di `cfg.design_variables` (es. `cfg.design_variables.zkick`, `cfg.design_variables.pitch_c1`, ...). `giano.m` costruisce il vettore `x` con **lookup esplicito per nome** (`x0 = [cfg.design_variables.zkick.x0; cfg.design_variables.pitch_over_starting.x0; ...]`), non leggendo righe in un ordine presunto. Non serve alcuna validazione ordine↔indice: se un campo manca, MATLAB solleva un errore "campo non definito" immediato e leggibile — l'ordine del CSV originale non ha più alcun ruolo. *(Nota residua, non bloccante: `traj_problem.m` internamente scrive ancora `x(1)=zkick, x(2)=...` per indice fisso — è `giano.m`, non `traj_problem.m`, che deve garantire che l'ordine con cui assembla il vettore `x` rispetti quel contratto fisso; questo è un dettaglio implementativo del Gate 3, non un'ambiguità di progetto.)* |
| H11 | `tmin/tmax` RK5, `other.STEP.frac`, `AbsTol/RelTol` legacy | `simulator.m`/`traj_problem.m` | `tmax_phase/tmin/tmax/step_frac` esposti come campi opzionali di `cfg.opts` (default = attuali), cablati in Gate 7. **`AbsTol`/`RelTol` ESCLUSI** (correzione Gate 7, richiesta utente "sono usati realmente?"): verificato con grep su `TSTO/source` che sono forwarded da `traj_problem.m` in `config.AbsTol/RelTol` ma **mai letti** da `simulator.m` (unico consumatore) dopo la sostituzione di `ode45` con `rk5.m`, integratore a passo cinematico fisso, non a controllo d'errore — esporli in `giano.m` sarebbe un'opzione senza alcun effetto |
| H12 | `warm_start.mat` persiste il ratchet **tra chiamate separate** dello script | `run_continuation.m` | per rispettare CON-001: `giano.m` accetta un `cfg.warm_state` opzionale in ingresso e restituisce `out.warm_state` in uscita — il chiamante decide come/se persisterlo (file, workspace, DB), `giano.m` non tocca mai il disco. Preserva la funzionalità cross-sessione senza violare il vincolo |

Nessun altro hardcoding rilevante trovato in `solver.m`/`core`/`constraints`/`io`
(motore generico, dimension-agnostic per costruzione, CLAUDE.md §1 già lo
garantisce).

---

## Scaffolding applicato o proposto

Non ancora creato nulla: il progetto ha già una struttura propria e
consolidata (`core/constraints/io/benchmark/real_case/TSTO`), incompatibile
con lo scaffold generico `docs/input/output/source` della skill — non
forzato. Proposta minima, non distruttiva, da applicare al **Gate 1**:

```
solver_project/
└── giano/                     ← NUOVO
    ├── giano.m                 entry point, v1.0.0
    ├── private/                subfunction interne (adapter struct→other, wrapper obiettivo, ratchet in-memory)
    ├── helper-giano.md
    └── package/                script di confezionamento zip (non nello zip stesso)
```

Nessun file esistente spostato o modificato in questa fase.

---

## Matrice di routing

| Requisiti | Attività | Esito | Skill/Agente | Input | Artefatto | Verifica |
|---|---|---|---|---|---|---|
| FR-002, DAT-001 | Porting `interface.m` a input-struct (per-nome) | CORE | — | Read/Edit su `TSTO/source/interface.m` | `giano/private/giano_build_other.m` | round-trip identico a `interface.m` sui 3 dataset |
| H1-H4,H8,H10 | Audit fix + RES completo | CORE | — | file sopra | `giano/private/*` | unit check + regressione numerica |
| FR-001 | Port CMA-ES+ARCH / DE+Deb / continuation senza file I/O | CORE | — | `solver.m`,`solver_de.m`,`run_continuation.m` | `giano.m` | smoke test 4 combinazioni motore×modalità |
| CON-001 | Verifica "zero file I/O" | CORE (Bash) | — | `giano.m` | report | diff prima/dopo directory, o cartella read-only |
| GAP-001 | Packaging Windows senza `.mexw64` | CORE | — | `TSTO/source/native/*` | zip asset | contenuto rivisto dall'utente (Gate 9) |
| — | Compilazione `.mexw64` reale | GAP | nessuna capability disponibile (no MATLAB Windows in questo ambiente) | — | — | rimandata al Windows target dell'utente |
| Release | `gh release create v3.1.0` | CORE (Bash `gh`) | — | zip pronto | release pubblica | conferma esplicita utente (azione visibile a terzi) |

---

## Piano di esecuzione per gate

**Gate 1 — Scaffolding + firma** (basso costo): creazione `giano/`,
header/docstring completo di `giano.m` (firma `out = giano(cfg)` con ogni
campo di `cfg` documentato, incluso il formato "struct per-nome" di
`design_variables`) e scheletro di `helper-giano.md`. Nessuna logica
ancora.

**Gate 2 — Adapter struct→other**: porting di `interface.m`; verifica
bit-esatta contro l'originale sui 3 dataset TSTO esistenti (letti via
script di test, non da `giano.m`).

**Gate 3 — Design variables + audit fix**: adapter per `design_variables`
(lookup per nome, non per riga — risolve H10), derivazione dinamica
H2/H3/H4, `tol_con` esplicito (H1).

**Gate 4 — Wrapper obiettivo senza file I/O**: porta `traj_problem.m` →
`[f,cineq,ceq]`, accumulo `opt_log` in memoria a verbosità configurabile
(0-3, stessa semantica di oggi).

**Gate 5 — Motore CMA-ES+ARCH / DE+Deb / continuation in-memory**: la fase
più grande — porta `run_continuation.m` rimuovendo `save/load` su
`warm_start.mat`, sostituendo con `cfg.warm_state`/`out.warm_state` (H12).

**Gate 6 — RES completo sul best**: ri-simulazione finale (H8).

**Gate 7 — Assemblaggio `giano.m` + `helper-giano.md`**: entry point
unico, validazione input, manuale utente completo (inclusa nota sul passo
`mex` opzionale una tantum su Windows).

**Gate 8 — Validazione end-to-end** (su questa macchina Octave): 4
combinazioni motore×modalità, regressione adapter, verifica "zero
scritture su disco" durante una chiamata, verifica `warm_state` round-trip
su 2+ chiamate consecutive simulate. **Limite dichiarato**: nessun test
possibile su MATLAB 2026b/Windows reale da qui.

**Gate 9 — Packaging zip**: contenuto rivisto insieme all'utente prima di
allegarlo alla release.

**Gate 10 — Release `v3.1.0`**: tag + `gh release create` con asset zip —
richiede conferma esplicita utente (azione visibile pubblicamente).

---

## Strategia di verifica

- Gate 2: confronto struct-a-struct (`isequaln`) tra `other` prodotto da
  `giano_build_other` e da `interface.m` sugli stessi dati, sui 3 dataset
  TSTO.
- Gate 5/8: replica dei risultati già certificati in CLAUDE.md (es. il run
  di continuazione ufficiale) a parità di seed/settaggi, tolleranza sul
  rumore di `vary_seed`.
- Gate 8: verifica "no file I/O" con controllo automatico (snapshot
  ricorsivo della working dir prima/dopo una chiamata a `giano.m`, nessun
  file nuovo/modificato atteso).
- Nessun test possibile sulla combinazione reale MATLAB 2026b + Windows
  10: rischio residuo dichiarato, non colmabile in questo ambiente.

---

## Decisioni richieste all'utente

Nessuna bloccante rimasta: H10 è stato chiarito e risolto dall'utente
stesso (accesso per nome, non per ordine di riga).

## Gate specifica: **PASS**

Directory/file creati in questa sessione: `giano-design.md` (questo file).
Deviazione dallo scaffold di default: cartella `giano/` proposta invece di
`docs/input/output/source`, motivata da CON-001 e dalla struttura già
esistente del progetto.

**Piano completato.** Nessun gate residuo. Punti aperti non bloccanti,
per riferimento futuro:
- `.mexw64` reali non compilati (GAP-001): da fare sulla macchina
  Windows/MATLAB 2026b di destinazione, istruzioni incluse nell'asset.
- H10 (mapping `x↔other.GUI.*` cablato in `traj_problem.m`): lasciato
  com'è per decisione utente, non riscritto in forma dati-driven.
