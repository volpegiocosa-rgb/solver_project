# CLAUDE.md — solver.m

> Documento guida per l'agente. Definisce scopo, ambiente, contratti di interfaccia,
> convenzioni e regole operative del progetto. Leggere **interamente** prima di
> scrivere o modificare codice. In caso di ambiguità: **fermarsi e chiedere**, non indovinare.

---

## 0. Execution Protocol (economia token — leggere per PRIMO)

Regole operative per minimizzare il costo totale della procedura. Prevalgono sul resto.

- **Lettura unica**: leggere questo file **una sola volta** a inizio sessione. Non rileggerlo
  nei turn successivi salvo modifiche esplicite.
- **Una fase per sessione**: lavorare su **una sola fase** del §11 per volta, tenendo in contesto
  **solo** i file di quella fase. Non aprire l'intero progetto insieme.
- **Auto-segmentazione + conferma ai gate**: l'agente **si auto-organizza per fasi** (§11) e,
  al raggiungimento di ogni **gate** (M2, M3, M4, M5), **si ferma e chiede conferma** all'utente
  prima di proseguire. Non superare un gate autonomamente.
- **Compattazione**: se il contesto si appesantisce o prima di cambiare fase, **suggerire
  `/compact`** (o attenderlo) per ripulire la history mantenendo solo lo stato utile.
- **No ricerca ridondante**: **non** cercare sul web ciò che è già in §10. **Portare** il codice
  dalle fonti indicate, non reinventarlo da paper.
- **No rework**: non passare alla fase successiva senza il **gate verde** (test/PASS) della fase
  corrente. Evitare iterazioni alla cieca.
- **Output snello**: produrre **codice + diff minimi**; niente spiegazioni non richieste,
  niente ripetizione del contenuto del doc.
- **Modello**: **Sonnet come default** per task meccanici (scaffolding già pronto,
  normalizzazione, I/O, benchmark, logging). Escalation a un modello superiore **solo** per il
  **porting ARCH** e il design del ranking (§5.2), dove l'ambiguità algoritmica è alta.
- **Dubbio/contraddizione**: fermarsi e chiedere (vedi anche §7, regola di ingaggio).

---

## 1. Scopo del progetto

Sviluppo **ex novo** di un ottimizzatore per **trajectory optimization con metodo diretto**.

- Le variabili di decisione sono **parametri continui interpretati dalla guida del
  lanciatore** (impostazione tipo single-shooting con guida parametrizzata).
  Nel caso d'uso attuale sono **~20–25**, ma il valore è **indicativo**: il solver deve essere
  **dimension-agnostic** (vedi principio di genericità sotto).
- Il motore di ottimizzazione è **CMA-ES** (Covariance Matrix Adaptation Evolution Strategy).
- La gestione dei vincoli usa **ARCH** (Adaptive Ranking-based Constraint Handling,
  Sakamoto & Akimoto, *Evolutionary Computation* 30(4), 2022 — arXiv:1811.00764).
- **NON usare Augmented Lagrangian.** Decisione di progetto vincolante.

L'eseguibile principale è **`solver.m`**. Il progetto **non fa parte di ISAAC** e non deve
importare né dipendere da moduli ISAAC.

### Principio di genericità e crescita (VINCOLANTE)
Il progetto deve nascere **generico e riusabile**, non specializzato sul caso traiettoria.
Numero di variabili `n` e numero di vincoli (`n_ineq`, `n_eq`) sono **indicativi** e vanno
trattati come **parametri**, mai cablati (`hardcoded`). Regole:
- **Nessun magic number**: `n`, `n_eq`, `n_ineq` si ricavano a runtime da `x0`/bounds/uscite di
  `traj_cost`. Vietato assumere `n=25` o `n_eq=3` nel codice.
- **Dominio applicativo disaccoppiato**: `/core` e `/constraints` non devono contenere nulla di
  specifico sulle traiettorie. Il significato fisico dei vincoli vive **solo** nella funzione
  utente (`traj_cost`) e nella configurazione, non nel solver.
- **Interfaccia stabile ed estendibile**: la firma dei moduli deve reggere l'aggiunta futura di
  disuguaglianze, nuovi criteri di stop, nuove strategie di init o di constraint-handling senza
  riscrivere il motore.
- **Obiettivo di lungo termine**: il solver deve poter essere riusato in **altri ambiti** di
  ottimizzazione black-box vincolata (non solo lanciatori). Le scelte di design privilegiano la
  riusabilità rispetto all'ottimizzazione sul singolo caso.
- Tolleranze e vincoli sono **vettori di lunghezza variabile** (per-vincolo), dimensionati sul
  numero effettivo di vincoli rilevato, non su un valore fisso.

---

## 2. Ambiente e vincoli tecnici

- **Linguaggio**: Octave (versione **latest**), con **compatibilità doppia Octave + MATLAB**.
- **Dipendenze**: partire dal solo core. Pacchetti `octave-forge` ammessi **solo se
  strettamente necessari** e comunque **non** su percorsi critici (il solver deve girare senza
  logging/plotting anche in assenza di pacchetti opzionali).
- **Base CMA-ES**: partire da **`purecmaes.m`** di Hansen (implementazione minimale, ~90 righe,
  gira nativamente in Octave). Il motore va esteso, non riscritto da zero.
  - Motivo della scelta: ARCH richiede l'accesso esplicito al **passo di ranking/selezione**
    dell'intera popolazione (repair + ranking aggregation). `purecmaes.m` espone questo passo
    in chiaro; `cmaes.m` completo ordina uno scalare per-individuo e non è adatto a ARCH.

### Vincoli operativi vincolanti (decisioni utente, non negoziabili)
- **Parallelizzazione VIETATA.** Non proporre, non progettare e non implementare
  alcuna forma di calcolo parallelo (né sulla popolazione CMA-ES, né sulle fasi di
  simulazione, né multi-processo/multi-thread/GPU). Vale come leva di performance e
  come suggerimento: **non va nemmeno menzionata** fra le opzioni. Ogni guadagno di
  velocità va cercato altrove (costo per valutazione, numero di valutazioni,
  strategia di ricerca, budget di restart).

### Regole di compatibilità Octave/MATLAB (rispettare sempre)
- Commenti con `%`, **mai** `#`.
- Chiusura blocchi con `end`, **mai** `endfunction` / `endif` / `endfor` / `endwhile`.
- **Vietati** operatori Octave-only: `++`, `--`, `+=`, `-=`, `*=`, `/=`.
- Stringhe: preferire `'...'` per uniformità.
- Nessuna funzione anonima con sintassi Octave-specifica; usare `@(x) ...` standard.
- Evitare `printf`; usare `fprintf`.
- Un file = una funzione principale con lo stesso nome del file. Funzioni ausiliarie locali
  in coda al file **oppure** in file separati se servono a più moduli.

---

## 3. Architettura e struttura file

Struttura a cartelle:

```
/core          Motore CMA-ES (purecmaes esteso) + loop, restart IPOP, step di selezione
/constraints   Modulo ARCH: repair operator, ranking aggregation, trasformazione epsilon
/benchmark     Problemi di validazione (sphere, Rosenbrock vincolata, un CEC2006 con uguaglianze)
/io            Normalizzazione variabili, parsing opts, logging riproducibile, I/O risultati
solver.m       Entry point: configura problema, bounds, opts; lancia l'ottimizzazione
```

Regole:
- `solver.m` **orchestra soltanto**: non contiene logica di algoritmo né di vincoli.
- Il motore in `/core` non deve conoscere il significato fisico dei vincoli: riceve
  ranking già calcolato da `/constraints`.
- `/constraints` non deve conoscere i dettagli interni di CMA-ES: espone una funzione
  di ranking che riceve `(f, cineq, ceq)` della popolazione e restituisce l'ordine finale.

### 3.1 Mappa delle function principali (responsabilità)

> Firme **indicative** e dimension-agnostic (nomi in inglese, §7). Da rifinire in fase di
> implementazione, mantenendo le responsabilità qui indicate. `n`, `n_eq`, `n_ineq` sono sempre
> ricavati a runtime, mai cablati.

**Entry point**
- `solver(fun, bounds, opts)` — *(solver.m)* orchestrazione. Ricava `n` da `bounds`, valida
  `opts`, prepara normalizzazione, lancia il loop, restituisce il risultato. **Nessuna** logica
  di algoritmo o vincoli.

**/core — motore CMA-ES**
- `cmaes_core(fun_ranked, n, opts)` — loop CMA-ES esteso da `purecmaes`: ask → valuta →
  ranking (delegato) → tell. Espone la popolazione prima della selezione.
- `cmaes_ask(state)` — campiona la popolazione da `N(xmean, sigma^2 C)`.
- `cmaes_tell(state, X, order)` — aggiorna media, covarianza, sigma dato l'**ordine** dei candidati.
- `init_mean(opts, n)` — sceglie `xmean` iniziale: `opts.x0` → Sobol singolo → centro (§5.1).
- `ipop_restart(state, opts)` — gestisce restart con λ crescente e nuovo `xmean` (Sobol+jitter).

**/constraints — ARCH**
- `arch_rank(f, cineq, ceq, eps_eq, state)` — **cuore ARCH**: calcola l'ordine finale della
  popolazione combinando ranking su obiettivo e su violazione (adaptive aggregation). È la
  funzione che `/core` riceve come `fun_ranked`.
- `arch_repair(x, con_fun, eps_eq)` — repair operator: proietta un candidato infeasible verso la
  regione feasible usando il gradiente numerico della violazione.
- `eps_schedule(iter, iter_max, tol_con)` — schedule decrescente per-vincolo di `eps_eq_k`,
  convergente a `tol_con_k`.
- `eq_to_ineq(ceq, eps_eq)` — trasforma `|h_k| - eps_eq_k <= 0`.
- `viol_total(cineq, ceq_as_ineq)` — violazione aggregata per il ranking (per-vincolo, normalizzata).

**/io — supporto**
- `parse_opts(opts, n)` — validazione e default (provvisori) degli `opts`; dimensiona i vettori
  per-vincolo sul numero effettivo di vincoli.
- `normalize(x_phys, bounds)` / `denormalize(x_norm, bounds)` — mapping [0,1] ↔ spazio fisico.
- `eval_cached(fun, x, cache)` — valutazione con cache (evita di ripetere la simulazione tra
  obiettivo e repair sullo stesso `x`).
- `logger(...)` — log deterministico: seed, opts, storia sigma, violazione per-vincolo, best-feasible, n_eval.

**/benchmark — validazione**
- `bench_sphere(x)`, `bench_rosenbrock_con(x)`, `bench_g13(x)` — problemi Fase A con firma
  compatibile a `traj_cost` (`[f, cineq, ceq] = ...`).
- `run_benchmarks(opts)` — esegue la suite su più seed e raccoglie le metriche per la calibrazione (§6.1).

**Polish (§5.3)**
- `feasibility_polish(x_best, con_fun, tol_con)` — **attivo**: chiude i residui `ceq` entro `tol_con`.
- `optimality_polish(x_best, fun, opts)` — **STUB** OFF di default (`opts.polish_opt`).

---

## 4. Contratto di interfaccia con la guida

Funzione utente (fornita dall'esterno, **non** da modificare):

```matlab
[f, cineq, ceq] = traj_cost(x, other)
```

- `x`      : vettore colonna delle variabili di decisione **in spazio fisico** (dimensione 20–25).
- `other`  : struct/parametri accessori passati dal solver (contesto, costanti, handle...).
- `f`      : scalare, funzione obiettivo (costo della traiettoria).
- `cineq`  : vettore delle disuguaglianze, convenzione `cineq <= 0` (feasible).
             **Attualmente PLACEHOLDER**: nessuna disuguaglianza attiva. Il solver deve
             predisporre la gestione, ma `cineq` può essere vuoto (`[]`) in questa fase.
- `ceq`    : vettore delle uguaglianze, convenzione `ceq == 0`. Lunghezza **variabile**
             (`n_eq` ricavato a runtime). Nel caso d'uso **attuale** sono **3 condizioni
             terminali** — 1) quota di perigeo, 2) quota di apogeo, 3) inclinazione obiettivo —
             ma il solver **non deve assumere** `n_eq = 3`: gestisce un numero arbitrario di
             uguaglianze.

### Note sul contratto
- **Costo dei vincoli**: `ceq` (e `cineq` in futuro) **richiedono la simulazione**, ma la
  simulazione **NON è costosa**. Questo soddisfa il requisito ARCH di vincoli "espliciti/economici"
  → **il repair operator è applicabile** e va implementato (non resta uno stub).
  Attenzione: poiché anche `f` esce dalla stessa `traj_cost`, valutare una **cache** per non
  ripetere la simulazione tra valutazione dell'obiettivo e repair dello stesso `x`.
