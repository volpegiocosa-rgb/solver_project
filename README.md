# solver — CMA-ES + ARCH (Octave/MATLAB)

Ottimizzatore black-box vincolato **generico e dimension-agnostic**.
Motore CMA-ES (base `purecmaes.m`) + gestione vincoli **ARCH**. **Niente Augmented Lagrangian.**

> Leggere **`CLAUDE.md`** prima di qualsiasi modifica: contiene scopo, contratti, regole,
> piano (§11) e link alle risorse esterne (§10). In caso di dubbio/contraddizione: **chiedere**.

## Struttura
- `solver.m` — entry point generico (orchestrazione, `solver(fun, bounds, opts)`).
- `main.m` — entry point per l'**utente finale**: lancia l'ottimizzazione del caso reale
  (lanciatore TSTO), vedi sezione "Caso reale" sotto.
- `core/` — motore CMA-ES (ask/tell, init, restart IPOP).
- `constraints/` — ARCH (ranking, repair, epsilon-schedule) + polish.
- `benchmark/` — sphere, Rosenbrock vincolata, g13 (validazione, Fase A).
- `io/` — parsing opts, normalizzazione, cache, logging.
- `real_case/` — adapter/dati per il caso reale (lanciatore a due stadi, repo TSTO esterno).
- `results/` — output dei run (log deterministici, non versionati).

## Caso reale: lanciatore a due stadi (TSTO)

`main.m` lancia l'ottimizzazione (massimizzazione payload) sul simulatore
[TSTO](https://github.com/volpegiocosa-rgb/TSTO) (lanciatore a due stadi, propulsione
liquida, Falcon-9-like), **incluso in questo repository** (cartella `TSTO/`,
vendorizzata via `git subtree`): un singolo clone o download di questa release
contiene tutto il necessario, nessun altro repository da scaricare a parte.

**Prerequisiti**:
1. Nessuno per i sorgenti: `git clone` (o "Download ZIP" dalla release) e sei pronto.
2. (Consigliato, non obbligatorio) Compilare i kernel Fortran nativi per la simulazione
   (~150-400x più veloce delle funzioni Octave interpretate — vedi
   `TSTO/source/native/README.md`):
   ```
   sudo apt install octave-dev gfortran
   cd TSTO/source/native
   mkoctfile eom_oct.cc eom_core.f90 -o eom_native.oct
   mkoctfile phase_event_oct.cc eom_core.f90 -o phase_event_native.oct
   ```
   Senza questo passo `main.m` funziona comunque (fallback automatico sulle funzioni
   Octave interpretate), solo molto più lento.
3. Lanciare: `octave main.m`

**Stato attuale (release 0.1.0) — onesto**: il porting Fortran ha reso ogni valutazione
della traiettoria ~150-400x più veloce (da ~7.5s a ~0.02-0.1s), ma il numero di
valutazioni necessario per trovare una traiettoria ammissibile su questo problema
(misurato: ~200.000) resta troppo alto per un requisito applicativo di ottimizzazione
completa in **≤5 minuti** su hardware target. `main.m` riproduce l'ultimo run riuscito
(`feasible=1` raggiunto), che richiede **ore**, non minuti. Vedi `CLAUDE.md` §11 Fase 5
per l'analisi completa e le direzioni di sviluppo aperte (principalmente:
parallelizzazione della valutazione della popolazione, oggi strettamente seriale).

## Avvio sessioni di sviluppo
Usa `kick-off-prompt.md`: copia il blocco della fase su cui lavori. Un blocco = una sessione
(rispetta Execution Protocol §0 e i gate §11 di CLAUDE.md).

## Genericità (rif. CLAUDE.md §1)
`n`, `n_eq`, `n_ineq` ricavati a runtime. Nessun magic number. `/core` e `/constraints`
non contengono nulla di specifico sulle traiettorie: il dominio vive solo nella funzione
utente (`real_case/traj_cost.m` per il caso reale, `benchmark/*.m` per la validazione).
