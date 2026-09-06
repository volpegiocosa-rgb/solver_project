# Toolbox/pacchetti richiesti — eccezione a CLAUDE.md §2

> Tracciamento delle dipendenze opzionali accettate come ECCEZIONE esplicita a CLAUDE.md §2
> ("nessun pacchetto opzionale su percorso critico"). Decisione utente, Fase 2 (rif. sessione
> kick-off-solver, 2026-09-04): `cineq` sarà necessario a breve (oltre il placeholder attuale),
> quindi il repair operator ARCH deve poter risolvere un sotto-problema di ottimo vincolato
> generale (nearest-feasible-point) — non riducibile a un semplice Gauss-Newton equality-only.
> Eccezione accettata, da mantenere aggiornata ad ogni nuova dipendenza introdotta.

## Octave

- **`sqp()`** — usato in `constraints/arch_repair.m` per il nearest-feasible-point (Mahalanobis)
  nel repair operator ARCH.
  - **Pacchetto**: `sqp` è funzione **core di Octave** (non `octave-forge`), presente di default
    in ogni installazione standard. Nessuna installazione aggiuntiva richiesta.
  - Fonte: https://docs.octave.org/latest/Nonlinear-Programming.html
  - **Nessuna eccezione reale sul lato Octave**: il solver gira "nudo" senza pacchetti opzionali,
    come richiesto da §2. L'eccezione riguarda solo il lato MATLAB (sotto).

## MATLAB

- **`fmincon()`** (algoritmo `'sqp'`) — equivalente usato in `constraints/arch_repair.m` quando
  il codice gira su MATLAB (dispatch via `exist('OCTAVE_VERSION', 'builtin')`).
  - **Toolbox richiesto**: **Optimization Toolbox**. NON incluso in MATLAB base — è un add-on
    a pagamento, licenza separata.
  - Fonte: https://www.mathworks.com/help/optim/ug/fmincon.html
  - **STATO: NON VERIFICATO.** L'utente non dispone di un'installazione MATLAB per confermare
    la disponibilità della licenza Optimization Toolbox. Se in futuro si esegue il solver su
    MATLAB e la toolbox non risulta disponibile, `arch_repair.m` fallirà a runtime con l'errore
    nativo MATLAB "requires Optimization Toolbox" — non c'è fallback silenzioso.
  - **Azione richiesta prima di un run reale su MATLAB (Fase 5 o prima)**: verificare
    `license('test','Optimization_Toolbox')` sull'installazione target.

## Note

- Questa eccezione è circoscritta al repair operator ARCH (`arch_repair.m`). Il resto del
  solver (`/core`, `/io`, benchmark) non introduce dipendenze opzionali e resta conforme a §2.
- Se in futuro emergono altre dipendenze opzionali (Octave o MATLAB), aggiungerle qui prima di
  usarle, non silenziosamente nel codice.
