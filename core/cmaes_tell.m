function state = cmaes_tell(state, X, order)
% CMAES_TELL  Aggiorna media, covarianza e sigma dato l'ORDINE dei candidati.
%   CMA-ES usa SOLO il ranking (rif. CLAUDE.md S5.2): 'order' arriva da ARCH
%   (Fase 2) o, in assenza di constraint handling, da un ranking banale
%   sull'obiettivo (rif. cmaes_core.m, fallback quando fun_ranked e' vuoto).
%   Porting diretto del passo di update di purecmaes.m (rif. CLAUDE.md S10):
%   'arfitness'/'arindex' del sorgente originale sono sostituiti dall'ordine
%   esterno 'order', che e' l'unico canale attraverso cui i vincoli
%   influenzano il motore (preserva le invarianze di CMA-ES, rif. S5.2).
%
%   NOTA: state.counteval deve essere gia' stato incrementato di lambda dal
%   chiamante (cmaes_core.m) PRIMA di invocare questa funzione, perche' hsig
%   e il trigger di ricalcolo di B/D dipendono da counteval (come in
%   purecmaes.m, dove l'incremento avviene nel ciclo di valutazione).
%
%   INPUT X     : popolazione valutata (n x lambda), spazio normalizzato
%         order : indici di ranking (dal migliore al peggiore), lunghezza lambda
    n = state.n;
    mu = state.mu;
    lambda = state.lambda;

    xold = state.xmean;
    state.xmean = X(:, order(1:mu)) * state.weights;

    state.ps = (1 - state.cs) * state.ps + ...
        sqrt(state.cs * (2 - state.cs) * state.mueff) * state.invsqrtC * (state.xmean - xold) / state.sigma;

    hsig = sum(state.ps.^2) / (1 - (1 - state.cs)^(2 * state.counteval / lambda)) / n < 2 + 4/(n + 1);

    state.pc = (1 - state.cc) * state.pc + ...
        hsig * sqrt(state.cc * (2 - state.cc) * state.mueff) * (state.xmean - xold) / state.sigma;

    artmp = (1 / state.sigma) * (X(:, order(1:mu)) - repmat(xold, 1, mu));
    state.C = (1 - state.c1 - state.cmu) * state.C + ...
        state.c1 * (state.pc * state.pc' + (1 - hsig) * state.cc * (2 - state.cc) * state.C) + ...
        state.cmu * artmp * diag(state.weights) * artmp';

    state.sigma = state.sigma * exp((state.cs / state.damps) * (norm(state.ps) / state.chiN - 1));

    if state.counteval - state.eigeneval > state.lambda / (state.c1 + state.cmu) / n / 10
        state.eigeneval = state.counteval;
        state.C = triu(state.C) + triu(state.C, 1)';
        [state.B, Dsq] = eig(state.C);
        state.D = sqrt(diag(Dsq));
        state.invsqrtC = state.B * diag(state.D.^-1) * state.B';
    end
end