- Le 3 uguaglianze hanno **grandezze fisiche eterogenee** (km per le quote, gradi/rad per
  l'inclinazione): la trasformazione epsilon e il repair devono usare **tolleranze/scale
  per-vincolo**, non un `eps_eq` scalare unico. Vedi §5.2 e §6.
- Il solver lavora su **variabili normalizzate in [0,1]**; la conversione da/verso lo spazio
  fisico avviene in `/io` tramite `lb`, `ub` (già disponibili come vettori).

---

## 5. Algoritmo — cosa implementare

### 5.1 Motore CMA-ES (`/core`)
- Base `purecmaes.m` estesa con:
  - **Restart IPOP** (Increasing Population, raddoppio di λ ad ogni restart) per la multimodalità
    tipica di finestre/assetti di guida.
  - Interfaccia **ask-and-tell** o loop esplicito che esponga la popolazione prima della selezione.
  - **Seed fisso** configurabile per riproducibilità.

#### Inizializzazione (punto chiave — NON confondere)
CMA-ES **non** riceve una popolazione iniziale: parte da un **singolo punto** `xmean` (centro
della distribuzione) più uno **step-size** `sigma`. La popolazione di λ candidati è **campionata
internamente** dal motore a ogni generazione da `N(xmean, sigma^2 * C)`. Di conseguenza:

- **NON** costruire una popolazione (es. Sobol) e passarla come "popolazione iniziale":
  verrebbe ignorata. Sobol serve semmai a scegliere i **centri**, non gli individui.

Logica di init da implementare:

1. **Guess utente presente** (`opts.x0` fornito) → `xmean = x0` (in spazio fisico, poi
   normalizzato in [0,1] da `/io`). È l'uso naturale di CMA-ES. Priorità massima.

2. **Guess assente** → generare un **singolo punto** di partenza:
   - Default: **un singolo campione Sobol** nel dominio normalizzato [0,1] (evita che tutti i
     run "vergini" partano dallo stesso identico punto, a differenza del centro fisso 0.5).
   - Alternativa configurabile: centro del dominio `xmean = 0.5 * ones(n,1)`.

3. **Step-size iniziale** `sigma`: default ~**0.3** in spazio normalizzato [0,1]
   (≈ 1/3 dell'ampiezza del dominio, regola di Hansen), configurabile via `opts.sigma0`.

#### Uso di Sobol + jitter (SOLO dove serve davvero un insieme di punti)
Il Sobol+jitter **non** alimenta il CMA-ES base. Va usato dove serve un insieme di centri:
- **Restart IPOP**: a ogni restart, campionare un **nuovo `xmean`** da una sequenza **Sobol**
  (copertura quasi-uniforme) + **jitter** per rompere la regolarità, invece di ripartire dallo
  stesso punto. Migliora la copertura della multimodalità.
- **Multi-start opzionale**: valutare più centri candidati e avviare CMA-ES dal migliore.
  Da attivare via `opts`, non default.

### 5.2 ARCH (`/constraints`)
ARCH modifica CMA-ES **solo nel ranking**. Tre componenti:

1. **Trasformazione uguaglianze → disuguaglianze con tolleranza epsilon**
   Ogni uguaglianza `h_k(x)=0` diventa `g_k(x) = |h_k(x)| - eps_eq_k <= 0`.
   - `eps_eq_k` **per-vincolo** (quota perigeo, quota apogeo, inclinazione): scale diverse.
   - Schedule **decrescente** nel tempo (ampia all'inizio, stretta a fine run).
   - Il valore finale di `eps_eq_k` deve **coincidere con `tol_con_k`** (tolleranza utente
     per-vincolo, §6): è il target di feasibility a fine run.

2. **Repair operator** (da implementare, i vincoli sono economici)
   Per un candidato infeasible, genera il punto riparato sfruttando il gradiente (numerico)
   della violazione. Usare la **cache** della simulazione dove possibile.

3. **Adaptive ranking aggregation**
   Combina in modo adattivo il ranking sull'obiettivo e il ranking sulla violazione;
   passa al motore CMA **solo l'ordine finale**. Preserva le due invarianze di CMA-ES
   (affine sullo spazio di ricerca + monotona su obiettivo/vincoli).

**Vietato**: penalità additive, feasibility rule di Deb "rigida", Augmented Lagrangian.

### 5.3 Polish finale — due livelli distinti

Distinzione di progetto (NON confondere i due):

**(a) Feasibility-polish — ATTIVO di default.**
A fine run, sul miglior candidato, applicare una **proiezione/repair sui 3 `ceq`** (riuso del
repair operator ARCH) per portare ogni residuo entro la rispettiva `tol_con_k`. È economico
(vincoli non costosi) e a basso rischio. Chiude i residui terminali senza solver aggiuntivi.

**(b) Optimality-polish (trust-region / SQP locale) — OFF di default, STUB dichiarato.**
Ricerca locale in trust-region attorno al best per spremere l'obiettivo.
- **Sconsigliato come default** in questo progetto: CMA-ES è già un buon ottimizzatore locale a
  fine run (covarianza ≈ inverso Hessiano) e l'obiettivo è **black-box via guida, potenzialmente
  non-liscio** → un trust-region gradient-based rischia di sprecare valutazioni o divergere.
- **Attivabile via `opts`** solo se l'utente dichiara che la guida è **localmente liscia**
  vicino all'ottimo. Fino ad allora resta uno **stub** non collegato al flusso principale.

---

## 6. Opzioni utente (`opts`)

> ⚠️ **STATO DEI DEFAULT: PROVVISORI — NON VALIDATI.**
> I valori di default numerici in questa sezione e in §6.1 sono **provvisori** e **restano tali
> finché i benchmark della Fase A (§8) NON vengono effettivamente eseguiti**. La sola
> definizione della metodologia di calibrazione (§6.1) **non** rende i default definitivi:
> occorre eseguire i benchmark e derivare i numeri dai risultati misurati.
> Regole operative fino ad allora:
> - Marcare ogni default numerico in codice con
>   `% TODO: PROVVISORIO — calibrare eseguendo i benchmark Fase A (rif. CLAUDE.md §6.1)`.
> - **Non** considerare questi valori affidabili per il caso reale.
> - I default diventano **definitivi solo dopo** l'esecuzione della Fase A e la derivazione
>   dei valori dai dati raccolti.

`solver.m` deve accettare una struct `opts` con criteri di stop e tolleranze configurabili
dall'utente. Ogni campo mancante ricade su un **default provvisorio** (vedi §6.1 per come si
fissano una volta eseguiti i benchmark). Campi previsti (estendibile):

| Campo             | Significato                                                   | Default (PROVVISORIO) |
|-------------------|--------------------------------------------------------------|-----------------------|
| `max_iter`        | numero massimo di iterazioni/generazioni                     | da eseguire benchmark (§6.1) |
| `max_eval`        | budget massimo di valutazioni di `f`                         | da eseguire benchmark (§6.1) |
| `max_time`        | tempo di calcolo massimo (s), stop su wall-clock             | input applicativo |
| `tol_con`         | **vettore per-vincolo**: soglia entro cui ogni vincolo è ok  | input applicativo |
| `tol_fun`         | tolleranza sulla variazione dell'obiettivo                   | da eseguire benchmark (§6.1) |
| `tol_x`           | tolleranza sulla variazione delle variabili                  | da eseguire benchmark (§6.1) |
| `x0`              | guess iniziale utente (spazio fisico); se assente → §5.1     | assente |
| `sigma0`          | step-size iniziale in spazio normalizzato [0,1]              | ~0.3 (provvisorio) |
| `init_mode`       | `sobol` (singolo campione) \| `center` (0.5) per guess assente | sobol |
| `multistart`      | numero di centri candidati da valutare prima di avviare (§5.1)| off (1) |
| `seed`            | seme RNG per riproducibilità                                 | fisso |
| `restart_ipop`    | on/off e numero massimo di restart                           | on |
| `polish_opt`      | attiva l'optimality-polish trust-region (§5.3b)              | off |
| `verbose`         | livello di logging                                           | — |

Regole:
- Il **parsing e la validazione** di `opts` stanno in `/io`, non sparsi nel motore.
- **`tol_con` è per-vincolo**: un vettore con una soglia per ciascuna delle 3 uguaglianze
  (quota perigeo, quota apogeo, inclinazione). Ogni vincolo si considera rispettato quando il
  suo residuo è entro la propria `tol_con_k`. Non usare una soglia scalare unica.
- Il valore finale dello schedule `eps_eq_k` (§5.2) **deve convergere a `tol_con_k`**.
- Almeno un criterio di stop deve essere sempre attivo (evitare loop infiniti).
- La feasibility a fine run si valuta **per-vincolo** contro `tol_con` (nessuna aggregazione
  scalare che nasconda la violazione di un singolo vincolo).

### 6.1 Come si fissano i default (metodologia — NON valori arbitrari)
I default numerici degli `opts` **non vanno inventati**: si **calibrano eseguendo i benchmark
standard** della Fase A (§8) prima di passare al caso reale. **Finché i benchmark non sono
stati eseguiti, i default restano provvisori** (vedi avviso a inizio §6). Procedura:

1. Eseguire i benchmark (sphere, Rosenbrock vincolata, CEC2006 con uguaglianze) con parametri
   di riferimento noti in letteratura per CMA-ES:
   - `lambda = 4 + floor(3*log(n))` (default Hansen), `mu = lambda/2`;
   - `sigma0 ~ 0.3` in spazio normalizzato [0,1].
2. Registrare, per ogni benchmark: numero di valutazioni per raggiungere il target di
   fitness/feasibility, stabilità di `sigma`, tasso di successo su più seed.
3. **Derivare i default** di `max_iter`, `max_eval`, `tol_fun`, `tol_x`, e lo **schedule di
   `eps_eq`** da questi risultati (es. `max_eval` calibrato sul budget mediano di convergenza
   con margine; `tol_fun`/`tol_x` sui plateau osservati).
4. `tol_con` (per-vincolo) e `max_time` restano **input applicativi** dell'utente sul caso reale:
   dipendono dai requisiti di missione (precisione su perigeo/apogeo/inclinazione) e dall'hardware,
   non sono calibrabili sui benchmark. Fornire solo valori-guida provvisori, chiaramente marcati.

Fino al completamento effettivo della Fase A, usare i valori di riferimento del punto 1 come
**provvisori ben commentati** (`% TODO: PROVVISORIO — calibrare su benchmark Fase A`), mai come
definitivi.

---

## 7. Convenzioni di codice e comunicazione

- **Codice e identificatori in inglese**; **note tecniche/commenti esplicativi in italiano**.
- Tono **peer-to-peer ingegneristico**, non code-oriented: ragionare in logica di ottimizzazione
  e di traiettoria, non in gergo software.
- **Assunzioni sempre esplicitate** nell'header del file e nei commenti dove impattano il risultato.
- **Niente espansione oltre lo scope** richiesto: non aggiungere feature, solver alternativi o
  strategie non chieste.
- **Chiedere se qualcosa non è chiaro** invece di indovinare. Esporre i moduli/ipotesi mancanti
  come *guess* dichiarati, non come fatti.
- **Traceability**: documentare da dove viene ogni scelta non ovvia (paper, §, assunzione).

### Regola di ingaggio (PRIORITARIA — vale su tutto il resto)
- **In caso di dubbio, ambiguità, informazione mancante o CONTRADDIZIONE, FERMARSI e CHIEDERE.**
  Non procedere "a naso", non colmare i vuoti con invenzioni, non risolvere silenziosamente le
  contraddizioni scegliendo un'interpretazione.
- Se due parti di questo documento (o una richiesta dell'utente e il documento) sembrano in
  conflitto, **segnalare esplicitamente il conflitto** e proporre le alternative, poi attendere.
- I moduli/ipotesi mancanti vanno esposti come **guess dichiarati**, chiaramente marcati, non
  come fatti.
- Meglio una domanda in più che un'assunzione sbagliata propagata nel codice.

---

## 8. Testing e riproducibilità

Validazione in **due fasi** (prima benchmark, poi caso reale). I benchmark hanno **doppio ruolo**:
validare il solver **e** calibrare i default degli `opts` (§6.1). **I default numerici restano
provvisori finché questa fase non è stata eseguita.**

### Fase A — Benchmark (`/benchmark`)
- **Sphere** (sanity check del motore, no vincoli).
- **Rosenbrock vincolata** (disuguaglianze).
- **Un problema CEC2006 con uguaglianze** (verifica trasformazione epsilon + repair su `ceq`).
- Criteri di PASS espliciti (target di fitness / feasibility per-vincolo entro tolleranza).
- Output della fase: **default calibrati** per `max_iter`, `max_eval`, `tol_fun`, `tol_x`,
  schedule `eps_eq` (§6.1). Prima di questo output, i default sono solo segnaposto.

### Fase B — Caso reale
- Aggancio a `traj_cost` sulla traiettoria effettiva, dopo il superamento della Fase A.

### Riproducibilità (obbligatoria)
- **Seed fisso** per RNG, configurabile via `opts.seed`.
- Log deterministici in `/io`: per ogni run salvare seed, `opts`, storia di `sigma`,
  **violazione per-vincolo**, best-feasible, numero di valutazioni di `f`.
- Stesso input + stesso seed ⇒ stesso output.

---

## 9. Stato dei punti aperti

Risolti:
- Costo di `cineq`/`ceq` → simulazione **non costosa**, repair ARCH **applicabile**.
- Significato delle 3 uguaglianze → quota perigeo, quota apogeo, inclinazione obiettivo.
- Disuguaglianze → **placeholder** (`cineq = []`).
- `tol_con` → **per-vincolo** (vettore, una soglia per uguaglianza).
- Polish → **feasibility-polish attivo** di default (riuso repair);
  **optimality-polish trust-region OFF** di default, stub attivabile via `opts.polish_opt`.
- Inizializzazione → CMA-ES parte da **singolo punto** `xmean` + `sigma`, non da popolazione.
  Guess utente via `opts.x0`; se assente, **singolo campione Sobol** (default) o centro.
  Sobol+jitter riservato a **restart IPOP** e **multi-start** opzionale (§5.1).
- Metodo per i default degli `opts` → **calibrazione sui benchmark Fase A** (§6.1).

Ancora aperti / da eseguire:
1. **ESECUZIONE dei benchmark Fase A**: i default numerici (`max_iter`, `max_eval`, `tol_fun`,
   `tol_x`, schedule `eps_eq`) **restano provvisori finché la Fase A non viene eseguita** e i
   valori non sono derivati dai risultati misurati.
2. **Valori di `tol_con` per-vincolo** e **`max_time`**: input applicativi dal caso reale
   (requisiti di missione + hardware), da fornire in Fase B.
3. **Budget di valutazioni di `f`** sul caso reale: usato insieme alla calibrazione benchmark
   per dimensionare λ, numero di restart e schedule di `eps_eq`.

> Fino al completamento **effettivo** della Fase A, l'agente implementa motore CMA-ES + ARCH
> completo (repair + feasibility-polish) e i benchmark, usa i parametri di riferimento
> (§6.1 punto 1) come **default provvisori commentati** (mai definitivi), e lascia come
> **stub dichiarato** solo l'optimality-polish trust-region (§5.3b).

---

## 10. Risorse esterne (link diretti — NON dedurre, scaricare da qui)

> Scopo: evitare che l'agente reinventi codice già disponibile. Preferire il **porting** da queste
> fonti alla reimplementazione da paper. Verificare licenza prima di riusare il codice.

### Motore CMA-ES (base del progetto)
- `purecmaes.m` (Octave-native, base scelta per `/core`):
  https://cma-es.github.io/cmaes_sourcecode_page.html
- Pagina sorgenti CMA-ES ufficiale (varianti C/C++/Matlab/Python/R):
  https://cma-es.github.io/cmaes_sourcecode_page.html
- pycma (riferimento Python: ask-and-tell, restart IPOP, logging — utile per confronto logica):
  https://github.com/CMA-ES/pycma
- API pycma (`purecma.CMAES`, metodi `ask`/`tell`):
  https://cma-es.github.io/apidocs-pycma/cma.purecma.html

### ARCH — gestione vincoli (riferimento PRIMARIO per il porting)
- **Codice degli autori (Akimoto/Sakamoto)** — `constraint_handling.py` contiene **ARCH (QUAK)**,
  `ddcma.py` contiene DD-CMA-ES. Base da cui portare repair + ranking aggregation in Octave:
  https://github.com/akimotolab/multi-fidelity
- Paper ARCH (algoritmo completo, trasformazione epsilon delle uguaglianze):
  arXiv:1811.00764 — https://arxiv.org/abs/1811.00764
- Versione journal (Evolutionary Computation, MIT Press 2022):
  https://direct.mit.edu/evco/article/30/4/503/110409/

### Benchmark CEC2006 (Fase A — validazione + calibrazione default)
- **Repo con implementazioni Python + MATLAB** di g01–g24 (include **g13**, 3 uguaglianze):
  https://github.com/franciscorafaelsr/cec2006-benchmarks
- **g13** (il più simile al caso reale: 3 uguaglianze non-lineari, n=5):
  - definizione: https://github.com/franciscorafaelsr/cec2006-benchmarks/blob/master/problems/g13.md
  - codice Python: https://github.com/franciscorafaelsr/cec2006-benchmarks/blob/master/code/python/g13.py
  - `f(x)=exp(x1*x2*x3*x4*x5)`, `h1=sum(xi^2)-10`, `h2=x2*x3-5*x4*x5`, `h3=x1^3+x2^3+1`,
    best noto `f* = 0.053942`.

### Nota di porting
- ARCH originale è in **Python**: prevedere una fase di **porting in Octave/MATLAB** del solo
  modulo `/constraints` (repair + ranking aggregation + epsilon-schedule). Il motore `/core`
  resta su `purecmaes.m`. Documentare le differenze di porting come nel resto del progetto.
- I benchmark CEC2006 sono disponibili anche in MATLAB nel repo sopra: usarli direttamente per la
  Fase A riduce il rischio di errori di trascrizione delle formule.

---

## 11. Piano di sviluppo e To-Do (spuntare man mano)

> Regola: aggiornare questa checklist a ogni avanzamento. Non passare a una fase successiva
> senza aver completato i gate della precedente. Il gate critico è **F3 → default definitivi**.
> **Ai gate (M2–M5): fermarsi, chiedere conferma, suggerire `/compact` (rif. §0).**

### Milestone
- **M1 — Scaffolding**: struttura cartelle + entry point + I/O di base.
- **M2 — Motore**: CMA-ES funzionante (senza vincoli) validato su sphere.
- **M3 — Vincoli**: ARCH portato e validato su benchmark con uguaglianze (g13).
- **M4 — Calibrazione**: default `opts` derivati dai benchmark (rimuove i provvisori).
- **M5 — Caso reale**: aggancio a `traj_cost`, run sulla traiettoria.

### Checklist operativa

**Fase 0 — Setup** ✅ completata
- [x] Creare struttura `/core`, `/constraints`, `/benchmark`, `/io` + `solver.m`.
- [x] Scaricare `purecmaes.m` e verificarne l'esecuzione nuda in Octave (converge su Rosenbrock
      N=11, pubblico dominio dichiarato nell'header — nessun problema di licenza).
- [x] Scaricare repo ARCH (`akimotolab/multi-fidelity`) e CEC2006 (`franciscorafaelsr/...`) in
      `/external` (staging, non fa parte della struttura finale del solver).
      Nota licenza: nessun `LICENSE` file né licenza dichiarata su GitHub per questi due repo.
      **Decisione utente**: rischio accettato, si procede al porting citando la fonte (URL +
      autori) nei commenti dei file di destinazione in `/constraints` e `/benchmark`.
- [x] Verificare compatibilità Octave/MATLAB delle regole §2 su un file di prova (eseguito in
      Octave 9.4.0 con successo).

**Fase 1 — Motore CMA-ES (`/core`)** ✅ completata (gate M2 verde)
- [x] Portare/estendere `purecmaes.m` con loop esplicito (accesso alla popolazione)
      (`core/cmaes_ask.m`, `core/cmaes_tell.m`, `core/cmaes_core.m`, `core/init_state.m`).
- [x] Implementare normalizzazione bound [0,1] in `/io` (`lb`,`ub`) (`io/normalize.m`,
      `io/denormalize.m`). Nota: `normalize.m` genera un warning di shadowing su una
      funzione built-in di Octave (nome gia' fissato da CLAUDE.md §3.1, non rinominato
      senza conferma — innocuo, funziona correttamente).
- [x] Implementare inizializzazione: `opts.x0` → Sobol singolo → centro (§5.1)
      (`core/init_mean.m`). Sobol self-contained (`core/sobol_point.m`, tabella
      Joe-Kuo imbarcata, licenza BSD citata nel file, cap n<=40 con errore esplicito
      oltre — decisione utente Fase 1, vedi memoria di sessione).
- [x] Implementare `sigma0` e seed fisso (`io/parse_opts.m`, `rng(opts.seed)` in
      `cmaes_core.m`).
- [x] Aggiungere restart IPOP con nuovo `xmean` da Sobol+jitter (`core/ipop_restart.m`).
- [x] **Gate M2**: PASS su sphere n=25 (f_best≈1.4e-13), riproducibilita' bit-esatta
      verificata (due run stesso seed → stesso `x_best`/`f_hist`), genericita'
      dimensionale verificata su n=2,5,8,12,25 senza modifiche al codice.

**Fase 2 — ARCH (`/constraints`)** ✅ completata (gate M3 verde)
- [x] Portare in Octave la trasformazione uguaglianze → `|h_k| - eps_eq_k <= 0`
      (`constraints/eq_to_ineq.m`, vettorizzato su popolazione).
- [x] Implementare schedule decrescente di `eps_eq_k` (per-vincolo)
      (`constraints/eps_schedule.m`, geometrico, K0=1e3 provvisorio, converge
      esattamente a `tol_con_k` all'orizzonte `opts.eps_horizon` — NON
      `opts.max_iter`: l'orizzonte dello schedule e' proprieta' del problema,
      disaccoppiato dal budget utente, altrimenti un run piu' lungo puo'
      peggiorare invece di migliorare, vedi bug corretto sotto).
- [x] Portare il repair operator da `constraint_handling.py`
      (`constraints/arch_repair.m`). ECCEZIONE A §2 (decisione utente, rif.
      `octave_toolbox_required.md`): usa `sqp()` (Octave, funzione CORE,
      nessun pacchetto opzionale) / `fmincon('Algorithm','sqp')` (MATLAB,
      richiede Optimization Toolbox, NON verificato sull'ambiente utente).
      Design: le uguaglianze sono trattate come disuguaglianze eps-bandate
      (via `eq_to_ineq`), non come vincoli di uguaglianza esatti nel solver —
      lega la precisione del repair allo stesso schedule del ranking.
- [x] Portare l'adaptive ranking aggregation (`constraints/arch_rank.m`).
      Deviazione dichiarata dal paper (rif. header del file): secondo asse di
      ranking = violazione diretta (non distanza di repair, perche' f e'
      valutabile ovunque, non solo su punti riparati come nel paper); alpha
      adattato su uno stimatore statistico a costo zero della distanza del
      centro dalla banda ammissibile (equivalente a `dm` del paper, derivato
      per regressione implicita dalla popolazione invece che da un repair di
      xmean); clipping di alpha in `[1, lam_def]` invece di `[1/lam, lam]`
      (floor a 1.0, non a 1/lam: necessario per non far "fuggire" la
      popolazione fuori dal dominio dichiarato, misurato su g13). Redesign
      completo eseguito da un agent su modello superiore (Opus) dopo che la
      prima versione (alpha su frazione feasible) si e' mostrata instabile
      su budget lunghi — vedi nota su ambiguita' algoritmica sotto.
- [ ] Cache simulazione (f e vincoli dallo stesso `x`): NON implementata.
      Non necessaria con l'architettura attuale — `cmaes_core.m` valuta
      `fun_norm` una sola volta per candidato per generazione (f, cineq, ceq
      insieme), e il repair (che potrebbe rivalutare i vincoli piu' volte)
      e' usato solo nel polish finale su un unico punto (Fase 4), non nel
      loop principale su tutta la popolazione. Da rivalutare se Fase 4
      introduce chiamate ripetute che la rendono utile.
- [x] **Gate M3**: PASS su g13 (3 uguaglianze, f*=0.053942). 16/16 run
      feasible per-vincolo entro `tol_con` (8 seed × budget default/lungo,
      validati sia dall'agent sia indipendentemente in sessione). Proprieta'
      garantita per costruzione (non solo osservata): un run piu' lungo non
      puo' peggiorare il best-feasible rispetto a uno piu' corto, stesso seed.
      3/8 seed raggiungono l'ottimo globale (errore fino a 2.8e-08, limitato
      dalla tolleranza), 5/8 si fermano sull'attrattore locale noto di g13
      (f≈0.439) — tasso di successo globale legato al budget di restart IPOP,
      demandato alla calibrazione Fase 3 (non e' un fallimento del gate).
      Regressione sphere n=25 verificata bit-esatta (f_best=2.597625e-13,
      invariato rispetto a Fase 1).

  **ADDENDUM (trovato in Fase 3, rif. sotto per il bug completo)**: il tasso
  3/8 sull'ottimo globale riportato sopra era in parte un artefatto di un bug
  nel criterio `tol_fun` (i restart IPOP non cercavano davvero — vedi bug #5
  nella sezione Fase 3). Dopo il fix, sugli stessi identici benchmark: g13
  10/10 ottimo globale (non solo 10/10 feasible). Il gate M3 originale
  (PASS su feasibility) resta valido cosi' com'era: la feasibility non era
  mai stata in dubbio, solo il tasso di successo sull'ottimo GLOBALE era
  sottostimato dal bug.

  **Bug corretti durante la Fase 2** (rif. CLAUDE.md §7, trovati per verifica
  empirica, non solo teorica):
  1. Tracking di `x_best`/`f_best` in `cmaes_core.m` seguiva il minimo raw di
     `f` anche su punti fortemente infeasible (obiettivo artificiosamente
     basso fuori dalla regione ammissibile) — aggiunto tracking separato
     `x_best_feas`/`f_best_feas` (vero best per-vincolo entro `tol_con`,
     scansione dell'intera popolazione, nessuna valutazione aggiuntiva),
     ora output primario di `result` quando esistono vincoli
     (`result.feasible` segnala se e' stato trovato).
  2. `viol_total.m` normalizzava la violazione relativamente al massimo della
     popolazione CORRENTE — cieco alla scala assoluta, causava divergenza di
     sigma (osservato fino a ~1e19). Corretto: normalizzazione in scala
     assoluta (`eps_eq`, costante nella generazione) fatta dal chiamante
     (`arch_rank.m`) prima di aggregare.
  3. `eps_schedule` legato a `opts.max_iter` invece che a una proprieta' del
     problema — un budget piu' lungo non necessariamente faceva raggiungere
     `tol_con`. Introdotto `opts.eps_horizon` (§6, provvisorio), disaccoppiato.
  4. Aggiunto criterio di stop di sicurezza `diverged_sigma` in
     `cmaes_core.m` (sigma > soglia interna 100x il dominio normalizzato →
     forza restart IPOP invece di continuare a divergere). Contenimento
     generico, non specifico ad ARCH.

  **Nota su ambiguita' algoritmica (rif. CLAUDE.md §0/§7)**: il design del
  ranking adattivo ha richiesto un redesign completo dopo che la prima
  versione (alpha su frazione feasible della popolazione) si e' mostrata
  instabile (convergenza peggiorava, non migliorava, con budget piu' lungo).
  Il redesign e' stato affidato a un agent su modello superiore (Opus), come
  previsto da CLAUDE.md §0 per "il porting ARCH e il design del ranking,
  dove l'ambiguita' algoritmica e' alta". Risultati verificati
  indipendentemente in sessione prima di accettarli.

  **Gap aperto, NON risolto in Fase 2 (decisione utente: nessuna modifica
  ora)**: CMA-ES campiona senza vincoli di bound nello spazio normalizzato
  (`cmaes_ask.m` non clippa, per l'invarianza affine di §5.2, come
  `purecmaes.m`). E' stato provato un clip della sola valutazione (passare a
  `fun_norm` una copia clippata in [0,1]^n, lasciando intatta la X vista da
  `cmaes_tell.m`) ma SCARTATO: misurato su g13, introduce un nuovo
  fallimento (popolazione intrappolata su un angolo del dominio quando molti
  campioni vi si clippano in modo identico, azzerando il gradiente di
  ritorno) che peggiora il tasso di feasibility rispetto a non clippare
  affatto (regressione su 2/3 seed testati, anche a budget maggiorato). Resta
  quindi SENZA fix: il floor di alpha=1.0 in `arch_rank.m` e' l'unico argine,
  indiretto, alle fughe fuori dominio (nessuna fuga osservata nei 16/16 run
  di validazione, ma non e' una garanzia strutturale). Da riconsiderare in
  Fase 3/5, es. iniettando i bound come `cineq` (richiede prima una scala
  per-vincolo per le disuguaglianze, analoga a `eps_eq`, non ancora
  progettata — `cineq` e' oggi placeholder vuoto).

**Fase 3 — Benchmark e calibrazione (`/benchmark`)** ✅ completata (gate M4 verde)
- [x] Implementare/collegare sphere (gia' da Fase 1), Rosenbrock vincolata
      (`benchmark/bench_rosenbrock_con.m`, formulazione standard "cubic-and-
      line" n=2, letteratura CMA-ES vincolato — prima validazione reale del
      ramo `cineq` di ARCH, mai esercitato prima d'ora: ne' sphere ne' g13
      hanno disuguaglianze), g13 (gia' da Fase 2).
- [x] `benchmark/run_benchmarks.m` implementata e verificata funzionante
      (smoke test: 2 seed/benchmark, budget ridotto, struct di output
      corretta). La calibrazione sotto usa in parte run_benchmarks.m
      direttamente e in parte script equivalenti ad-hoc (stessa chiamata a
      `solver()`, stesso criterio di successo) per ragioni di tempo di
      esecuzione in sessione — nessuna differenza nella logica misurata.
- [x] Eseguito su piu' seed (10 per benchmark), registrato budget di
      convergenza, success-rate, comportamento di sigma.

  **Bug #5 trovato ESEGUENDO la calibrazione (rif. CLAUDE.md §7, §0)**: il
  criterio di stop `tol_fun` in `core/cmaes_core.m` usava `f_hist`/`iter`
  GLOBALI (mai azzerati da un restart IPOP all'altro). Poiche' `f_hist(iter)`
  e' il best-feasible MAI decrescente su tutto il run, non appena il best
  globale smetteva di migliorare la finestra di plateau (`f_hist` piatta)
  faceva scattare "convergenza" alla primissima generazione di OGNI restart
  successivo — i restart IPOP (gia' portati e validati in Fase 1/2) non
  avevano MAI la possibilita' di cercare davvero. Misurato su
  `bench_rosenbrock_con` seed 1: i restart 1..9 duravano ESATTAMENTE 1
  iterazione ciascuno (10/10 seed), mentre il primo segmento convergeva
  genuinamente in ~170 iterazioni con `sigma` che scendeva in modo liscio a
  ~1e-5 (nessun falso positivo li' — il bug e' specifico ai restart).
  Fix: introdotto tracking SEGMENT-LOCAL (`iter_seg`, `f_hist_seg`,
  `f_best_feas_seg`, azzerati a ogni `ipop_restart`) usato SOLO dal criterio
  `tol_fun`; `f_hist`/`f_best_feas` globali restano invariati per l'output
  (`result.f_hist`, S6/S7). Verificato: dopo il fix i restart esplorano
  davvero (rosenbrock seed 1: f_best 0.976→0.16 sfruttando i restart 7-9;
  g13, stesso identico budget del vecchio default, 3/8→10/10 seed che
  raggiungono l'ottimo globale, vedi addendum Fase 2 sopra). Regressione
  sphere/g13 verificata: nessun peggioramento di qualita', solo di tempo di
  calcolo (i restart ora consumano budget reale invece di essere abortiti).

  **Risultati calibrazione** (post-fix, 10 seed/benchmark salvo indicato):
  - **sphere** (n=25, target f≤1e-8): 10/10 successo. Budget di convergenza
    misurato: mediana ~32575 valutazioni, massimo 34153. Nessuna divergenza
    di sigma.
  - **g13** (n=5, 3 uguaglianze, target = feasibility): 10/10 feasible,
    10/10 ottimo globale (f*=0.053942) a `max_iter=2500` (vs 4/10 ottimo
    globale, 10/10 feasible, al vecchio default `max_iter=1232` — la
    feasibility non e' mai stata il collo di bottiglia, l'ottimo globale si'
    ). Costo in valutazioni fortemente variabile per seed (78632–431088),
    dominato dal numero di restart IPOP raggiunti (lambda raddoppia ad ogni
    restart).
  - **rosenbrock vincolata** (n=2, sole disuguaglianze, target f≤1e-3):
    0/10 successo anche a budget molto piu' ampio (`max_iter=5000`,
    `max_eval=2e5`): 4/10 seed intrappolati su un plateau f=0.9989 (
    verificato ANALITICAMENTE non essere un punto KKT del problema vincolato
    — non e' un minimo locale genuino, condizione di stazionarieta' violata
    sul vincolo attivo c1), gli altri 6/10 fra 0.0020 e 0.82. **Gap aperto,
    NON risolto**: coerente con la nota gia' in `constraints/arch_rank.m`
    (manca un `eps_ineq`/scala per-vincolo per le disuguaglianze, analogo a
    `eps_eq` per le uguaglianze) — deferito a Fase 5, quando `cineq` uscira'
    dal placeholder sul caso reale. I default sotto sono quindi calibrati
    principalmente su g13 (strutturalmente piu' vicino al caso reale:
    n_eq=3 in entrambi), non su rosenbrock.
- [x] **Gate M4**: default sostituiti in `io/parse_opts.m`, TODO PROVVISORIO
      rimossi, ciascun campo numerico marcato "CALIBRATO (Fase 3)" con la
      derivazione inline. Relazione chiave: `eps_horizon` lasciato alla
      formula originale (gia' adeguata, invariata), `max_iter = 2 *
      eps_horizon` (margine di ricerca DOPO che lo schedule di eps_eq ha
      raggiunto `tol_con`, verificato 10/10 su g13), `max_eval = max_iter *
      lambda_ref * 50` (tetto di sicurezza dominato dal costo peggiore di
      IPOP con `max_restarts` esaurito, non un budget stretto — per n grande,
      caso reale, diventera' verosimilmente non vincolante rispetto a
      max_iter/max_time, coerente con S6.1 punto 4). `tol_fun`, `tol_x`,
      `sigma0`, `max_restarts` verificati/confermati invariati (nessun
      fallimento della suite riconducibile al loro valore numerico).
      Validato con i default PURI (nessun override) post-calibrazione:
      g13 5/5 ottimo globale, sphere f_best=1.13e-16 (convergenza pulita,
      nessuna divergenza), nessuna regressione.

**Fase 4 — Feasibility-polish** ✅ completata
- [x] Implementare feasibility-polish finale (riuso repair) sui 3 `ceq`
      (`constraints/feasibility_polish.m`, ora attiva: chiama `arch_repair`
      con `eps_eq = opts.tol_con` direttamente, non uno schedule — e' il
      target finale di precisione, S5.2 punto 1). Agganciata in `solver.m`
      dopo `cmaes_core`, in spazio NORMALIZZATO (`arch_repair` assume
      dominio `[0,1]^n`, deviazione dal TODO originale che operava su
      `x_best_phys` — necessaria per coerenza con `arch_repair` gia'
      validato in Fase 2/3, non una nuova decisione algoritmica). No-op per
      costruzione se non vincolato o gia' feasible (nessuna chiamata SQP).
- [x] Verificare chiusura residui entro `tol_con` per-vincolo: g13 (n=5, 10
      seed, budget default calibrato) 10/10 `feasible=1` post-polish,
      residui `|ceq|` tutti ≤ `tol_con` (tipicamente appena sotto la soglia,
      es. 9.9999e-05 su tol=1e-4 — atteso: il repair proietta sul BORDO
      della banda ammissibile, e' la proiezione a distanza minima, non un
      punto strettamente interno). Sphere (n_eq=0) verificato come puro
      no-op, nessun overhead SQP, nessuna regressione (f_best invariato).
- [x] Lasciare optimality-polish trust-region come **stub**
      (`constraints/optimality_polish.m`, invariato, `opts.polish_opt`
      resta `false` di default, §5.3b — nessuna modifica in Fase 4).

  **Bug trovato verificando il risultato (non solo per ispezione, rif.
  CLAUDE.md S7)**: nella prima versione del collegamento in `solver.m`,
  `result.f_best`/`result.feasible` restavano quelli calcolati da
  `cmaes_core` PRIMA del polish — disallineati dal `x_best`/`x_best_phys`
  restituiti, che il polish sposta (proiezione sul vincolo). Diagnosticato
  con un test mirato a budget deliberatamente ridotto (`max_iter=40`,
  restart disattivati, su g13): il polish produceva un punto con un residuo
  marginalmente fuori tolleranza (0.000100144 contro tol=1e-4), ma
  `result.feasible` avrebbe continuato a riportare il valore pre-polish.
  Fix: `solver.m` ri-valuta `fun_norm` sul punto POST-polish e ricalcola
  `f_best`/`feasible` con la STESSA definizione per-vincolo usata in
  `cmaes_core.m` (`cineq<=0` e `|ceq|<=tol_con`, nessuna aggregazione
  scalare). Verificato: su g13 con budget default (10 seed) risultato
  invariato (10/10 feasible, il polish ci arriva comunque); sul caso
  stress a budget=40 il fix fa correttamente emergere `feasible=0` per il
  seed che resta marginalmente fuori banda, invece di nasconderlo.

  **Limite noto, non risolto (onesta, rif. CLAUDE.md S7)**: la chiusura
  entro `tol_con` NON e' una garanzia assoluta — dipende dalla convergenza
  del sotto-problema SQP interno ad `arch_repair` (`maxiter=200`,
  `tol=1e-10`), che a sua volta dipende da quanto il punto di partenza e'
  lontano dalla regione ammissibile. Sotto il budget CALIBRATO (Fase 3) il
  punto pre-polish e' gia' vicino a `tol_con` (lo schedule di `eps_eq`
  converge li' entro `eps_horizon`), quindi il polish opera su un problema
  SQP facile — osservato 10/10 su g13. Sotto un budget artificialmente
  ridotto (stress test, non lo scenario d'uso previsto) il polish puo'
  lasciare un residuo marginalmente fuori banda (~0.1% oltre soglia in un
  caso osservato) — ora correttamente segnalato da `result.feasible=0`
  (rif. bug/fix sopra), non silenziosamente nascosto. Non e' stato
  necessario alcun intervento su `arch_repair.m`: il gap e' nel regime
  d'uso estremo testato, non nella logica del polish.

**Fase 5 — Caso reale (Fase B)** — in corso
- [x] Agganciare `traj_cost(x, other)` reale. Il simulatore reale e' **TSTO**
      (repository esterno, cartella parallela `../TSTO`, un lanciatore a due
      stadi a liquido, Falcon 9-like, dataset `reference_LV`). TSTO aveva
      gia' un wrapper quasi pronto (`TSTO/source/traj_problem.m`, firma
      `[f,g,h]=traj_problem(x,other)`) che combacia col contratto S4. Creato
      `real_case/traj_cost.m` (thin wrapper, FUORI da /core /constraints
      /io /benchmark, rif. S1/S3) + `real_case/run_real_case.m` (script di
      lancio: `other=interface(reference_LV)` una volta sola, bounds, opts,
      chiamata a `solver()`).

      **Ridisegno di x (decisione utente, non assunta)**: rispetto alle 12
      variabili originarie di `GUIDANCE_VARS.csv`, `plane_controller_kd/ki`
      RIMOSSE da x (restano fisse al nominale, non hanno senso come
      variabili di design) e sostituite dalla massa payload (`Mpayload`,
      prima fissa in `LV.csv`), che diventa la 11a variabile. Conseguenza:
      l'obiettivo in `TSTO/source/eval_fgh.m` cambia da proxy (-massa
      residua a fine missione) a `f = -Mpayload` diretto (massimizzare il
      payload, coerente con `interface_specification.md §5.1`, che gia'
      specificava "-massa PL" — il proxy precedente era un ripiego dichiarato
      "da sostituire se non valido", ora sostituito). Modifiche in TSTO:
      `source/eval_fgh.m`, `source/traj_problem.m`, `source/main.m`
      (round-trip re-verificato: f=-4000, h≈0 sul nominale, invariato).

      **Bug trovato e corretto durante l'integrazione (non solo per
      ispezione, rif. S7)**: collisione di nome `init_state.m` tra
      `core/init_state.m` (stato CMA-ES) e `TSTO/source/init_state.m`
      (stato fisico veicolo) — Octave risolve i nomi di funzione
      GLOBALMENTE sul path, non per-cartella-chiamante: qualunque ordine di
      `addpath` fa vincere UN SOLO file per entrambi i chiamanti
      (`cmaes_core.m` E `TSTO/source/simulator.m`), causando errori runtime
      differenti a seconda dell'ordine (`"too many inputs"` o `'n'
      undefined` a seconda di quale versione vince). Fix STANDARD Octave/
      MATLAB: spostato `TSTO/source/init_state.m` in `TSTO/source/private/`
      (meccanismo di funzione privata, visibile solo ai chiamanti nella
      stessa cartella — qui `simulator.m`). Nessuna altra collisione di nome
      trovata (verificato per intersezione degli elenchi file). Round-trip
      TSTO re-verificato dopo lo spostamento: risultato identico.

- [x] Ricevere `tol_con` per-vincolo e `max_time` applicativi dall'utente.
      `tol_con` = 3% del target di missione per-vincolo (perigeo 6000 m,
      apogeo 12000 m, inclinazione 0.01492 rad — stesso ordine di
      `eval_fgh.m` OPT.h). `max_time` = `Inf` (nessun limite di wall-clock,
      esplicito, fase di sviluppo).
- [x] Ricevere/definire budget valutazioni `f`.
      **Trovato un vincolo NON previsto da S4/S6.1**: una singola
      valutazione di `traj_cost` (simulazione ODE45 reale, 6+ fasi) costa
      **~12.3 s**, non i pochi ms dei benchmark. I default CALIBRATI di
      Fase 3 (`io/parse_opts.m`, tarati assumendo vincoli "economici", S4)
      darebbero per n=11 `max_eval=3.360.500` (~478 giorni) — del tutto
      impraticabile. Per questa fase (decisione utente): **override
      esplicito** `opts.max_eval=300`, `opts.max_iter=300` in
      `run_real_case.m` — un run ESPLORATIVO (~1h di calcolo), non
      un'ottimizzazione a convergenza. La calibrazione Fase 3 resta valida
      per i benchmark economici; NON si applica al caso reale TSTO senza
      un ripensamento del budget (parallelizzazione? tolleranze ODE piu'
      larghe? entrambe fuori scope qui, da riconsiderare se serve un run
      a convergenza).
      Bounds (lb/ub, decisione utente): ±50% attorno al nominale
      `GUIDANCE_VARS.csv` per le 10 variabili di guida rimaste (segno
      preservato per i coefficienti negativi), `Mpayload` in `[0, 6000]`
      kg (esplicito, non derivato dal nominale).
- [ ] **Gate M5**: run completo con feasibility su perigeo/apogeo/inclinazione + log riproducibile.
      Run esplorativo lanciato (`real_case/run_real_case.m`, seed=1,
      budget 300 eval) — **INTERROTTO, gate NON raggiunto**: bloccato da un
      problema trovato durante il run (sotto), non ancora arrivato a
      produrre un risultato. **SESSIONE SOSPESA qui su richiesta utente
      (2026-09-05)**: nessuna correzione applicata ancora, riprendere da
      qui.

      **PROBLEMA APERTO, NON RISOLTO**: alcune valutazioni di `traj_cost`
      restano bloccate per minuti/ore invece dei ~12s tipici (misurato su
      questa macchina N100, rif. `dev_vs_target_hardware` in memoria) —
      un run esplorativo da 300 eval e' arrivato a 2h19m+ senza terminare
      prima di essere interrotto manualmente. Causa: CMA-ES campiona in
      normalizzato SENZA clip a `[0,1]` (gap gia' noto, Fase 2), quindi
      puo' proporre `x` fisico fuori da `[lb,ub]` -- su un simulatore ODE
      reale questo puo' produrre geometrie di volo degeneri che fanno
      collassare il passo di `ode45` (non solo un obiettivo "brutto ma
      veloce" come sui benchmark sintetici).

      Diagnosi svolta (test di isolamento: una variabile alla volta
      perturbata dal nominale al bordo, resto invariato):
      - **`pitch_at_transition` (CAUSA CONFERMATA)**: bordo superiore
        attuale `ub=2.1 rad (120°)` supera il tetto FISICO di `pi/2 rad
        (90°)`. Motivo strutturale (da `guidance.m` case 2): il pitch di
        fase 2 e' `pi/2 + pitch_c1*dt^2 + pitch_c2*dt` con `pitch_c1` e
        `pitch_c2` SEMPRE negativi su tutto il loro range di bounds ->
        parte da 90° e decresce monotonicamente, non puo' MAI superare
        90°. Un `pitch_at_transition` (assetto assunto all'ingresso fase
        3) oltre 90° e' quindi strutturalmente irraggiungibile, produce un
        mismatch iniziale enorme sull'`incidence` di fase 3, corretta a
        rate fisso (`pitch_rate_transition`) troppo lento -> volo
        prolungato ad angolo d'attacco estremo -> rigidezza numerica.
        **Fix concordato in linea di massima ma NON ANCORA APPLICATO**:
        portare `ub` a `pi/2` (o poco sotto) invece di `nominale*1.5`.
      - **`transition_starting` (SOSPETTO, MECCANISMO NON CONFERMATO)**:
        bordo superiore `ub=45s` isolato da solo (con `pitch_at_transition`
        rimasto al nominale 1.4 rad, quindi SENZA sforare il tetto dei
        90°) si blocca ugualmente nel test di isolamento. Ipotesi non
        verificata: l'evento di fase 3 (`incidence==0`, rilevazione
        bidirezionale) fatica a localizzare un attraversamento poco netto
        quando l'`incidence` iniziale e' piu' piccola (~17° stimato, non
        impossibile) ma la correzione e' comunque lenta. DA INDAGARE.
      - Le altre 9 variabili, isolate singolarmente al bordo, completano
        regolarmente (anche quando producono forte infeasibility, gestita
        correttamente da ARCH) -- rif. `real_case/design_variables.csv`
        (nuovo file, tabella idx/nome/unita'/x0/lb/ub/campo-sovrascritto/
        note, colonna note aggiornata con questi due flag).
      - **NON risolutivo**: il clip di `x` a `[lb,ub]` in `traj_cost.m`
        (gia' implementato, utile per i casi PIU' grossolanamente fuori
        bounds tipo massa/quota negative) NON basta da solo: un punto
        clippato con piu' variabili contemporaneamente sui rispettivi
        bordi (non necessariamente il caso `pitch_at_transition`) puo'
        ricreare condizioni degeneri per combinazione, non per singolo
        valore fuori range.
      - **Scartato**: un ipotetico `MinStep` su `ode45` (non esiste
        nativamente in Octave/MATLAB per solver non-stiff; anche se
        emulato a mano, rischierebbe di far mancare/imprecisare la
        rilevazione degli `Events`, che sono la macchina a stati delle
        fasi di volo -- rischio inaccettabile).

      **Prossimo passo, da decidere a inizio prossima sessione** (proposto
      da Claude, non ancora scelto dall'utente): (a) applicare subito il
      fix di `pitch_at_transition` (causa confermata) e (b) indagare a
      parte il meccanismo di `transition_starting` prima di rilanciare il
      run esplorativo. Non procedere autonomamente oltre senza rileggere
      questa nota ed eventualmente confermare con l'utente.

      **AGGIORNAMENTO (2026-09-05, sessione successiva)**: causa
      `pitch_at_transition` risolta, ma con un fix diverso da quello
      proposto sopra (bound a `pi/2`) -- **decisione utente**: la variabile
      e' stata **rimossa dalle variabili di design** (n: 11->10), non
      semplicemente ri-bound. Motivazione utente: non e' un assetto libero,
      e' vincolata per fisica a coincidere con l'assetto raggiunto a fine
      fase 2 (coerente con la nota gia' in `guidance.m`, mai risolta prima
      d'ora). Implementato: `TSTO/source/simulator.m` (sezione 3g/3h)
      calcola ora `other.GUI.pitch_at_transition = other.GUI.last_pitch`
      automaticamente non appena la fase 2 termina (stesso
      `GUI.last_pitch` gia' calcolato li' per il case 3 di `guidance.m` --
      nessun nuovo hook necessario, il valore desiderato era gia'
      disponibile in quel punto). `guidance.m` case 3 invariato (legge
      ancora `GUI.pitch_at_transition`, ora popolato automaticamente
      invece che da `x`). Aggiornati di conseguenza: `TSTO/source/
      traj_problem.m` (10 componenti, non piu' 11), `TSTO/source/main.m`
      (x0 baseline), `real_case/traj_cost.m`, `real_case/run_real_case.m`
      (x_nom/bounds a 10 componenti), `real_case/design_variables.csv`
      (riga rimossa, idx 8-11 rinumerati 7-10). **NON ancora rifatto**: il
      run esplorativo (bloccato su questo bug) non e' stato rilanciato in
      questa sessione -- resta da fare, insieme all'indagine separata su
      `transition_starting` (ancora SOSPETTA, meccanismo non confermato,
      invariata rispetto a sopra).

      **Nota separata emersa in questa sessione (non ancora risolta)**:
      l'utente ha segnalato una presunta conversione gradi->radianti "a
      lettura" per le variabili angolari di `design_variables.csv`, che
      pero' NON esiste nel codice attuale (verificato: nessun file in
      `real_case/` o in TSTO fa conversioni di unita'; `design_variables.
      csv` non viene letto a runtime da nessuno script, resta una tabella
      di sola documentazione). La colonna `unit` del CSV e' inoltre
      incoerente in almeno un altro punto oltre al (ex) `pitch_at_
      transition`: `pitch_c1`/`pitch_c2` sono etichettate `deg_s2` con
      nominale CSV `-1`, ma il nominale reale in TSTO (`GUIDANCE_VARS.csv`)
      e' `-1.0e-4 rad/s^2` -- tre ordini di grandezza di scarto, stesso
      pattern di mislabeling. **Da chiarire con l'utente prima di
      intervenire**: se il CSV deve restare solo documentale (e allora va
      semplicemente risincronizzato ai valori reali) oppure se e' pensato
      come futura fonte di input in gradi da cui costruire `run_real_case.
      m` tramite una conversione ancora da scrivere.

      File coinvolti in questa indagine (nessuna modifica funzionale
      ancora, solo diagnosi): `real_case/traj_cost.m` (clip aggiunto),
      `real_case/run_real_case.m` (bounds/opts, invariati rispetto al
      problema aperto), `real_case/design_variables.csv` (nuovo, tabella
      di riferimento). TSTO: `source/init_state.m` spostato in
      `source/private/` (collisione di nome con `core/init_state.m`, fix
      GIA' APPLICATO e verificato, non fa parte del problema aperto).

      **AGGIORNAMENTO 2 (2026-09-05, stessa giornata, sessione
      successiva)**: risolta la nota separata sopra (conversione
      gradi<->radianti) e trovata una CAUSA CONCRETA e diversa per l'hang,
      non ancora corretta (decisione utente: fermarsi qui, nessun fix
      applicato).

      - **Conversione deg<->rad implementata** (decisione utente):
        `real_case/design_variables.csv` e' ora la fonte di verita' per
        `x0`/`lb`/`ub` (`real_case/run_real_case.m` lo legge riga per
        riga, non piu' derivazione +-50% dal nominale TSTO). Le 4
        componenti angolari (`pitch_c1`, `pitch_c2`,
        `pitch_rate_transition`, `AoA_rate`; indici 3,4,6,8) viaggiano in
        **gradi** nello spazio di `x` dell'ottimizzatore; `real_case/
        traj_cost.m` le converte in radianti con `deg2rad` subito dopo il
        clip ai bounds, appena prima di chiamare `traj_problem.m` (TSTO
        resta internamente in radianti, invariato). Round-trip verificato
        esatto in Octave. Il mislabeling di `pitch_c1`/`pitch_c2` nel CSV
        segnalato sopra resta pero' NON risincronizzato ai valori nominali
        reali: l'utente ha scelto di usare direttamente i valori che aveva
        messo nel file (bounds di ricerca voluti, non derivati dal
        nominale) -- non e' un refuso da correggere, e' lo spazio di
        ricerca scelto.

      - **Run esplorativo rilanciato DUE volte, bloccato ENTRAMBE le
        volte sul timeout di sicurezza di 3h** (non completato, 300 eval
        mai raggiunti): riproduzione confermata dell'hang, non piu' solo
        sospetto. Aggiunto **logging per-eval** in `real_case/
        traj_cost.m` (append su `real_case/eval_log.csv`, riga START prima
        di `traj_problem.m` e riga END dopo, `x` completo + timestamp +
        durata, file aperto/chiuso ad ogni scrittura per garantire il
        flush anche se il processo viene ucciso a meta' valutazione) --
        FONDAMENTALE per la diagnosi, resta attivo (side-effect
        deliberato, documentato nell'header del file, decisione utente).

      - **Provato e SCARTATO**: `ode23s` (unico solutore stiff core
        Octave davvero funzionante su questa build -- `ode15s` fallisce
        sempre per sundials mancante, `ode23t`/`ode113` non esistono senza
        `odepkg`) applicato SOLO alla fase 3 in `TSTO/source/simulator.m`.
        Non risolve l'hang in generale e introduce ~8x di overhead anche
        sui casi SENZA alcun sintomo di stallo (18s->146s misurato su un
        caso facile), rendendo impraticabile il budget del run
        esplorativo. **Revertito**, si resta su `ode45` ovunque; nota
        dell'esperimento lasciata inline in `simulator.m` per non
        riprovarlo alla cieca in futuro.

      - **CAUSA CONCRETA identificata dal log del secondo run** (diversa
        dall'ipotesi NaN/interpolazione discussa e scartata come
        probabile in questa sessione: le due interpolazioni attive nel
        loop `ode45`, in `eom.m`, sono gia' clampate ai bordi tabella --
        verificato leggendo il codice, non solo per assunzione): l'ultima
        riga del log e' uno START senza END, con
        **`pitch_rate_transition = 0`** (il suo stesso `lb` in
        `design_variables.csv`). Con rateo zero, `guidance.m` case 3
        (`pitch_rate = -sign(incidence) * GUI.pitch_rate_transition`)
        perde l'unico meccanismo di correzione dell'incidenza in fase 3:
        il pitch resta COSTANTE per tutta la fase, e l'uscita (`phase_
        event.m` case 3, trigger su `incidence==0`) dipende solo dalla
        rotazione "naturale" del vettore velocita' relativa sotto
        gravita' -- puo' richiedere una finestra molto lunga (fino al
        tetto `tmax_phase=1000s`) con il veicolo a un angolo d'attacco
        ampio e sostenuto per centinaia di secondi simulati, molti passi
        `ode45` piccoli per tenere le tolleranze. Meccanismo diverso e
        piu' diretto di `transition_starting` (SOSPETTO precedente,
        ancora non confermato ne' smentito, resta aperto) -- puo'
        comunque essere un fattore concorrente sullo stesso episodio, non
        sono ipotesi mutuamente esclusive.

      - **Fix proposto, NON applicato** (decisione utente: fermarsi qui,
        nessuna modifica di codice ne' nuovo run in questa sessione):
        alzare `lb` di `pitch_rate_transition` sopra zero in `design_
        variables.csv` (fix mirato, un solo numero, nessuna modifica di
        codice TSTO). Proposto anche, come rete di sicurezza generica
        indipendente da questa causa specifica: un controllo esplicito
        `isfinite` a fine `eom.m` su `dy` (e su `Mach`/`AoA` prima del
        clamp, che altrimenti maschera silenziosamente un eventuale NaN
        upstream invece di segnalarlo -- verificato: `max(NaN, a)` in
        Octave/MATLAB restituisce `a`, non NaN). **Riprendere da qui**:
        nessuna delle due modifiche e' stata scritta.

      **AGGIORNAMENTO (2026-09-05, sessione "fix-ode-hang"): hang RISOLTO
      alla radice, non piu' aggirato con isfinite/lb.** Decisione utente:
      invece dei due fix mirati sopra (mai applicati), sostituito
      l'integratore stesso. `ode45`/`ode23s` sono controllori d'errore
      LOCALE (RelTol/AbsTol): su un candidato quasi-inerziale per una
      finestra simulata lunga (il caso `pitch_rate_transition~0` sopra)
      possono restringere il passo a oltranza senza alcun vantaggio
      pratico rispetto alla tolleranza di missione (3% del target).
      L'utente ha scritto un RK5 esplicito a passo FISSATO da una regola
      cinematica (`TSTO/source/rk5.m`, Butcher 5° ordine con
      localizzazione lineare degli eventi stile `ode45`) invece che da un
      controllo d'errore: il passo e' proposto da uno `stepFcn`
      intercambiabile, poi SEMPRE clippato a `[tmin,tmax]` da `rk5.m` --
      questo limita il costo peggiore per fase a un numero di passi
      FISSO, `(tmax_phase)/tmin`, indipendente da quanto la fisica del
      candidato lo richiederebbe.

      Il "manca ancora" segnalato dall'utente all'apertura di questa
      sessione era proprio lo `stepFcn`: implementato in
      `TSTO/source/kinematic_step.m`, come richiesto sfruttando
      informazioni cinematiche istantanee (velocita', accelerazione) —
      non un errore locale. Regola: `h = frac * tau`, con
      `tau = |v|/|a|` (tempo caratteristico perche' l'accelerazione
      corrente "consumi" la velocita' attuale) e `frac` di default 0.05
      (`other.STEP.frac`, non calibrato — TODO PROVVISORIO nel file).
      Dinamica quasi-inerziale (il caso patologico) → `tau` grande → il
      passo cresce fino a `tmax` invece di restare piccolo come con
      RelTol fisso; dinamica rapida (accensione, pitch-over, staging) →
      `tau` si riduce e il passo si restringe di conseguenza.

      Bug corretti nella bozza originale di `rk5.m` (scritta dall'utente,
      non ancora eseguita — trovati leggendo il codice prima di
      eseguirlo, non solo a runtime): indice di loop `i` mai inizializzato
      (doveva essere `n_step`); `y` indicizzata per colonna (`y(:,i)`)
      invece che per riga (stato salvato come una riga per istante,
      `y(n_step,:)`); `t_next` letto da `t(i+1)` prima ancora di essere
      calcolato come `tn+h`; nessuna logica di crescita del
      preallocamento (`n=1000` fisso, il commento "puo' stretch-are"
      dichiarava l'intento ma non era implementato) — aggiunta crescita
      per raddoppio. Aggiunta anche una rete di sicurezza `max_steps`
      (analoga a `max_iterations` in `simulator.m`/`diverged_sigma` in
      `cmaes_core.m`): non dovrebbe mai scattare (h e' sempre >= tmin per
      costruzione) salvo bug futuri su h/tmin.

      Convenzioni di chiamata (dichiarate dall'utente nell'header
      originale di `rk5.m`, mantenute): `f` resta una closure a 2
      argomenti `(t,y)` — stessa forma gia' in uso con `ode45` in
      `simulator.m`, `other` gia' catturato — mentre `eventFcn` e
      `stepFcn` ricevono `other` come terzo argomento esplicito
      (`rk5.m` lo forwarda a entrambi). Questo ha richiesto in
      `simulator.m` di ricostruire `event_fun` come
      `@(t,y,other) phase_event(t,y,other,phase)` (cattura solo `phase`
      via closure, non piu' anche `other`) — `phase_event.m` stesso
      invariato.

      `simulator.m`: rimossa la chiamata a `ode45` e i default
      `config.AbsTol`/`config.RelTol` (non piu' letti da nessuno,
      sostituiti da `config.tmin=0.05` / `config.tmax=2`, entrambi
      TODO PROVVISORIO — non calibrati su un run a convergenza, solo su
      smoke-test, vedi sotto). `traj_problem.m`: forwarding di
      `opts.tmin`/`opts.tmax` aggiunto per simmetria con
      `opts.AbsTol`/`opts.RelTol` (questi ultimi lasciati, ora innocui).

      **Verificato (smoke-test in sessione, non un run a convergenza)**:
      1) round-trip nominale (`TSTO/source/main.m`, stesso x0 di sempre):
         `f=-4000`, `h=[1.9e-09, 9.3e-10, 2.8e-16]` — IDENTICO al
         risultato storico con `ode45`.
      2) il candidato ESATTO che con `ode45` restava bloccato oltre il
         timeout di sicurezza di 3h (`pitch_rate_transition~0`, decodificato
         da `real_case/eval_log.csv`): ora **21.9 s**, `f=-2491.34`,
         residui `h` enormi (candidato genuinamente pessimo/instabile,
         atteso — ARCH lo respinge correttamente in ranking, questo NON
         era mai stato in dubbio: il problema era solo il tempo di
         calcolo).
      3) un candidato "normale" dal vecchio `eval_log.csv` (mai bloccato,
         8.831 s con `ode45`): stesso identico `f=-4679.19`, ma in
         **1.797 s** — piu' veloce, non solo non-piu'-lento.
      Nessuna regressione osservata sui due casi nominali, hang risolto
      sul terzo. **NON ancora fatto**: un run esplorativo completo
      (Gate M5, 300 eval) con il nuovo integratore — i punti 1-3 sopra
      sono singole valutazioni, non la suite; `tmin`/`tmax`/`frac` restano
      TODO PROVVISORIO fino a un run a convergenza. L'indagine separata
      su `transition_starting` (SOSPETTA, mai confermata) resta aperta,
      ma e' ora meno urgente: il meccanismo che la rendeva pericolosa
      (hang illimitato) non esiste piu' con `rk5.m` a passo tettato.

      **Run esplorativo Gate M5 RILANCIATO E COMPLETATO** (stesso identico
      `run_real_case.m`, seed=1, `opts.max_eval=300`, nessuna modifica di
      budget): per la prima volta il run arriva in fondo invece di essere
      ucciso dal timeout di sicurezza di 3h. Durata totale **~22 min 22 s**
      (22:36:47 -> 22:59:09, 357 valutazioni incluso il polish finale, vs
      >3h x2 senza risultato prima del fix). Il candidato patologico
      identico a quello che prima si bloccava (`pitch_rate_transition~0`,
      stesso seed => stessa sequenza campionata da CMA-ES) e' ricomparso
      nel log e si e' risolto normalmente in linea con lo smoke-test.
      Risultato: `f_best=-6000` (Mpayload=6000 kg, il tetto superiore del
      bound su questa variabile), **`feasible=0`**, `n_eval=300 n_iter=30
      n_restarts=0 stop_reason=max_eval`. Warning non bloccante durante
      `feasibility_polish` (`sqp: QP subproblem is infeasible` in
      `arch_repair.m` -- il punto finale e' troppo lontano dal manifold
      dei vincoli perche' il repair locale converga, gestito correttamente:
      `result.feasible` resta 0, nessun crash, coerente col fix di Fase 4).

      **Non feasible non e' una sorpresa** (il commento gia' in
      `run_real_case.m` lo dichiarava: "run ESPLORATIVO... NON un'
      ottimizzazione a convergenza"): 300 eval su n=10 con 3 uguaglianze
      e' un budget minuscolo rispetto a quanto servito su g13 (n=5, decine
      di migliaia di eval per l'ottimo globale, Fase 3) -- `f=-Mpayload`
      spinge la massa al tetto superiore del bound indipendentemente dalla
      feasibility semplicemente perche' ARCH non ha ancora avuto modo di
      spostare il ranking verso una regione feasible in cosi' poche
      generazioni (n_iter=30, nessun restart IPOP scattato).

      **Scoperta rilevante per il prossimo budget**: il costo per
      valutazione assunto nel commento di `run_real_case.m` ("~12.3s")
      era calibrato su `ode45` ed e' ora OBSOLETO -- misurato su questo
      run, la stragrande maggioranza delle valutazioni costa **~1-2s**
      (714 righe di log / 22m22s ~ 3.8s/eval IN MEDIA, ma la mediana e'
      piu' vicina a 1-1.5s: la media e' alzata da poche valutazioni
      patologiche piu' lente, es. ~20s). Un budget molto piu' ampio
      (migliaia di eval) e' ora praticabile in un tempo di calcolo
      ragionevole, cosa che non era vera con `ode45`. **Decisione non
      ancora presa**: se/quando aumentare `opts.max_eval` per un
      tentativo di run a convergenza resta da decidere con l'utente, non
      assunto qui.

      **NUOVO REQUISITO NON-FUNZIONALE (2026-09-06, decisione utente):
      un'ottimizzazione completa di TSTO NON puo' durare piu' di 5 minuti
      sul PC target.** Non era presente ne' in S1 ne' altrove in questo
      documento fino ad ora -- e' un'informazione NUOVA che ridefinisce il
      problema, non un dettaglio di tuning. Run lanciato con
      `opts.max_eval=50000` (sessione precedente) **interrotto
      manualmente** (era a ~159 valutazioni dopo 40 min, palesemente
      incompatibile col nuovo requisito) invece di lasciarlo esaurire le
      96h di timeout di sicurezza: proseguirlo non avrebbe prodotto
      un'informazione diversa da quella gia' raccolta.

      **Analisi di fattibilita' eseguita in sessione (misure reali, non
      stime)**: strumentato un round-trip nominale isolato
      (`simulator()` diretto, non passando da `traj_cost.m`/CMA-ES):
      **7.47 s totali, 188 punti temporali accettati su tutte le fasi**
      (durata fisica simulata 490.83 s) => **~39.7 ms per punto RK5
      accettato**. Ogni punto RK5 costa 7 chiamate a `eom.m` (k1..k6 di
      `rk5.m` + 1 di `kinematic_step.m`) => **~5.7 ms per singola chiamata
      a `eom.m`**, a fronte di un contenuto di calcolo per chiamata
      minimo (poche operazioni vettoriali, 2 interpolazioni tabellari, una
      chiamata a `guidance.m`): il costo e' quasi certamente dominato
      dall'OVERHEAD DELL'INTERPRETE Octave (dispatch di funzione, accesso
      a campi di struct annidate ENV/AER/MOT/GUI/MIS ad ogni chiamata),
      non da un carico numerico reale -- un'implementazione compilata
      dello stesso calcolo e' plausibilmente 2-3 ordini di grandezza piu'
      veloce per chiamata (microsecondi, non millisecondi).

      **Il secondo fattore, indipendente dalla velocita' di calcolo, e'
      quante valutazioni servono strutturalmente**: l'unico dato empirico
      disponibile sul PROBLEMA (non sulla macchina) e' g13 (Fase 3,
      CLAUDE.md sopra), strutturalmente affine (uguaglianze non-lineari
      multiple) anche se piu' piccolo (n=5 vs n=10 qui): raggiungere
      l'OTTIMO GLOBALE con 10/10 seed e' costato **78.632–431.088
      valutazioni**. Pero' la sola FEASIBILITY (non l'ottimo globale) era
      gia' 16/16 anche al budget originale piu' piccolo (`max_iter=1232`,
      quindi un ordine di grandezza sotto quei numeri, prima che i restart
      IPOP profondi entrassero in gioco) -- rif. Fase 2 Gate M3. Il costo
      esplode con la PROFONDITA' di restart IPOP inseguita (lambda
      raddoppia ad ogni restart, vedi la discussione precedente in questa
      sessione), non con la feasibility di per se'.

      **Conclusione onesta**: con l'architettura attuale COSI' COM'E'
      (simulazione Octave interpretata, CMA-ES+ARCH con `max_restarts=9`
      inseguendo l'ottimo globale) il requisito di 5 minuti sul PC target
      e' con altissima probabilita' **INFATTIBILE**, indipendentemente
      dall'hardware: nessuna quantita' di velocita' di CPU aggiuntiva
      cambia il fatto che l'algoritmo, per come e' calibrato/usato ora,
      insegue un budget di valutazioni che puo' arrivare a centinaia di
      migliaia. **Plausibilmente fattibile SOLO combinando**: (a) un porting
      del blocco simulazione (`eom.m`, `guidance.m`, `phase_event.m`,
      interpolazioni, il loop `rk5.m`) in un linguaggio compilato
      (Fortran/C, richiamato da Octave via oct-file/MEX o processo
      esterno) per abbattere il costo per-valutazione di 2-3 ordini di
      grandezza, E (b) un ripensamento esplicito dell'ambizione
      dell'ottimizzazione sul caso reale: puntare a "feasible e buono" con
      un budget di restart IPOP DELIBERATAMENTE limitato (non
      all'inseguimento dell'ottimo globale certificato, che sui soli dati
      g13 richiederebbe centinaia di migliaia di valutazioni anche a
      costo-per-eval trascurabile). **Nessuna delle due e' stata avviata**:
      e' una decisione di architettura/scope, non un'esecuzione di
      routine -- rif. CLAUDE.md S0/S7 (fermarsi e chiedere su ambiguita'
      algoritmica alta), sottoposta esplicitamente all'utente a fine
      sessione invece di essere assunta.

      **AGGIORNAMENTO (2026-09-06, sessione "requisito 5 minuti"): leva
      (a) eseguita ed ECCEDE le attese; leva (b) NON ancora sufficiente,
      gate Fase 3 NON superato.** Piano approvato (formale, via plan mode)
      in `~/.claude/plans/mossy-percolating-map.md`.

      **Leva (a) — porting Fortran, risultati misurati**:
      - `TSTO/source/native/eom_core.f90` + shim `eom_oct.cc`: porting di
        `eom.m`+`guidance.m` (casi 1-6, le uniche fasi integrate).
        Validato numericamente su 18 stati campione multi-fase (max
        differenza assoluta 4.26e-14, rumore di floating-point) —
        **412.9x** di speedup per chiamata (5.89ms -> 0.014ms).
      - `phase_event_oct.cc` (stesso modulo Fortran, funzione
        `phase_event_native_f`): porting di `phase_event.m`. Validato
        (differenze ~0, metadata isterminal/direction identici su tutte
        le fasi) — **44.9x** (0.75ms -> 0.017ms).
      - Bug trovato SCRIVENDO il codice (non solo a runtime): `%` invece
        di `!` in due punti (un commento Fortran, un commento C++) --
        avrebbero rotto la compilazione; corretti prima di compilare.
      - `simulator.m`: `f_fun`/`event_fun` usano le versioni native se
        `exist(...,'file')==3` (fallback automatico alle .m interpretate
        se i .oct non sono presenti — nessuna rottura per chi non ricompila).
        `kinematic_step.m` esteso con `other.eom_fast` (stesso principio,
        cosi' anche la sua chiamata a eom, 1/7 per punto, usa il percorso
        veloce). Round-trip nominale (`main.m`) verificato INVARIATO
        (`f=-4000` esatto) ad ogni passo.
      - **Trovato un secondo collo di bottiglia NON previsto dal piano**:
        dopo aver portato eom.m+phase_event.m, il tempo totale di
        `simulator()` sulla traiettoria nominale e' sceso solo da 7.47s a
        1.30s (non l'atteso ~15-20x): `create_output.m` ha un secondo
        loop `for k=1:N` che RICALCOLA (interpretato) l'intera catena
        cart2geo/interp1x3/guidance/eval_AoA/interp2 per OGNI punto, solo
        per costruire gli array di reporting (`RES.theX/theMach/...`),
        anche con `config.silent=true` (che salta solo plotter/write_log,
        non create_output stesso). Verificato leggendo `eval_fgh.m` (unico
        consumatore di RES durante l'ottimizzazione): usa SOLO 4 scalari
        all'istante finale (`theMass(end)`, `theApogeeAltitude(end)`,
        `thePerigeeAltitude(end)`, `theInclination(end)`). Aggiunto
        `config.minimal_output` a `simulator.m`: se `true`, calcola SOLO
        questi 4 scalari dall'ultima riga di Y (stesse formule di
        `create_output.m`), saltando l'intero loop di reporting.
        `traj_problem.m` lo attiva sempre (unico chiamante durante
        l'ottimizzazione). Default `false` (nessun impatto su chiamanti
        che vogliono il RES completo, es. plotting/debug manuale).
      - **Risultato end-to-end combinato**: round-trip nominale
        `simulator()`: 7.47s -> 1.30s (solo native) -> **0.108s**
        (+ minimal_output). Batch di 30 candidati CASUALI entro i bounds:
        media **17ms/eval** (mediana 12.9ms, max 93.9ms) — ma vedi sotto,
        NON rappresentativo del comportamento reale di CMA-ES.

      **Leva (b) — test "vecchio percorso lento" INTERROTTO, superato
      dagli eventi**: il test `real_case/run_reduced_restart_test.m`
      (max_restarts=3/max_eval=5000, lanciato PRIMA del porting) era
      ancora in corso quando il porting ha reso l'intera premessa (calcolare
      su Octave interpretato) obsoleta — fermato manualmente (~870 righe
      di log, mai arrivato a conclusione), log archiviato
      (`eval_log_reduced_restart_test_superseded_*.csv`). Nessuna perdita:
      l'informazione che avrebbe dato (quanti eval servono con budget di
      restart limitato) e' ora ottenibile MOLTO piu' velocemente sul
      percorso nativo.

      **Gate Fase 3 (run calibrato sul percorso nativo): NON SUPERATO.**
      `real_case/run_real_case.m` aggiornato con `opts.max_eval=12000`
      (stimato ~3.4 min dalla media di 17ms/eval sui 30 campioni casuali).
      Risultato reale, cronometrato con `time` (shell, non stimato):
      - **`real = 8m58s`** per 12000 eval => **44.9ms/eval medio durante
        un vero run CMA-ES** (non 17ms): i 30 campioni casuali usati per
        calibrare sovra-rappresentavano traiettorie corte/degeneri
        (terminazione precoce su altitude-zero ecc.); CMA-ES, partendo da
        x0 e muovendosi con continuita', esplora una regione piu'
        "coerente" che produce traiettorie mediamente piu' lunghe/costose.
        **Lezione**: calibrare il costo/eval su campioni CASUALI uniformi
        nei bounds sottostima il costo reale di un run CMA-ES -- va
        ri-calibrato sul comportamento effettivo dell'ottimizzatore, non
        su un campionamento sostitutivo.
      - **`feasible=0`** anche a 12000 eval, **`n_restarts=0`** per
        l'intero run (nessun plateau tol_fun/tol_x/ill_conditioned/
        diverged_sigma mai scattato in 1200 iterazioni), `f_best=-6000`
        (Mpayload sul tetto superiore del bound) — **IDENTICO pattern**
        gia' osservato nel run esplorativo da 300 eval (Fase 5, sopra):
        l'ottimizzatore massimizza il payload senza mai trovare un punto
        feasible da cui quel massimo dovrebbe essere vincolato. A 40x piu'
        eval (300->12000) il sintomo NON e' cambiato.
      - **Implicazione**: 12000 eval a 44.9ms/eval eccede gia' da solo il
        tetto di 5 minuti (538s vs 300s) PRIMA ANCORA di chiedersi se
        bastano per la feasibility — e per quanto osservato sopra, tutto
        lascia pensare che NON bastino: 40x piu' budget (300->12000) non
        ha cambiato il sintomo (stesso blocco su Mpayload=6000,
        feasible=0, zero restart). Aumentare ulteriormente il budget da
        solo, senza capire perche' non scatta mai un restart ne' si trova
        mai un punto feasible, e' un'escalation non ancora concordata con
        l'utente (rif. CLAUDE.md S0/S7) -- non eseguita.
      - **Aperture NON investigate in questa sessione** (elenco onesto,
        nessuna assunta come causa): (i) il problema reale potrebbe
        semplicemente avere un floor di valutazioni per la feasibility
        molto piu' alto di g13 (landscape ODE-integrato, non polinomiale,
        con terminazioni precoci che "sprecano" parte della popolazione
        ogni generazione); (ii) l'assenza totale di restart in 1200
        iterazioni potrebbe indicare che sigma non si sta riducendo
        abbastanza (tol_x mai vicino) mentre il progresso e' comunque
        lento -- da verificare con un log di sigma/generazione, non
        disponibile qui (`opts.verbose=1` non produce output visibile in
        esecuzione non interattiva, problema gia' noto da sessioni
        precedenti); (iii) possibile interazione tra il floor di alpha=1.0
        in `arch_rank.m` (gap dichiarato fin da Fase 2, mai risolto) e un
        problema dove la feasibility e' particolarmente rara da campionare.

      **Prossimo passo, da decidere con l'utente (non assunto)**: (a) un
      run diagnostico piu' lungo (ora economico, minuti non giorni) senza
      il vincolo dei 5 minuti, solo per misurare il floor reale di eval-
      to-feasibility sul problema vero; (b) investigare direttamente
      perche' zero restart in 1200 iterazioni (log di sigma); (c)
      entrambe. Nessuna scelta fatta autonomamente.

      **AGGIORNAMENTO (2026-09-06, stessa sessione): opzione (a) eseguita
      -- primo `feasible=1` MAI raggiunto sul caso reale, ma con un floor
      di valutazioni molto piu' alto di g13.** Script
      `real_case/run_feasibility_floor_probe.m` (stesso x0/bounds/
      tol_con/seed=1 di `run_real_case.m`, `opts.max_eval=200000`,
      `opts.verbose=2` per la prima volta -- traccia gia' implementata in
      `cmaes_core.m`, mai attivata prima d'ora).

      Risultato: `feasible=1`, `f_best=-6000` (Mpayload al tetto
      superiore del bound -- stavolta PERO' un punto genuinamente
      feasible, non il sintomo bloccato visto a 300/12000 eval),
      `n_eval=202430`, `n_iter=1476`, `n_restarts=9` (tutti e 9 i restart
      IPOP calibrati esauriti, lambda arrivato a 5120), `stop_reason=
      max_eval` (si e' fermato per il tetto di 200000, non per
      convergenza -- avrebbe potuto continuare). Tempo reale (timestamp
      inizio/fine file): **~3h30m**.

      Diagnosi via il log verbose (dato nuovo, non disponibile prima):
      il PRIMO segmento (n_restarts=0, lambda=10) e' durato da solo 1273
      iterazioni (12730 eval) prima che sigma collassasse a 1.213e-07
      (convergenza numerica genuina via tol_x, NON un bug) senza mai
      trovare un punto feasible in quella regione -- **quasi identico**
      al run da 12000 eval (Fase 5 sopra, fermato a 1200 iter/12000 eval
      da max_eval): quel run si e' fermato ~73 iterazioni PRIMA che il
      primo restart naturale sarebbe comunque scattato. Il campione
      feasible e' stato trovato da qualche parte nei restart successivi
      (lambda crescente per doppiamento, popolazioni sempre piu' larghe),
      non per convergenza fine del segmento -- coerente con l'ipotesi
      "serve un campionamento ampio (numerosita' di popolazione), non
      solo tempo di ricerca" gia' ipotizzata sopra.

      **Implicazione per il requisito dei 5 minuti**: il floor reale di
      eval-to-feasibility su questo problema (~200000, non i ~10000 di
      g13 Fase 2 -- landscape ODE-integrato reale, non sintetico,
      confermato piu' difficile) e' un fattore ~20x oltre g13. A 44.9ms/
      eval (velocita' reale gia' misurata durante CMA-ES, dopo tutto il
      porting Fortran di questa sessione) 200000 eval = 9089s = 151 min,
      non 5. **Colmare questo gap richiederebbe un ulteriore ~30-40x di
      velocita'** (oltre il gia' ottenuto ~150x-400x sulle singole
      funzioni) — non piu' ottenibile dal solo porting della simulazione
      (gia' fatto): servirebbe parallelizzare la valutazione della
      popolazione su piu' core (rif. discussione precedente in sessione:
      il ciclo `for k=1:lambda_cur` in `cmaes_core.m` e' oggi
      strettamente seriale) e/o ripensare la strategia di ricerca stessa
      (rif. leva "ottimizzatore alternativo" gia' discussa e scartata
      come non ovviamente piu' efficiente in astratto, ma qui il vincolo
      e' concreto: serve *molta* popolazione larga per campionare un
      punto feasible raro, non necessariamente un ottimizzatore diverso).
      **Nessuna decisione presa**: sottoposta esplicitamente all'utente,
      sessione ancora aperta su questo punto.

      **AGGIORNAMENTO (2026-09-09, sessione "debug-solver"): trovata la CAUSA
      VERA del "non trova mai una regione feasible e incolla al bound la
      variabile dell'obiettivo", ed era un BUG, non una proprieta' del
      problema. Diagnosi completa e numeri in `real_case/diagnostic_plan.md`
      (piano approvato dall'utente, T1/T2 eseguiti).**

      Premessa non prevista: `TSTO/source/native/*.oct` NON sono versionati
      (rif. native/README.md) e in questo checkout non esistevano -> tutto
      girava sul fallback interpretato, **8.4 s/eval invece di 0.1 s**.
      Ricompilati in sessione con `mkoctfile`. Ogni cronometraggio fatto dopo
      la vendorizzazione di TSTO e' da rifare.

      - **T1 (sweep 1-D del payload, guida al nominale)**: feasible da 0 a
        15000 kg, non feasible da 20000 -> il tetto fisico e' ~2.5-3x sopra
        `ub=6000`. Quindi l'ipotesi "caso test non fattibile" e' SMENTITA e
        arrivare a `ub` e' la risposta CORRETTA per questo box (l'ottimo lo
        decide il box, non la fisica). Trovato anche il perche' i residui
        sono ~1e-9: `simulator.m` fasi 7-8 (`injection_target_orbit.m`)
        centrano il target PER COSTRUZIONE saturando sul propellente, quindi
        `ceq` e' quasi binaria (~1e-9 su tutto l'ammissibile, ordini di
        grandezza fuori) -- l'insieme ammissibile e' una REGIONE, non una
        varieta' di codimensione 3, e dentro non c'e' gradiente utile. E'
        anche il motivo del `sqp: QP subproblem is infeasible` del polish.
      - **T2 (frazione in banda per generazione, ri-valutando i candidati
        loggati del run da 12000 eval)**: ipotesi "banda eps troppo larga ->
        ranking degenere sul solo f" **FALSIFICATA** (in-band 0% in tutte le
        49 generazioni campionate: `eps_horizon`/`K0` non erano la causa).
        Trovata invece la causa vera: dalla generazione ~76 i residui del
        best sono COSTANTI a 3 cifre e la popolazione degenera (righe
        distinte per generazione: 10 -> 5 -> **1**), con **9 componenti su 10
        incollate al proprio lb/ub**. Meccanismo: `cmaes_ask.m` campiona
        senza bound handling (gap dichiarato in Fase 2) -> la media esce da
        `[0,1]^n` -> il clip aggiunto in Fase 5 in `real_case/traj_cost.m`
        riporta TUTTI i candidati sullo stesso bordo -> f e vincoli identici
        -> ranking tutto pareggi -> nessun segnale di selezione. Il clip,
        introdotto per curare l'hang di `ode45`, era diventato il meccanismo
        che uccideva la ricerca (prima di `rk5.m` il sintomo era mascherato
        dall'hang).

      **FIX 1 (decisione utente: opzione (a) fra le tre proposte) -- bound
      handling nel motore.** Nuovi `io/bound_transform.m` /
      `io/bound_transform_inv.m`: porting della boundary transformation di
      Hansen (pycma `cma/boundary_transformation.py`), mirroring periodico +
      patch quadratiche C1 ai bordi (`al=0.05`), identita' ESATTA in
      `[al,1-al]`. Il motore lavora ora in spazio NON vincolato e la
      trasformazione vive dentro la funzione obiettivo (`solver.m`:
      `fun_norm = fun_box(bound_transform(xn))`), quindi `/core` resta ignaro
      (S3) e ARCH non e' toccato. Scartate: (b) penalita' di box (S5.2) e
      (c) bound come `cineq` (richiederebbe valutare `f` fuori dominio --
      cioe' esattamente i punti degeneri su TSTO -- e diluirebbe 3
      uguaglianze di missione con 20 disuguaglianze di box sul ramo non
      validato).
      Verificato: unit test di PROPRIETA' (in-box, identita' interna esatta,
      |derivata|<=1, round-trip 2.4e-22, nessun plateau fuori dominio);
      regressione **verde** (sphere n=25 `f_best=1.53e-16` vs 1.13e-16 di
      Fase 3; g13 5 seed **5/5 feasible e 5/5 ottimo globale**, 64k-553k
      eval, 5-9 restart, in linea con Fase 3).
      Effetto sul caso reale (stesso x0/bounds/tol_con/seed, budget 2000
      eval): **`feasible=1` in 2020 valutazioni e 1 min 39 s**, 2020/2020
      valutazioni distinte, 2 restart IPOP -- contro `feasible=0` a 300 e a
      12000 eval e feasible solo a ~200000 (3h30m).
      **Due voci di questo documento vanno quindi lette come superate**: il
      "floor di eval-to-feasibility ~200000" era un artefatto del bug, non
      una proprieta' del problema; e la conclusione "requisito dei 5 minuti
      con altissima probabilita' INFATTIBILE" torna in discussione (99 s per
      un run che trova feasible). Attenzione: e' UN solo seed a budget
      ridotto, NON un run a convergenza su piu' seed -- non e' ancora una
      dimostrazione, e il Gate M5 resta aperto.

      **FIX 2 (decisione utente: opzione B della proposta ceq->cineq) --
      vincolo di disuguaglianza sul margine di delta-v.** Le 3 uguaglianze
      restano (opzione A, `|h_k|-tol_con_k<=0`, NON applicata). Aggiunto in
      TSTO `OPT.g = (dv_required - dv_available)/ue2 <= 0` (adimensionale),
      lungo la catena `injection_target_orbit.m` (2 output in piu', erano
      gia' calcolati in `deliver_delta_v` e scartati) -> `simulator.m`
      (`other.INJ`, popolata in fase 8) -> `eval_fgh.m` -> `traj_problem.m`
      (anche il ramo `catch` restituisce `g` di lunghezza costante: un
      `cineq` di lunghezza variabile romperebbe `local_cell2mat` in
      `arch_rank.m`, che deduce n_ineq dal primo individuo).
      Scala `ue2` = COSTANTE del veicolo, non `dv_available` (che dipende da
      x: cambierebbe l'ORDINAMENTO fra candidati, non solo la scala,
      rompendo l'invarianza monotona di S5.2).
      Misurato: dove `h` era piatta a ~1e-9, `g` e' continua e monotona
      (-1.057 a 4 t, -0.844 a 6 t, -0.242 a 15 t, -0.076 a 19 t) e si annulla
      verso il tetto -> il vincolo diventa ATTIVO all'ottimo, cioe' il
      problema non e' piu' degenere. Round-trip nominale invariato
      (`f=-4000`, `h~1e-9`); caso reale con `cineq` non vuoto (prima volta):
      `feasible=1` a 2000 eval.
      **Discontinuita' residua NON risolta, per decisione utente**: il salto
      a 20 t e' `END_PROP2` (propellente stadio 2 esaurito in fase 6, il run
      termina prima di fase 7/8, scelta di modellazione gia' documentata in
      `simulator.m`), non saturazione del burn. Un proxy continuo e' stato
      proposto e scartato: "la mancanza di dv non permette di arrivare a
      orbita target, e' gia' pagato" dai residui `h` (~3.9e6 m sul perigeo)
      -- duplicare quel segnale non aggiunge informazione. Coerente col
      fatto che ARCH ORDINA la violazione (`rank_v`), non la pesa: il
      fallback non deve portare informazione. Dove la magnitudine conta e'
      il controllore di alpha (`local_centering_error` usa `mean/std` dei
      `cineq` GREZZI): per questo il fallback del `catch` e' stato portato
      da 1e3 a 20 (ordinamento invariato: missione chiusa < non chiusa (10)
      < simulazione fallita (20), ma non piu' capace di dominare le
      statistiche con l'~1% di valutazioni fallite osservato).

      **Aperto, non toccato in questa sessione**: (i) `tol_fun` resta inerte
      finche' non esiste un punto feasible (`f_best_feas=Inf` ->
      `Inf-Inf=NaN` -> criterio mai vero): una popolazione bloccata non fa
      scattare restart -- meno urgente ora, difetto reale comunque; (ii)
      `ub` di Mpayload ~3x sotto il tetto fisico (T1) -> con questo box
      l'ottimo e' sul bordo per definizione, da decidere se e' un requisito;
      (iii) `eps_ineq`/scala per-vincolo per `cineq` in `arch_rank.m`: il
      caso reale ha ora UN solo `cineq` gia' adimensionale (configurazione
      benigna), il gap non e' stato davvero esercitato ne' validato.

      **AGGIORNAMENTO (2026-09-09, stessa sessione): cambio di caso di test
      -> `validation_test_2`, e accuratezza degli eventi portata sotto la
      tolleranza della funzione di costo (requisito utente).**

      - **Caso di test** (decisione utente): `run_real_case.m` usa ora
        `TSTO/input/validation_test_2` invece di `reference_LV`. Perigeo
        target 400 km invece di 200 -> orbita target CIRCOLARE 400x400 km
        (burn di injection piu' esigente); `GUIDANCE_VARS.csv` identiche, per
        cui `x0`/bounds di `design_variables.csv` restano validi senza
        modifiche; `tol_con` si adatta da se' (3% -> 12 km sul perigeo).
        **Bounds NON cambiati** (decisione utente esplicita), `ub(Mpayload)`
        resta 6000: su questo dataset il margine di delta-v a 6000 kg e'
        ancora `g=-0.83`, quindi l'ottimo resta il bordo del box -- registrato
        come fatto, non riproposto come modifica.

      - **Bug preesistente sbloccato** (`TSTO/source/injection_target_orbit.m`):
        `validation_test_2` NON partiva, nemmeno nella configurazione nuda del
        suo readme. Con target circolare l'intervallo di raggi ammissibili in
        fase 8 degenera in un PUNTO, e la validazione tollerava
        `max(1 mm, 1e-10*r)`: il punto di fine coast cadeva a 0.38 m dal
        target e l'intero caso veniva rifiutato. Il readme del dataset era
        stato validato con `ode45`, prima di `rk5.m` -- cadeva dentro il
        millimetro per fortuna, non per accuratezza. Fix: la proiezione
        radiale del punto di burn sull'intervallo ammissibile serve SOLO a
        calcolare il delta-v richiesto (una manovra impulsiva cambia la
        velocita', non la posizione: il punto deve appartenere all'orbita
        target), mentre **l'orbita raggiunta e' valutata sul punto VERO** --
        cosi' lo scarto ricompare nei residui `h` invece di essere nascosto
        dentro il modello (rif. S7).

      - **REQUISITO UTENTE (2026-09-09)**: *l'accuratezza del cross-over di
        apogeo deve essere migliore della tolleranza ammessa dalla funzione
        di costo.* Non era soddisfatto: `rk5.m` localizzava gli eventi per
        **interpolazione lineare** di tempo E stato dentro il passo; con
        passo cinematico fino a `tmax=2 s` e |v|~7.6 km/s la corda e' ~15 km,
        quindi errore di posizione di ordine km (misurato 1613 m sul raggio
        di apogeo con `Mpayload=0`, cioe' lo STESSO ordine della tolleranza
        di missione, 12 km).
        Fix in `rk5.m`: la localizzazione ora cerca il crossing dentro il
        bracket `[tn, tn+h]` con **secante safeguarded (Illinois)**, e ogni
        tentativo e' valutato **ri-integrando un sub-passo RK5** dal nodo
        `tn` -- lo stato all'evento ha quindi l'accuratezza del quinto ordine
        dell'integratore, non quella di una corda. Gli stadi di Butcher sono
        stati estratti in `rk5_single_step` (usata sia dal loop sia dalla
        rifinitura: nessuna duplicazione). Tolleranza sul bracket temporale
        `tol_t=1e-6 s` (~8 mm a 8 km/s), cap di 40 iterazioni come sola rete
        di sicurezza.
        **Misurato**: scarto sul raggio di apogeo **0.4 mm** su reference_LV
        e **4-8 mm** su validation_test_2 (era rispettivamente ~0.4 m e fino
        a 1613 m) -> 6 ordini di grandezza sotto `tol_con`. Costo: invariato
        entro il rumore (0.10-0.16 s per valutazione interpretata prima e
        dopo; la rifinitura aggiunge pochi sub-passi RK5 per evento, ~8
        eventi per run). Di conseguenza `radius_tolerance` in
        `injection_target_orbit.m` e' stata portata a **1 m** (>100x sopra lo
        scarto osservato, ~4 ordini sotto la tolleranza di missione).
        Verificato: tutti e tre i dataset chiudono la missione
        (`reference_LV` 200000.0012/400000.0004, `validation_test` idem,
        `validation_test_2` 400000.0002/400000.0005).
        **Nota onesta su un numero che PEGGIORA**: il round-trip nominale di
        `reference_LV` dava `h~1e-9` e ora da' `h~1e-2` m. Non e' una
        regressione di accuratezza: prima il punto di burn cadeva
        STRETTAMENTE DENTRO l'intervallo ammissibile (target ellittico
        200x400 km) e l'injection centrava il target per costruzione,
        azzerando `h` per definizione; ora il punto arriva 0.4 mm sopra
        `ra_target`, la proiezione entra in gioco e il residuo riportato e'
        quello VERO (~1 cm), non quello nascosto dalla proiezione. Entrambi
        sono comunque ~6 ordini di grandezza sotto `tol_con`.

      - **Stato del caso reale su `validation_test_2`** (run breve, 2000
        eval, seed 1, stesso x0/bounds/tol_con): `feasible=1`,
        `f_best~-5999` (Mpayload al bordo del box), ~107 iterazioni, 2
        restart IPOP. Differenza qualitativa rispetto a `reference_LV`: i
        residui `h` qui VARIANO con `x` (millimetri-metri, non ~1e-9
        costante), quindi le uguaglianze tornano a portare informazione al
        ranking.

      - **Requisito dei 5 minuti**: ABBANDONATO per ora (decisione utente),
        sostituito dall'obiettivo generico "massimizzare la velocita'".
        Rif. S2 "Vincoli operativi vincolanti" per la leva che NON va
        proposta.

      **AGGIORNAMENTO (2026-09-09, sessione "continuazione sul payload"):
      bound del payload allargato e METODO DI CONTINUAZIONE (proposta
      utente) -- migliore risultato ottenuto finora sul caso reale,
      23707 kg feasible con TUTTE le variabili interne al box.**

      - **Bound (decisione utente)**: `Mpayload` da `[0, 6000]` a
        `[4000, 30000]` kg in `real_case/design_variables.csv`. Motivo: con
        `ub=6000` l'ottimo era sul bordo PER COSTRUZIONE (a 6000 kg il
        margine di delta-v era ancora `g=-0.55`, cioe' 1878 m/s inutilizzati),
        quindi il box mascherava il trade-off fisico. Vale SOLO per Mpayload:
        i bound delle 9 variabili di guida restano invariati.

      - **Tetto fisico su `validation_test_2` (sweep 1-D, guida nominale)**:
        feasible fino a **19600 kg**, primo infeasible a 19800. `g` sale
        monotono verso zero (-1.042 a 4 t, -0.176 a 14 t, -0.013 a 19.6 t) ->
        il vincolo che morde e' ora la FISICA, non il box.

      - **Run brute-force (nessuna continuazione, seed 1)**: 12000 eval ->
        12235 kg (`g=-0.322`, ~20 min); 60000 eval -> **15945 kg**
        (`g=-0.313`, ~100 min, 3 restart). Feasible entrambi, tutte le
        variabili interne. **Ma `g` resta lontano da zero**: CMA-ES NON
        cavalca il vincolo attivo, lascia delta-v (e quindi payload) sul
        tavolo. Misurato: bisecando il payload sulla guida del run da 60000
        eval si arriva a 17098 kg, cioe' **1153 kg lasciati sul tavolo** da
        un run di 100 minuti.

      - **METODO DI CONTINUAZIONE (proposta utente)**:
        `real_case/run_continuation.m`. Un punto feasible con delta-v
        residuo certifica che tutto il segmento di payload sotto di se' e'
        DOMINATO (payload minore = vincolo piu' lasco), quindi non va
        ri-cercato: si alza `lb(Mpayload)` a quel livello e si riparte a
        caldo. Lecito qui perche' `f=-Mpayload` dipende da UNA variabile e
        il vincolo attivo e' monotono in essa (misurato, sweep sopra).
        Risultato, **20053 valutazioni (~27 min)**: 12235 (seed) -> 14525
        (bisezione) -> 17810 -> 21412 -> **23707 kg**, `feasible=1`,
        `|h| = [0.67 mm, 2.0 mm, 5e-16]` contro `tol_con = [12 km, 12 km,
        0.0149]`, TUTTE le 10 variabili interne al box (payload al 75.8%).
        Cioe' **+48% di payload con 1/3 delle valutazioni** rispetto al run
        brute-force da 60000 eval.

      - **Due errori di progetto trovati ESEGUENDO il metodo** (rif. S7,
        entrambi corretti, entrambi istruttivi):
        1. **Il predittore non puo' extrapolare `g` a zero.** Prima versione:
           pendenza locale `dg/dMpayload` -> payload a cui `g=0`. SBAGLIATO:
           il vincolo attivo al tetto non e' `g` (continuo) ma la
           discontinuita' `END_PROP2` (propellente stadio 2 esaurito in fase
           6), che arriva PRIMA. Misurato sulla guida del seed: ultimo
           feasible 14000 kg con `g=-0.176`, muro fra 14000 e 15000, mentre
           l'estrapolazione prevedeva 16646 kg -> `x0` finiva 2.6 t oltre il
           muro, in una regione interamente infeasible da cui lo stadio non
           e' piu' rientrato (5000 eval, zero feasible). Sostituito con
           **bisezione del muro** a guida congelata (~9 eval, risoluzione 50
           kg): trova il limite VERO qualunque dei due vincoli lo produca.
        2. **`sigma0` va commisurata alla fetta lasciata dal ratchet, non al
           box.** Con `back_off=250` kg la fetta ammissibile era 250 kg e
           `sigma0=0.15` dava un passo di ~2360 kg sul solo payload: ~10x
           piu' largo della regione da trovare -> 5000 eval, ZERO punti
           feasible, PUR partendo da un `x0` feasible (che CMA-ES non valuta
           mai: campiona ATTORNO a `xmean`). Con `sigma0=0.03` e
           `back_off=1000` kg lo stesso stadio ha guadagnato +3189 kg.

      - **Meccanica osservata (perche' i due pezzi sono complementari)**: il
        solver spesso NON alza il payload, alza l'EFFICIENZA della guida, e
        il guadagno si presenta come delta-v residuo (stadio 3: payload
        +108 kg ma `g` da -0.003 a -0.181); la bisezione lo incassa poi in
        payload (+2295 kg in 8 eval). CMA-ES cerca, la bisezione monetizza.

      - **Limiti dichiarati (NON risolti)**: (i) il ratchet e' MONOTONO
        sull'obiettivo -- se l'ottimo globale richiedesse una guida in un
        bacino raggiungibile solo passando per payload piu' bassi di quello
        gia' certificato, il metodo lo esclude (compromesso deliberato: la
        garanzia globale con questo budget non c'era comunque); (ii) 23707 kg
        e' un LOWER BOUND del tetto reale, non un ottimo certificato: lo
        stadio 4 (`lb=22707`) non ha trovato punti feasible in 5000 eval, ed
        e' un fallimento di RICERCA, non una prova di tetto; (iii) tutto su
        UN seed (seed=1), nessuna statistica multi-seed; (iv) resta valido
        che oltre il muro la violazione non porta informazione direzionale
        (`g` = fallback costante 10, `|h|` ~6.7e6 m quasi piatta), quindi la
        ricerca non sa da che parte rientrare -- e' la ragione strutturale
        dei fallimenti di stadio.

      - **Opzione strutturale proposta e NON eseguita (serve ok utente)**:
        eliminare `Mpayload` dalle variabili di ricerca e derivarlo per
        bisezione da ogni guida candidata (formulazione bilevel: 9 variabili,
        obiettivo = payload al muro, ogni candidato feasible per costruzione,
        nessuna discontinuita' da inseguire). Costo ~5-9 valutazioni per
        candidato, warm-startabile dal muro precedente.

      **AGGIORNAMENTO (2026-09-09, sessione "procedura di continuazione"):
      la continuazione diventa una PROCEDURA parametrica
      (`real_case/run_continuation.m`, funzione con struct di opzioni) e il
      predittore passa in MASSA. Decisione utente: non si adotta la
      formulazione bilevel proposta sopra ("tieni cosi'").**

      - **Controlli esposti all'utente** (richiesta esplicita): `n_stage`
        (stadi di continuazione), `stage_eval` e `stage_iter` (budget per
        stadio, scalare o VETTORE per-stadio), `max_restarts` (restart IPOP
        per stadio), `sigma0_warm/cold`, `back_off`, `x0_retreat`, `patience`,
        `vary_seed`, parametri del predittore (`ratio_guess`, `ratio_safety`,
        `push_max`, `bisect_tol`), `min_gain`, `dataset`, `seed`. Il merge
        delle opzioni RIFIUTA i campi non riconosciuti (un typo non passa
        silenzioso).

      - **Nuova diagnostica esposta da TSTO** (non un vincolo): `prop_residual`
        = propellente residuo stadio 2 = `theMass(end) - (Minert2 + Mpayload)`,
        aggiunta come 4a uscita opzionale di `eval_fgh.m` -> `traj_problem.m`
        -> `real_case/traj_cost.m`. Il solver ne chiede 3 e non la vede: il
        contratto S4 resta invariato.

      - **MISURA CHIAVE: il muro del payload e' una BIFORCAZIONE DI TANGENZA,
        non un esaurimento graduale.** In fase 6 l'apogeo osculante sale e
        sfiora il target; con poco payload in piu' non lo raggiunge, l'evento
        non scatta e il motore brucia fino a esaurimento (`END_PROP2`).
        Misurato sulla guida del primo seed:
          14525 kg -> prop_res 1912.50 kg, deficit apogeo 0.4 mm,  g -0.098, OK
          14550 kg -> prop_res    0.00 kg, deficit apogeo 164.5 km, g +10,   NO
        Nessuna quantita' attraversa lo zero in modo continuo: ne segue che
        NESSUN predittore puo' essere esatto, e che serve sempre un correttore
        (bisezione). Sul muro restano ~1900 kg di propellente INUTILIZZABILE
        bloccati dalla tangenza: e' il margine che gli stadi CMA-ES cercano di
        liberare trovando una guida meno tangente.

      - **TSIOLKOVSKY testato come predittore (proposta utente) e RIGETTATO
        come tale, mantenuto come primo guess.** Con Delta-v invariante,
        `m_wall = MProp2*(Minert2+prop_res+m)/(MProp2-prop_res) - Minert2` e
        `r = R/(R-1)`. Misurato (muro vero 14537 kg): da 14525 predice 16802
        (pendenza misurata: 14992), da 14000 predice 18175 (misurata: 15861);
        `r` = 1.19 contro 0.24 misurato vicino al muro, un fattore 5. Sbaglia
        dal lato OTTIMISTICO perche' ignora che il Delta-v RICHIESTO cresce col
        payload e che il muro e' una tangenza. Resta pero' il guess giusto
        quando NON esistono run precedenti: si calcola dalle masse del veicolo
        invece di essere scelto a mano, e sovrastimando genera subito il
        bracket superiore. Da lI' in avanti subentra la pendenza misurata.

      - **`r` NON e' una costante del veicolo**: misurato 0.217 sul seed, 0.833
        e 1.098 su altri punti di guida (fattore 5). Va ri-misurato localmente
        ad ogni coppia di punti; la persistenza nel seed serve come guess
        iniziale, non come verita'.

      - **MISURA CHIAVE 2: il rendimento del budget PER STADIO satura quasi
        subito.** A `lb`, `x0`, `sigma0` e seed identici, lo stesso stadio ha
        dato **esattamente** lo stesso risultato con 3000, 6000 e 10000
        valutazioni (16769.9 kg, budget speso tutto, nessun arresto anticipato).
        Cio' che fa progredire e' il RESTART, il PUSH e l'alzata di `lb`, non la
        lunghezza dello stadio. Conseguenza di progetto: `vary_seed` (default
        true) -- ri-tentare uno stadio a vuoto con lo STESSO seed rigioca la
        ricerca identica, e non e' un ri-tentativo.

      - **`x0_retreat`**: il push lascia il punto ESATTAMENTE sul muro, dove
        ogni perturbazione della guida e' infeasible e l'obiettivo punta fuori
        dalla regione ammissibile -- la peggiore condizione iniziale per
        CMA-ES. Separati i due ruoli: punto CERTIFICATO (riportato) e punto di
        PARTENZA (arretrato di `x0_retreat` dentro la fetta). Misurato: +753 kg
        sullo stesso stadio a budget invariato (15935.8 -> 16688.5 kg).

      - **Confronto a parita' di seed (12235 kg) e di budget (~20.5k eval)**:
        budget CRESCENTE `[1500 3000 6000 10000]` + 2 restart + retreat ->
        **17127.6 kg in 20574 eval**; budget COSTANTE 5000/stadio + 9 restart
        + x0 sul muro -> **23707 kg in 20053 eval**. La configurazione a stadi
        corti e' molto piu' efficiente sul PRIMO stadio (1510 eval danno 16688
        kg, il 94% di quanto 5009 eval danno) ma NON arriva allo stesso punto
        finale: la leva mancante sono i restart per stadio.

      **AGGIORNAMENTO (2026-09-09, RELEASE 2.0.0): trovata la causa della
      varianza (il restart Sobol), corretta secondo la regola dell'utente, e
      fissati i default ufficiali. Miglior risultato mai misurato:
      24655.3 kg in 20075 valutazioni.**

      - **CAUSA della varianza: `core/ipop_restart.m`.** Il restart
        (a) sostituiva `xmean` con un punto Sobol nell'INTERO box, buttando via
        il warm start e rimettendoci `sigma0` attorno -- ne' sfruttamento (posto
        sbagliato) ne' esplorazione (passo piccolo); (b) il `jitter` pesca dallo
        stream RNG, il cui stato dipende da quante iterazioni e' durato il
        segmento precedente -> due run identici a meno di 1.8 kg su x0 finivano
        in bacini diversi (15935 contro 17714 kg allo stesso stadio). Tutta la
        varianza del risultato veniva da lI'.

      - **REGOLA UTENTE applicata**: "se la soluzione e' fattibile il restart si
        basa sulla soluzione precedente; ripartire da Sobol+jitter ha senso solo
        per soluzione infeasible". Implementata come `opts.restart_mode`
        ('auto' default | 'sobol' | 'warm') in `io/parse_opts.m` +
        `core/ipop_restart.m`: con un punto ammissibile noto il restart e'
        CALDO (x_best_feas + `restart_jitter`), altrimenti Sobol. `/core` resta
        dominio-agnostico: riceve "il miglior punto noto", non sa cosa sia.
        La parte "predizione dal propellente" NON e' entrata nel motore (e'
        fisica del lanciatore): vive in `run_continuation.m`.

      - **`x0` ORA VIENE VALUTATO** (`core/cmaes_core.m`, 1 valutazione).
        CMA-ES campiona ATTORNO a xmean e non lo valutava mai, con due
        conseguenze misurate: (i) con un x0 AMMISSIBILE un run che non trovava
        punti ammissibili restituiva un punto PEGGIORE del guess dell'utente
        (accadeva in ogni stadio fallito); (ii) il restart caldo non poteva
        attivarsi perche' `x_best_feas` era vuoto. Non altera l'algoritmo:
        xmean non entra nel ranking, solo nei tracker.

      - **REGRESSIONE VERDE** dopo le modifiche a `/core`: sphere n=25
        `f_best=3.93e-20` (era 1.53e-16 -- MIGLIORE di 4 ordini: senza vincoli
        ogni punto e' ammissibile, quindi il restart ri-centra sul best invece
        che su un punto casuale); g13 **3/3 ottimo globale** (56569, 115913,
        512953 eval; 4, 6, 9 restart), in linea con Fase 3 (64k-553k) e con
        esattamente +1 valutazione per run (quella di x0). Il restart caldo NON
        ha distrutto la ricerca globale.

      - **Bug corretto in `run_continuation.m`**: `min_gain` veniva usato anche
        come criterio di ACCETTAZIONE, quindi un push che guadagnava 83 kg
        veniva contato come stadio a vuoto E il punto scartato. Ora un
        miglioramento vero si accetta sempre; `min_gain` governa solo la
        `patience`.

      - **`explore_every` (default 2)**: alterna stadi CALDI (restart caldo) e
        ESPLORATIVI (restart Sobol), a parita' di `sigma0_warm`. Misurato che la
        differenza deve stare SOLO nel modo di restart: uno stadio esplorativo
        avviato con `sigma0_cold=0.3` dentro una fetta ammissibile di ~1000 kg
        rende quasi ogni campione infeasible e torna x0. Il ratchet rende
        l'esplorazione SENZA RISCHIO (uno stadio fallito non puo' perdere il
        payload certificato), quindi conviene tenerla.

      - **DEFAULT UFFICIALI** (`local_defaults` in run_continuation.m):
        `n_stage=8`, `stage_eval=2500` costante, `max_restarts=3`,
        `explore_every=2`, `patience=3`, `x0_retreat=500`, `back_off=1000`,
        `sigma0_warm=0.03`, `vary_seed=true`, `ratio_guess=[]` (Tsiolkovsky).

      - **RUN UFFICIALE 2.0.0** (seed 1, dal seed a 12235 kg, 20075 eval):
        16688.5 -> 16771.7 -> 16792.3 -> 17146.5 -> 21878.9 -> 21916.8 ->
        24655.1 -> **24655.3 kg**, `g=-1.08e-04`, `prop_res=3 kg`,
        `|h| = [2.5 mm, 7.6 mm, 4.4e-16]` contro `tol_con=[12 km, 12 km,
        0.0149]`, TUTTE le 10 variabili interne al box (payload al 79.4%),
        `r` appreso 1.1166. Batte il 23707 kg precedente a parita' di budget.
        Gli stadi 5 e 7 portano +4.7 t e +2.7 t, gli altri quasi nulla: la
        distribuzione del guadagno resta molto disomogenea (un solo campione,
        nessuna statistica multi-seed).

- [x] Dimensione di calibrazione benchmark: usata n=25 per sphere (proposta
      originale), n=5 per g13 (dimensione nativa del problema, non scelta),
      n=2 per rosenbrock vincolata (dimensione nativa della formulazione
      standard "cubic-and-line"). Nessuna obiezione sollevata durante la
      Fase 3, proceduto (gate M4, §11).
- [x] Conferma g13 come benchmark con uguaglianze: confermato per uso (gate
      M3, Fase 2, kick-off-prompt.md lo indicava esplicitamente).
- [ ] Numero/ordine futuri di `cineq` quando usciranno dal placeholder.
- [ ] Attivazione o meno dell'optimality-polish (guida localmente liscia?).
