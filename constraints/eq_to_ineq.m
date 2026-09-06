function g = eq_to_ineq(ceq, eps_eq)
% EQ_TO_INEQ  Trasforma le uguaglianze in disuguaglianze con tolleranza (rif. CLAUDE.md S5.2).
%   g_k = |h_k| - eps_eq_k <= 0.  Dimension-agnostic: opera su n_eq arbitrario
%   (n_eq = size(ceq,1), MAI cablato). eps_eq e' un vettore per-vincolo (S4: scale
%   fisiche eterogenee, es. km per le quote, gradi per l'inclinazione).
%   Vettorizzato: ceq puo' essere un singolo punto (n_eq x 1) o una popolazione
%   (n_eq x lambda, usato da arch_rank) -- eps_eq (n_eq x 1) si broadcasta su
%   ogni colonna.
%
%   INPUT  ceq    : n_eq x 1 (punto) o n_eq x lambda (popolazione), o [] se n_eq=0
%          eps_eq : vettore n_eq x 1, lunghezza = size(ceq,1)
%   OUTPUT g      : stessa shape di ceq; g_k <= 0 <=> vincolo k soddisfatto entro eps_eq_k
    if isempty(ceq)
        g = [];
        return
    end
    eps_eq = eps_eq(:);
    assert(numel(eps_eq) == size(ceq, 1), 'eq_to_ineq:badSize', ...
        'eps_eq deve avere lunghezza pari a size(ceq,1) (n_eq=%d), ricevuto %d.', ...
        size(ceq, 1), numel(eps_eq));
    g = abs(ceq) - eps_eq;   % broadcast eps_eq (n_eq x 1) su ogni colonna di ceq
end
