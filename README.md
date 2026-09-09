# solver — CMA-ES + ARCH + continuazione (Octave/MATLAB)

Ottimizzatore black-box vincolato **generico e dimension-agnostic**: motore **CMA-ES**
(base `purecmaes.m` di Hansen) + gestione vincoli **ARCH** (Sakamoto & Akimoto 2022).
**Niente Augmented Lagrangian** (decisione di progetto vincolante).

Applicazione di riferimento: massimizzare la **massa payload** di un lanciatore a due
stadi a propulsione liquida (simulatore **TSTO**, incluso nel repository) rispettando i
vincoli di missione — quota di perigeo, quota di apogeo, inclinazione — e il margine di
delta-v del burn di injection.

> Per sviluppare: leggere **`CLAUDE.md`** (scopo, contratti, regole, piano, misure
> storiche). In caso di dubbio o contraddizione: chiedere, non indovinare.

---

## Novità della release 2.0.0

1. **Metodo di continuazione a stadi** (`real_case/run_continuation.m`): il payload viene
   spinto per stadi, con `lb(Mpayload)` che sale al livello certificato ad ogni passo.
2. **Predittore in massa + bisezione** ("push al muro"): a guida congelata il payload
   viene portato al proprio limite fisico in poche valutazioni, invece di chiederlo alla
   ricerca stocastica.
3. **Restart IPOP caldo** (`core/ipop_restart.m`): con un punto ammissibile noto il
   restart riparte da lì; il re-seeding Sobol globale resta per il caso "non so nulla".
4. **`x0` viene valutato** (`core/cmaes_core.m`, 1 valutazione): il solver non può più
   restituire un punto peggiore del guess dell'utente.
5. **Bound handling di Hansen** (`io/bound_transform.m`): il motore lavora in spazio non
   vincolato, la trasformazione vive dentro la funzione obiettivo. Ha risolto il bug per
   cui la ricerca collassava sui bordi del box.
