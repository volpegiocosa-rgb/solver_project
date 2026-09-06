function state = init_state(xmean, sigma, n, lambda)
% INIT_STATE  Inizializza lo stato interno di CMA-ES (rif. CLAUDE.md S5.1, S6.1
%   punto 1). Porting diretto del blocco di inizializzazione di purecmaes.m
%   (Hansen, rif. CLAUDE.md S10), generalizzato per accettare lambda esplicito
%   (serve a ipop_restart.m per il raddoppio di popolazione).
%
%   Usato sia da cmaes_core.m (init iniziale) sia da ipop_restart.m (reinit
%   dopo un restart IPOP): file separato perche' condiviso da piu' moduli di
%   /core (rif. CLAUDE.md S2, funzioni ausiliarie in file separati se servono
%   a piu' moduli).
%
%   INPUT  : xmean  punto medio iniziale, n x 1, spazio normalizzato [0,1]
%            sigma  step-size iniziale (scalare)
%            n      dimensione (runtime, non cablata)
%            lambda (opzionale) numero di individui; default = 4+floor(3*log(n))
%                   (formula di riferimento Hansen, NON calibrata su benchmark:
%                   rif. CLAUDE.md S6.1 punto 1, resta fissa anche dopo la
%                   calibrazione della Fase A)
%   OUTPUT : state  struct con tutti i parametri/variabili dinamiche di CMA-ES

    if nargin < 4 || isempty(lambda)
        lambda = 4 + floor(3 * log(n));
    end

    state.n = n;
    state.xmean = xmean(:);
    state.sigma = sigma;
    state.lambda = lambda;

    mu = lambda / 2;
    weights = log(mu + 1/2) - log((1:floor(mu))');
    mu = floor(mu);
    weights = weights / sum(weights);
    mueff = sum(weights)^2 / sum(weights.^2);

    state.mu = mu;
    state.weights = weights;
    state.mueff = mueff;

    state.cc = (4 + mueff/n) / (n + 4 + 2*mueff/n);
    state.cs = (mueff + 2) / (n + mueff + 5);
    state.c1 = 2 / ((n + 1.3)^2 + mueff);
    state.cmu = min(1 - state.c1, 2 * (mueff - 2 + 1/mueff) / ((n + 2)^2 + mueff));
    state.damps = 1 + 2*max(0, sqrt((mueff - 1) / (n + 1)) - 1) + state.cs;

    state.pc = zeros(n, 1);
    state.ps = zeros(n, 1);
    state.B = eye(n);
    state.D = ones(n, 1);
    state.C = state.B * diag(state.D.^2) * state.B';
    state.invsqrtC = state.B * diag(state.D.^-1) * state.B';
    state.eigeneval = 0;
    state.counteval = 0;
    state.chiN = n^0.5 * (1 - 1/(4*n) + 1/(21*n^2));
    state.iter = 0;
    state.n_restarts = 0;
end
