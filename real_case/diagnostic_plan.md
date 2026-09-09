# Piano diagnostico — "nessuna feasible region + Mpayload incollata a ub"

Stato: PIANO, nessuna modifica di codice eseguita. Redatto da analisi in sola
lettura (solver + TSTO + eval_log.csv), rif. CLAUDE.md S11 Fase 5.

## 0. Sintomo da spiegare

Run reali (seed=1): 300 eval, 12000 eval -> `feasible=0`, `f_best=-6000`
(Mpayload = ub del suo bound), `n_restarts=0`. Run da 200000 eval ->
`feasible=1`, ma sempre `f_best=-6000`, dopo ~3h30m e 9 restart IPOP.

## 1. Evidenza gia' raccolta in questa sessione (calcolo, non congettura)

Con n=10: `lambda_ref=10`, `eps_horizon = ceil(100+50*(n+3)^2/sqrt(lambda_ref))
= 2773`, `max_iter = 5546` (io/parse_opts.m).

`eps_schedule.m` e' geometrico con `K0=1e3`: `eps_eq(iter) = tol_con *
1000^(1-iter/eps_horizon)`. Quindi, con `tol_con = [6000 m; 12000 m;
0.01492 rad]`:

| iter | eps/tol | banda perigeo | banda apogeo | banda inclinazione |
|------|---------|---------------|--------------|--------------------|
| 1    | ~1000   | +-6000 km     | +-12000 km   | +-14.9 rad         |
| 300  | 473     | +-2842 km     | +-5683 km    | +-7.1 rad          |
| 1200 | 50.3    | +-302 km      | +-604 km     | +-0.75 rad (43 deg)|
| 1476 | 25.3    | +-152 km      | +-304 km     | +-0.38 rad (22 deg)|
| 2773 | 1.0     | +-6 km        | +-12 km      | +-0.0149 rad       |

Il run da 12000 eval si e' fermato a **iter 1200**, cioe' con la banda ancora
a ~50x `tol_con` (inclinazione: +-43 deg, vincolo di fatto inesistente).

Conseguenza sul ranking (`arch_rank.m` -> `eq_to_ineq` -> `viol_total`): se
tutti i candidati stanno dentro la banda, `G_eq_norm <= 0` per tutti,
`V` e' identicamente nullo, `rank_v` e' costante e
`score = rank_f + alpha*cost` **degenera nel puro ranking sull'obiettivo**.
Con `f = -Mpayload` (dipende SOLO da x(10), rif. TSTO/source/eval_fgh.m) il
motore per centinaia di generazioni ottimizza una funzione che ignora 9
variabili su 10: spinge x(10) a ub e lascia le altre alla deriva finche'
sigma collassa (osservato: sigma=1.2e-07 a iter 1273 nel probe da 200k).

**Questo spiega ESATTAMENTE il sintomo riportato** (nessun feasible + la
variabile dell'obiettivo incollata al bound), senza bisogno di invocare ne'
infattibilita' fisica ne' un bug di TSTO. Va comunque verificato
sperimentalmente prima di dichiararlo causa (rif. CLAUDE.md S7).

## 2. Ipotesi, ordinate per evidenza attuale

- **H2 (solver / calibrazione) — PRINCIPALE.** `eps_horizon` (calibrato su
  g13, n=5, vincoli O(1)) e `K0=1e3` producono qui una banda iniziale priva di
  significato fisico (+-6000 km di quota, +-14.9 rad di inclinazione). Fino a
  ~iter 1000 il problema e' di fatto NON vincolato. Sotto-ipotesi:
  H2a banda iniziale assurda (K0 moltiplicativo su tol_con);
  H2b orizzonte troppo lungo rispetto al budget dei 5 minuti;
  H2c collasso di sigma prima che la banda stringa (nessun restart perche'
  tol_x/tol_fun scattano tardi e comunque dopo il collasso il segmento e'
  perso);
  H2d le ~1% valutazioni fallite (`f=Inf`, `h=1e6`, 2099/202563 nel log)
  dominano `std(h)` nell'estimatore di alpha in `arch_rank.m` -> `t_k -> 0`
  -> `s -> 0` -> alpha resta al floor 1.0.
- **H1 (caso test non fattibile) — PARZIALMENTE GIA' SMENTITA.** Al nominale
  (Mpayload=4000) `h ~ 1e-9`: un punto feasible esiste ed e' x0. Resta aperto
  se `ub=6000` sia sopra il vero tetto di payload: se lo fosse, il boundary
  sarebbe un artefatto dello spazio di ricerca, non un ottimo. Il probe da
  200k pero' riporta `feasible=1` a Mpayload=6000, il che suggerisce che ub
  sia genuinamente raggiungibile (da confermare direttamente).
- **H3 (bug TSTO) — MENO PROBABILE ma non escluso.** Candidati concreti:
  h calcolato sull'ultimo istante anche quando la traiettoria termina
  suborbitale (apogeo/perigeo "orbitali" privi di senso, quindi un landscape
  dei vincoli discontinuo/ingannevole); ramo `catch` che restituisce
  `h=1e6*ones` (outlier che deforma le statistiche del ranking);
  `minimal_output` vs `create_output` verificato solo sul nominale.

## 3. Todolist

Ordine scelto per costo crescente e potere discriminante decrescente.
Ogni passo dice cosa lo conferma/smentisce.

- [ ] **T1 — Tetto di payload reale (H1, ~2 min).** Sweep 1-D di Mpayload
      (0, 2000, 4000, 5000, 6000, 8000, 10000 kg) con le altre 9 variabili al
      nominale; stampa `|h|` per-vincolo e feasibility contro `tol_con`.
      Esito: se h resta entro tol_con fino a 6000 -> ub NON e' binding per
      caso, il boundary e' legittimo e H1 cade del tutto; se il tetto e' sotto
      6000 -> lo spazio di ricerca ammette payload irrealizzabili e va
      ridiscusso con l'utente.
- [ ] **T2 — Costo del ranking degenere (H2a, ~1 min, nessun run).** Script
      offline: dai residui `h` gia' loggati in `eval_log.csv` del run da 12000
      eval, ricostruire per ogni generazione la frazione di popolazione dentro
      la banda `eps_eq(iter)`. Esito atteso se H2 e' vera: ~100% dentro banda
      per le prime ~1000 generazioni -> `rank_v` costante -> ranking = solo f.
      E' la conferma diretta del meccanismo del S1.
- [ ] **T3 — Strumentazione diagnostica del loop (H2c, ~30 min di lavoro).**
      Aggiungere a `cmaes_core.m` (dietro `opts.verbose>=2`, nessun cambio di
      comportamento) la traccia per-generazione di: `alpha`, `s`, `eps_eq`,
      frazione feasible reale (contro `tol_con`, non contro eps), `min |h_k|`
      per-vincolo, sigma. Serve a T5/T6: oggi si vola alla cieca.
- [ ] **T4 — Verifica dell'estimatore alpha con outlier (H2d, ~15 min).**
      Su una popolazione sintetica che replichi il mix osservato (99% residui
      "normali" + 1% a 1e6) misurare `s` e alpha con e senza gli outlier.
      Se s crolla per colpa di `std`, il fix candidato e' escludere/clippare i
      punti con `f=Inf` dalle statistiche di `local_centering_error` (NON dal
      ranking: li' vanno lasciati ultimi).
- [ ] **T5 — Esperimento decisivo su H2 (~10 min di calcolo).** Rilanciare il
      caso reale a budget invariato (12000 eval) con il SOLO cambio
      `opts.eps_horizon` ridotto (es. 300 e 600, due run) cosi' che la banda
      raggiunga `tol_con` dentro il budget. Esito: se compare `feasible=1`
      entro 12000 eval, H2 e' confermata come causa dominante e il problema
      diventa di calibrazione, non di solver rotto.
- [ ] **T6 — Alternativa/complemento su K0 (H2a, ~10 min).** Stesso protocollo
      di T5 ma agendo su `K0` (es. 30 invece di 1e3), lasciando `eps_horizon`
      al default. Serve a separare "banda iniziale assurda" da "orizzonte
      troppo lungo": sono due difetti distinti e il fix definitivo potrebbe
      richiederli entrambi.
- [ ] **T7 — Sanity check TSTO su traiettorie non orbitali (H3, ~20 min).**
      Prendere dal log 3-5 candidati che terminano presto (evento
      altitude-zero) e ispezionare apogeo/perigeo/inclinazione restituiti:
      verificare che i residui `h` siano grandi e monotoni verso la regione
      buona, non numeri "casualmente vicini" al target (che renderebbero il
      landscape ingannevole). Verificare inoltre che `minimal_output` e
      `create_output` diano gli stessi 4 scalari su questi casi limite, non
      solo sul nominale.
- [ ] **T8 — Decisione con l'utente (gate).** Presentare esito T1/T5/T6 e
      concordare: (i) valori definitivi di `eps_horizon`/`K0` per il caso
      reale (e se vadano resi `opts` documentati anziche' costanti);
      (ii) se `ub` di Mpayload va cambiato; (iii) se il floor di alpha e il
      trattamento degli outlier vanno toccati. Nessuna modifica ai default
      calibrati di Fase 3 senza questo passaggio (CLAUDE.md S0/S6.1).
- [ ] **T9 — Run di conferma nel budget dei 5 minuti.** Dopo il fix
      concordato: run cronometrato con `time`, criterio di PASS esplicito
      (`feasible=1` per-vincolo entro `tol_con` e wall-clock <= 300 s sul PC
      target, ~pessimistico su questa macchina N100). Aggiornare CLAUDE.md
      S11 Fase 5 con l'esito, positivo o negativo che sia.

## 4. Cosa NON viene fatto in questo piano (esplicito)

- Nessun aumento cieco del budget di valutazioni: 40x (300 -> 12000) non ha
  cambiato il sintomo, e il probe da 200k mostra che la strada "piu' budget"
  costa 3h30m, incompatibile col requisito dei 5 minuti.
- Nessun intervento sul gap noto del clipping ai bound in `cmaes_ask.m` ne'
  sull'`eps_ineq` mancante per le disuguaglianze (`cineq` e' vuoto qui):
  fuori dallo scope di questa diagnosi.
- Nessuna riscrittura del ranking ARCH: se T5/T6 confermano H2, il difetto e'
  nella scala dello schedule, non nell'aggregazione.

---

# ESITI T1 / T2 (eseguiti, 2026-09-09)

## Nota preliminare, non prevista: i kernel nativi NON erano compilati

`TSTO/source/native/*.oct` non sono versionati (rif. native/README.md) e in
questo checkout non esistevano: **ogni valutazione girava sul fallback
interpretato, 8.4 s invece di ~0.1 s** (misurato: sweep T1 prima 8.4 s/eval,
dopo `mkoctfile` 0.1 s/eval). Ricompilati in sessione. Da tenere presente
prima di ri-cronometrare qualunque run (il "44.9 ms/eval" di CLAUDE.md vale
solo con i .oct presenti).

## T1 — tetto reale di payload (sweep 1-D, guida al nominale)

| Mpayload [kg] | 0..15000 | 20000 | 30000+ |
|---|---|---|---|
| `\|h\|` per-vincolo | ~1e-9 (macchina) | 3.9e6 m | >5e6 m |
| feasible vs tol_con | **1** | 0 | 0 |

Tetto reale fra 15000 e 20000 kg, cioe' **~2.5-3x sopra `ub=6000`**.

Conseguenze:
1. **H1 (caso test non fattibile) e' SMENTITA**: il nominale e' feasible con
   margine enorme; l'ottimo del problema COSI' COM'E' BOXATO e' banalmente
   `Mpayload = ub`. Arrivare al bound non e' un sintomo di bug, e' la
   risposta corretta per questo box. La domanda vera diventa: `ub=6000` e'
   un requisito di missione o un residuo arbitrario? Se e' arbitrario, il
   problema di ottimizzazione e' mal posto (ottimo sul bordo del box, non
   determinato dalla fisica).
2. Scoperta strutturale su TSTO (piu' importante del bound): i residui NON
   sono ~0 per caso. `simulator.m` fase 7 (coast to apogee) + fase 8
   (`injection_target_orbit.m`, burn IMPULSIVO analitico) **centrano il
   target per costruzione**, saturando sul propellente disponibile quando non
   basta. Quindi `h` e' quasi BINARIA: ~1e-9 se la missione si chiude, ordini
   di grandezza se non si chiude. Il vincolo fisicamente significativo e'
   "delta-v richiesto <= delta-v disponibile", cioe' una **disuguaglianza**,
   non le 3 uguaglianze. Con le uguaglianze si ottiene un landscape a
   plateau: niente gradiente utile verso la feasibility.

## T2 — frazione in banda per generazione (run da 12000 eval, ri-valutato)

Ipotesi H2a (**banda eps troppo larga -> ranking degenere sul solo f**):
**FALSIFICATA**. Misura su 49 generazioni campionate del run:
`in-band = 0%` e `in-tol = 0%` in TUTTE le generazioni, da gen 1 a gen 1200.
Il ranking sulla violazione era quindi sempre attivo. `eps_horizon`/`K0` NON
sono la causa: T5 e T6 del piano perdono priorita'.

**Trovata invece la causa vera, misurata sul log.** Residui del miglior
individuo per generazione, in unita' di `tol_con`:

- gen 1..~76: variabili
- gen ~76..1200: **costanti a 3 cifre** (`|h|/tol = [966, 31.2, 0.114]`)

Il perigeo e' fuori di ~5800 km: la traiettoria e' suborbitale. E la
popolazione e' degenerata: righe distinte per generazione = 10 (gen 1-300),
5 (gen 600), **1 (gen 1200)**. Alla generazione 600 tutti i 10 individui
sono identici tranne l'ottava cifra decimale di `transition_starting`:

```
20, 5, -0.2deg, 0, 11.1446043, 0, 5, 5deg, 0.75, 6000
```

9 componenti su 10 sono **incollate al proprio lb/ub**. Meccanismo:

1. `cmaes_ask.m` campiona senza alcun bound handling (gap dichiarato in
   CLAUDE.md Fase 2, mai risolto) -> la media della distribuzione esce da
   `[0,1]^n`;
2. il clip aggiunto in Fase 5 dentro `real_case/traj_cost.m` riporta i
   candidati sul bordo -> **tutti sullo stesso bordo**;
3. candidati identici => `f` e `h` identici => il ranking e' tutto pareggi
   (`local_rank_stat` assegna lo stesso punteggio) => **nessun segnale di
   selezione**: la media non ha piu' un gradiente, sigma si contrae, e il
   run brucia 1100+ generazioni valutando 10 volte lo stesso punto.

`f_best = -6000` non e' un ottimo: e' `Mpayload` clippata a `ub`, con la
traiettoria suborbitale. Il clip in traj_cost.m, introdotto per curare
l'hang di `ode45`, e' quindi diventato il meccanismo che uccide la ricerca
(prima di rk5.m il sintomo era mascherato dall'hang).

## Difetto collaterale del solver, trovato qui (indipendente)

Finche' NESSUN punto feasible e' stato trovato, `f_best_feas = Inf`, quindi
`f_hist_seg` e' tutta Inf e il criterio `tol_fun` in `core/cmaes_core.m`
confronta `Inf - Inf = NaN < tol_fun` -> **sempre falso**. Una popolazione
completamente bloccata (caso sopra) non fa scattare nessun restart: nel run
da 12000 eval `n_restarts=0` per 1200 generazioni, e nel probe da 200k il
primo restart e' arrivato solo a iter 1273 via `tol_x` (sigma=1.2e-07).
Serve un rilevatore di stallo che funzioni anche in assenza di punti
feasible (es. plateau sul best RAW, o su sigma/dispersione della
popolazione, o degenerazione della popolazione).

## Priorita' riviste (da confermare con l'utente)

- **P1 — bound handling nel motore** (causa dominante). Opzioni:
  (a) trasformazione liscia/riflessione `R^n -> [0,1]^n` in `/io` (stile
      boundary transformation di Hansen: informazione preservata, nessuna
      penalita' additiva, compatibile con S5.2);
  (b) penalita' di solo BOX sull'obiettivo (Hansen `cmaes.m`), da chiarire
      rispetto al divieto di penalita' di S5.2 (che riguarda i vincoli del
      problema, non i bound);
  (c) bound come `cineq` (richiede `eps_ineq`, e il ramo disuguaglianze non
      e' validato: rosenbrock 0/10, rif. Fase 3).
  Raccomandazione: (a). E' generico, dimension-agnostic, non tocca ARCH.
- **P2 — rilevatore di stallo/restart valido senza punti feasible.**
- **P3 — riformulazione del vincolo su TSTO**: valutare "delta-v richiesto
  <= disponibile" come disuguaglianza, invece di 3 uguaglianze che sono
  soddisfatte per costruzione o violate in blocco (decisione di modellazione,
  non di implementazione: da discutere).
- **P4 — `ub` di Mpayload**: se non e' un requisito, l'ottimo resta sul
  bordo del box per definizione.
- **P5 (declassato) — `eps_horizon`/`K0`**: T2 li ha esclusi come causa.

---

# FIX APPLICATI (2026-09-09)

## P1 — bound handling, opzione (a) (decisione utente)

Nuovi file: `io/bound_transform.m`, `io/bound_transform_inv.m`. Porting della
boundary transformation di Hansen (pycma, `cma/boundary_transformation.py`):
mirroring periodico fuori dominio + patch quadratiche C1 sui bordi
(`al=0.05`), identita' ESATTA in `[al, 1-al]`.

`solver.m`: il motore lavora ora in spazio NON vincolato e la trasformazione
sta dentro la funzione obiettivo (`fun_norm = fun_box(bound_transform(xn))`),
quindi `/core` resta ignaro (S3). Aggiunte: `fun_box` (valutazione in spazio
box, usata da feasibility-polish e ri-valutazione finale -- NON `fun_norm`,
che ri-applicherebbe la trasformazione a un punto gia' trasformato),
`bound_transform_inv` su `opts.x0` (altrimenti il motore non parte dal punto
chiesto dall'utente vicino ai bordi), e la trasformazione di
`x_best`/`x_best_ranked` in uscita dal motore.

Unit test (proprieta', non solo smoke): in-box su y in [-3,4]; identita'
interna esatta (errore 0, non 1e-17 -- il `mod` e' applicato solo ai punti che
escono davvero dal dominio invertibile); |derivata| <= 1; round-trip sul box
2.4e-22; punti distinti fuori dominio restano distinti (nessun plateau).

**Regressione benchmark: verde.**
- sphere n=25 seed 1: `f_best=1.53e-16` (riferimento post-Fase 3: 1.13e-16;
  Fase 1: 2.6e-13) -- nessun peggioramento.
- g13, 5 seed, default puri + `tol_con=1e-4`: **5/5 feasible, 5/5 ottimo
  globale** `f*=0.053942`, 64216-553048 eval, 5-9 restart (in linea con
  Fase 3).

**Effetto sul caso reale** (`run_real_case_short_cfg.m`, stesso x0/bounds/
tol_con/seed di `run_real_case.m`, budget ridotto a 2000 eval):

| | prima | dopo |
|---|---|---|
| feasible | 0 (a 300 e a 12000 eval) | **1 a 2020 eval** |
| durata | >3h senza feasible (200k) | **1 min 39 s** |
| valutazioni distinte | 1 punto ripetuto da gen ~76 | 2020/2020 distinte |
| restart IPOP | 0 in 1200 iter | 2 in 100 iter |

Due conseguenze da riportare in CLAUDE.md S11 Fase 5:
1. il "floor di eval-to-feasibility ~200000" era **un artefatto di questo
   bug**, non una proprieta' del problema;
2. il requisito dei 5 minuti, dichiarato "con altissima probabilita'
   infattibile", torna in gioco (99 s per un run che trova feasible su un
   seed -- da confermare con un run completo su piu' seed, NON dimostrato).

## P3/B — vincolo di disuguaglianza sul margine di delta-v (decisione utente)

Le 3 uguaglianze restano (opzione A del piano NON applicata: l'utente ha
scelto solo B). Aggiunto `OPT.g`:

    g = (dv_required - dv_available) / ue2  <= 0        [adimensionale]

Catena: `injection_target_orbit.m` (2 output in piu', erano gia' calcolati
in `deliver_delta_v` e scartati) -> `simulator.m` (`other.INJ` =
reached/dv_required/dv_available/dv_margin, inizializzata prima del loop di
fase, popolata in fase 8) -> `eval_fgh.m` (`OPT.g`, con la scala e il
fallback documentati inline) -> `traj_problem.m` (ramo `catch`: `g` di
lunghezza COSTANTE, altrimenti `arch_rank`/`local_cell2mat` -- che deduce
n_ineq dal primo individuo -- si rompe).

Scala: `ue2 = vacuum_thrust/mass_flow_rate` dello stadio 2, COSTANTE del
veicolo. Non `dv_available` (che dipende da x): cambierebbe l'ordinamento fra
candidati, non solo la scala, rompendo l'invarianza monotona di S5.2.

Verifica (sweep sul payload, guida al nominale):

| Mpayload [kg] | 4000 | 6000 | 15000 | 19000 | 20000 |
|---|---|---|---|---|---|
| `g` | -1.057 | -0.844 | -0.242 | -0.076 | 10 (fallback) |
| `dv_margin` [m/s] | -3593 | -2867 | -827 | -211 | n/d |

Dove `h` era piatta a ~1e-9 su tutto l'insieme ammissibile, `g` e' continua e
monotona e si annulla verso il tetto di payload: il vincolo diventa ATTIVO
all'ottimo. Round-trip nominale invariato (`f=-4000`, `h~1e-9`).
Caso reale con `cineq` non vuoto (prima volta): `feasible=1` a 2000 eval.

**Discontinuita' residua, non risolta -- e per decisione utente NON da
risolvere**: il salto a 20 t non e' saturazione del burn di fase 8, e'
`END_PROP2` (propellente stadio 2 esaurito in fase 6), che termina il run
prima di fase 7/8 (scelta di modellazione gia' documentata in `simulator.m`).
Un proxy continuo di "quanto delta-v manca" in quel ramo e' stato proposto e
**scartato dall'utente**: la mancanza di delta-v e' *gia' pagata* dai residui
`h` (~3.9e6 m sul perigeo), un secondo canale duplicherebbe la stessa
informazione. Coerente anche col fatto che ARCH **ordina** la violazione
(`rank_v`), non la pesa: il fallback non deve portare informazione.

Dove la magnitudine conta davvero e' il controllore di alpha
(`local_centering_error` usa `mean/std` dei `cineq` GREZZI): per questo il
fallback del ramo `catch` e' stato portato da 1e3 a **20** -- ordinamento
invariato (missione chiusa < non chiusa (10) < simulazione fallita (20)),
ma non piu' capace di dominare le statistiche con l'~1% di valutazioni
fallite osservato.

## Aperto, non toccato

- **P2** — rilevatore di stallo valido senza punti feasible: `tol_fun` usa
  `f_best_feas` (Inf finche' non c'e' feasibility) -> `Inf-Inf=NaN` -> mai
  vero. Meno urgente ora (la feasibility arriva presto), ma il difetto resta.
- **P4** — `ub` di Mpayload (6000) e' ~3x sotto il tetto fisico (T1): con
  questo box l'ottimo e' sul bordo per definizione.
- **A** (uguaglianze -> `|h|-tol_con<=0`): non applicata.
- `eps_ineq`/scala per-vincolo per `cineq` in `arch_rank.m`: il caso reale ha
  ora UN solo `cineq`, gia' adimensionale (configurazione benigna), quindi il
  gap non e' stato esercitato davvero -- non e' stato validato, resta aperto.
