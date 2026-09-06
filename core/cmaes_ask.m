function X = cmaes_ask(state)
% CMAES_ASK  Campiona la popolazione da N(xmean, sigma^2 C) (rif. CLAUDE.md S3.1).
%   Porting diretto del passo di campionamento di purecmaes.m (rif. CLAUDE.md
%   S10), vettorizzato su lambda colonne invece del ciclo for originale.
%   OUTPUT X : matrice n x lambda dei candidati (colonne = individui), spazio
%              normalizzato [0,1] (i valori possono uscire da [0,1]: il repair
%              o la valutazione della funzione utente gestiscono i bordi,
%              rif. CLAUDE.md S5.2 — nessun clipping qui, per non alterare
%              l'invarianza affine di CMA-ES).
    n = state.n;
    lambda = state.lambda;
    X = state.xmean + state.sigma * state.B * (state.D .* randn(n, lambda));
end
