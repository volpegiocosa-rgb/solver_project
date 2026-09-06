# Kick-off prompt — lanciare all'avvio di ogni sessione

> Copia/incolla il blocco della fase su cui vuoi lavorare. Un blocco = una sessione.
> Il protocollo di economia token e i gate sono definiti in `CLAUDE.md` §0 e §11.

---

## Prompt universale (inizio di QUALSIASI sessione)

```
Leggi CLAUDE.md una sola volta, poi NON rileggerlo.
Rispetta l'Execution Protocol (§0): una fase per sessione, output snello (codice + diff minimi),
non cercare sul web ciò che è in §10, fermati e chiedi ai gate.
Sei in modalità Sonnet: task meccanico. Se incontri ambiguità algoritmica su ARCH (§5.2), segnalalo
invece di indovinare.
Dimmi solo: quale fase del §11 attacchiamo e quali file ti servono in contesto. Attendi il mio ok.
```

---

## Fase 0 — Setup

```
Obiettivo sessione: Fase 0 (§11).
Task: creare/verificare la struttura cartelle, scaricare purecmaes.m e i repo ARCH e CEC2006 dai
link §10, verificare le regole di compatibilità Octave/MATLAB (§2) su un file di prova.
Vincoli: dimension-agnostic (§1), nessun magic number. Non implementare logica: solo setup.
Al termine: elenca cosa è pronto e fermati (nessun gate di codice qui).
```

## Fase 1 — Motore CMA-ES (gate M2)

```
Obiettivo sessione: Fase 1 (§11), gate M2.
File in contesto: solver.m, core/*, io/normalize.m, io/denormalize.m, io/parse_opts.m,
benchmark/bench_sphere.m. NON aprire /constraints.
Task: implementare motore CMA-ES da purecmaes (loop esplicito con accesso popolazione),
normalizzazione bound [0,1], init (opts.x0 → Sobol singolo → centro, §5.1), sigma0, seed fisso,
restart IPOP. Default numerici PROVVISORI, marcati con % TODO (§6).
Gate M2: PASS su sphere (n generico, testare n=25), risultato riproducibile con seed fisso.
Al gate: fermati, mostrami il risultato, chiedi conferma, suggerisci /compact.
```

## Fase 2 — ARCH (gate M3) — ESCALATION MODELLO

```
Obiettivo sessione: Fase 2 (§11), gate M3. QUESTA fase può richiedere un modello superiore a Sonnet
per il porting ARCH (§0): se percepisci ambiguità algoritmica, segnalalo.
File in contesto: constraints/*, il purecmaes esteso di /core, e il codice sorgente ARCH
(constraint_handling.py da §10). NON aprire /benchmark oltre g13.
Task: portare in Octave da constraint_handling.py: eq_to_ineq, eps_schedule (per-vincolo, converge a
tol_con), arch_repair, arch_rank (adaptive ranking aggregation), viol_total. Cache simulazione.
Vietato: penalità additive, Deb rigida, Augmented Lagrangian (§5.2). n_eq generico, non 3.
Gate M3: PASS su g13 (3 uguaglianze), feasibility per-vincolo entro tolleranza.
Al gate: fermati, mostrami il risultato, chiedi conferma, suggerisci /compact.
```

## Fase 3 — Benchmark e calibrazione (gate M4)

```
Obiettivo sessione: Fase 3 (§11), gate M4.
File in contesto: benchmark/*, io/logger.m. Motore e ARCH già validati.
Task: eseguire la suite (sphere, Rosenbrock vincolata, g13) su più seed; raccogliere budget di
convergenza, stabilità sigma, success-rate; DERIVARE i default definitivi (max_iter, max_eval,
tol_fun, tol_x, schedule eps_eq) secondo §6.1.
Gate M4: sostituire i default PROVVISORI con i valori calibrati e rimuovere i % TODO PROVVISORIO.
Al gate: fermati, mostrami i default derivati, chiedi conferma, suggerisci /compact.
```

## Fase 4 — Feasibility-polish

```
Obiettivo sessione: Fase 4 (§11).
File in contesto: constraints/feasibility_polish.m, arch_repair.m.
Task: implementare il feasibility-polish finale (riuso repair) che chiude i residui ceq entro
tol_con per-vincolo. Lasciare optimality_polish come STUB OFF (opts.polish_opt, §5.3b).
Al termine: mostrami la verifica di chiusura residui, chiedi conferma, suggerisci /compact.
```

## Fase 5 — Caso reale (gate M5)

```
Obiettivo sessione: Fase 5 (§11), gate M5.
Task: agganciare traj_cost(x, other) reale; ricevere da me tol_con per-vincolo, max_time e budget
valutazioni f; dimensionare λ/restart/schedule. Run completo con feasibility su
perigeo/apogeo/inclinazione + log riproducibile.
Gate M5: run completo feasible + log. Fermati e chiedi conferma.
Nota: prima di iniziare, chiedimi i valori applicativi (tol_con, max_time, budget) — non assumerli.
```

---

## Promemoria gate (validi per tutte le fasi)
- Nessun avanzamento senza **gate verde** della fase corrente.
- A ogni gate: **fermati → mostra risultato → chiedi conferma → suggerisci `/compact`**.
- In caso di dubbio o contraddizione: **chiedi**, non indovinare (§0, §7).