6. **Vincolo di disuguaglianza sul margine di delta-v** e **accuratezza degli eventi**
   (localizzazione dell'apogeo per secante safeguarded, errore da ~1.6 km a ~5 mm).

---

## Installazione

```bash
git clone https://github.com/volpegiocosa-rgb/solver_project.git
cd solver_project
# consigliato: kernel Fortran nativi (~150-400x piu' veloci dell'interpretato)
sudo apt install octave-dev gfortran
cd TSTO/source/native
mkoctfile eom_oct.cc eom_core.f90 -o eom_native.oct
mkoctfile phase_event_oct.cc eom_core.f90 -o phase_event_native.oct
```

I `.oct` **non sono versionati**: senza compilarli tutto funziona comunque (fallback
automatico sulle funzioni Octave interpretate), solo ~150-400x piu' lento. TSTO e'
incluso nel repository (`TSTO/`, vendorizzato via `git subtree`): un solo clone basta.

---

## Uso

### Caso reale (payload del lanciatore)

```bash
octave main.m
```

`main.m` lancia `run_continuation()` con i default. Il punto certificato viene salvato in
`real_case/warm_start.mat`: **un nuovo lancio riparte da lì e migliora, non ricomincia.**

Con controlli espliciti:

```matlab
addpath('real_case');
out = run_continuation(struct( ...
        'n_stage',       8, ...            % stadi di continuazione
        'stage_eval',    2500, ...         % scalare o VETTORE per-stadio
        'stage_iter',    Inf, ...          % iterazioni/stadio (Inf = default parse_opts)
        'max_restarts',  3, ...            % restart IPOP per stadio
        'explore_every', 2));              % ogni N-esimo stadio e' esplorativo
```

Un campo non riconosciuto produce un **errore esplicito** (un typo non passa silenzioso).

### Solver generico (qualunque problema vincolato)

```matlab
[f, cineq, ceq] = my_problem(x);      % cineq <= 0, ceq == 0
bounds.lb = lb; bounds.ub = ub;
result = solver(@my_problem, bounds, struct('seed', 1, 'tol_con', tol_vec));
```

### Benchmark (validazione)

```matlab
addpath('benchmark'); run_benchmarks(struct());   % sphere, Rosenbrock vincolata, g13
```

---

## Come funziona la continuazione

Un punto ammissibile con **risorse residue** certifica che tutto il segmento di payload
sotto di se' e' **dominato** (payload minore = vincolo piu' lasco), quindi non va
ri-cercato. Lecito qui perche' `f = -Mpayload` dipende da **una** variabile e il limite e'
monotono in essa. Ogni stadio fa tre cose:

| passo | cosa fa | costo tipico |
|---|---|---|
| **ricerca** | CMA-ES+ARCH sulla guida (9 variabili) e sul payload | 2500 valutazioni |
| **push al muro** | predittore in massa + bisezione a guida congelata | 1-10 valutazioni |
| **ratchet** | `lb(Mpayload)` sale al livello certificato, warm start arretrato | 0 |

### Il predittore

Il limite del payload **non** e' un esaurimento graduale di risorse: e' una
**biforcazione di tangenza**. In fase 6 l'apogeo osculante sale e sfiora il target; con
poco payload in piu' non lo raggiunge, l'evento non scatta e il motore brucia fino a
esaurimento. Misurato:

| Mpayload | propellente residuo | deficit apogeo | `g` | esito |
|---|---|---|---|---|
| 14525 kg | 1912.50 kg | 0.4 mm | −0.098 | ammissibile |
| 14550 kg | 0.00 kg | 164.5 km | +10 | muro |

Nessuna quantita' attraversa lo zero in modo continuo, quindi **nessun predittore puo'
essere esatto**: il predittore serve a generare un **bracket** in 1 valutazione, e la
bisezione lo chiude. Il rapporto di scambio `r = dMpayload/dMprop` viene ri-misurato ad
ogni coppia di punti (non e' una costante: misurato fra **0.22 e 1.10** su punti di guida
diversi) e persistito nel seed come guess iniziale. Senza dati precedenti il primo guess
viene dall'**equazione di Tsiolkovsky** sulle masse del veicolo.

---

## Risultati misurati

Dataset `TSTO/input/validation_test_2` (orbita target circolare 400x400 km), seed 1,
`Mpayload` in `[4000, 30000]` kg, macchina di sviluppo Intel N100.
Tutti i punti sotto sono **ammissibili per-vincolo**: `|h| <= tol_con = [12 km, 12 km,
0.0149 rad]`, tipicamente residui di **millimetri**.

| metodo | valutazioni | Mpayload |
|---|---|---|
| CMA-ES+ARCH diretto | 12 000 | 12 235 kg |
| CMA-ES+ARCH diretto | 60 000 | 15 945 kg |
| solo "push al muro" sul punto precedente | +9 | 17 098 kg |
| continuazione, stadi lunghi tutti uguali (pre-2.0.0) | 20 053 | 23 707 kg |
| **continuazione, default 2.0.0** | **20 075** | **24 655 kg** |

Il primo stadio e' il piu' redditizio: **250 valutazioni** bastano per superare quanto il
metodo diretto ottiene in **60 000**.

### Run ufficiale della release 2.0.0

`run_continuation()` con i default, seed 1, dal seed a 12 235 kg. Ogni stadio: ricerca,
push al muro, ratchet.

```
 stadio         lb         x0       stadio    dopo push
      1      13527      14027      16688.5      16688.5
      2      15688      16188      16188.5      16771.7
      3      15772      16272      16271.7      16792.3
      4      15792      16292      16777.4      17146.5
      5      16147      16647      19794.6      21878.9
      6      20879      21379      21378.9      21916.8
      7      20917      21417      23822.4      24655.1
      8      23655      24155      24155.1      24655.3

Mpayload = 24655.3 kg    g = -1.08e-04    prop_res = 3 kg
|h| = [2.5 mm, 7.6 mm, 4.4e-16 rad]   tol = [12 km, 12 km, 0.0149 rad]  -> feasible
r appreso = 1.1166 kg payload / kg propellente
```

**Tutte e 10 le variabili sono interne al box** (payload al 79.4%), `g` e' praticamente
nullo e `prop_res = 3 kg`: la soluzione sta **esattamente sul limite fisico** del
lanciatore, non su un bordo del dominio di ricerca. I residui dei vincoli di missione sono
millimetrici contro una tolleranza di 12 km.

### Tre misure controintuitive (documentate perche' cambiano le scelte di default)

1. **Il budget per stadio satura quasi subito.** A `lb`, `x0`, `sigma0` e seed invariati,
   lo stesso stadio ha dato **esattamente** lo stesso risultato con 3000, 6000 e 10000
   valutazioni (budget speso tutto, nessun arresto anticipato). Cio' che fa progredire e'
   il restart, il push e l'alzata di `lb` — non la lunghezza dello stadio. Da qui il
   default "molti stadi corti".
2. **Tsiolkovsky e' un predittore peggiore della pendenza misurata.** Con delta-v
   invariante da' `r = 1.19` contro `0.24` misurato vicino al muro (fattore 5) e stima il
   muro a 16802 kg contro 14537 reali: ignora che il delta-v *richiesto* cresce col
   payload e che il muro e' una tangenza. Resta il guess giusto solo quando non ci sono
   dati precedenti.
3. **`sigma0` va commisurata alla fetta lasciata dal ratchet, non al box.** Con fetta di
   250 kg e `sigma0 = 0.15` (passo ~2400 kg) uno stadio ha fatto 5000 valutazioni con
   **zero** punti ammissibili, pur partendo da un `x0` ammissibile — CMA-ES campiona
   *attorno* a `xmean` e (prima della 2.0.0) non lo valutava mai.

---

## Limiti dichiarati

- **La ricerca e' caoticamente sensibile alle condizioni iniziali.** La stessa
  configurazione ri-eseguita con `x0` diverso di **1.8 kg** ha dato 15 935 kg invece di
  17 714 kg allo stesso stadio: il landscape della guida e' multimodale e i salti grossi
  dipendono da dove cade il re-seeding. Il default alterna quindi stadi **caldi**
  (economici, affidabili) e stadi **esplorativi** (`explore_every`), e il ratchet rende
  l'esplorazione **senza rischio**: uno stadio che fallisce spreca budget ma non puo'
  perdere il payload certificato. Il run ufficiale sopra mostra il meccanismo — gli stadi
  2, 3, 6 e 8 guadagnano quasi nulla, il 5 e il 7 portano +4.7 t e +2.7 t.
  **Un singolo run resta comunque un singolo campione**: non c'e' garanzia che 20 000
  valutazioni diano 24.6 t su un altro seed.
- **`out.Mpayload` e' un lower bound del tetto reale**: uno stadio che non trova punti
  ammissibili e' un fallimento di *ricerca*, non una prova di tetto.
- **Il ratchet e' monotono**: esclude per costruzione un ottimo raggiungibile solo
  passando per payload piu' bassi di quello certificato. Compromesso deliberato.
- **Nessuna statistica multi-seed** sul caso reale: tutti i numeri sopra sono singoli run.
- I default della continuazione e diversi parametri del simulatore (`tmin`, `tmax`,
  `frac` in `kinematic_step.m`, `restart_jitter`) **non sono calibrati**: sono marcati
  come provvisori nel codice.
- `bench_rosenbrock_con` (sole disuguaglianze) resta **non risolto**: manca una scala
  per-vincolo per `cineq` in `arch_rank.m`, analoga a `eps_eq` per le uguaglianze.

---

## Struttura

```
solver.m            entry point generico: solver(fun, bounds, opts)
main.m              entry point utente: ottimizzazione del payload TSTO
core/               motore CMA-ES (ask/tell, init, restart IPOP)
constraints/        ARCH (ranking, repair, epsilon-schedule) + polish
io/                 opts, normalizzazione, bound transform, logging
benchmark/          sphere, Rosenbrock vincolata, g13
real_case/          adapter TSTO, continuazione, variabili di design
TSTO/               simulatore (vendorizzato) + kernel Fortran nativi
results/            output dei run (non versionati)
```

Genericita' (rif. `CLAUDE.md` §1): `n`, `n_eq`, `n_ineq` ricavati a runtime, nessun magic
number. `core/` e `constraints/` non contengono nulla di specifico sulle traiettorie: il
dominio vive solo nella funzione utente.

## Riferimenti

- CMA-ES: Hansen, `purecmaes.m` — https://cma-es.github.io/cmaes_sourcecode_page.html
- ARCH: Sakamoto & Akimoto, *Evolutionary Computation* 30(4), 2022 — arXiv:1811.00764
- Bound handling: pycma `cma/boundary_transformation.py`
- CEC2006 (g13): https://github.com/franciscorafaelsr/cec2006-benchmarks
