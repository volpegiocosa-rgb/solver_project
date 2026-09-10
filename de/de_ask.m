function V = de_ask(X, F, CR)
% DE_ASK  Mutazione DE/rand/1 + crossover binomiale (rif. piano di sessione "confronto DE vs
%   CMA-ES+ARCH"). Fonte algoritmo (porting concettuale, non di codice): Storn, R. & Price, K.
%   (1997). "Differential Evolution - A Simple and Efficient Heuristic for Global
%   Optimization over Continuous Spaces." J. Global Optim. 11, 341-359.
%
%   Loop esplicito su pop_size (stile coerente con core/cmaes_core.m: leggibilita' contro il
%   riferimento testuale dell'algoritmo conta piu' che vettorizzare la scelta degli indici).
%   Bound handling: UNA sola chiamata a de_reflect_bounds sull'INTERA matrice trial a valle
%   (vettorizzata), non per-colonna dentro il loop.
%
%   INPUT  X  : popolazione corrente, n x pop_size, in [0,1]^n
%          F  : fattore di scala mutazione (> 0)
%          CR : tasso di crossover binomiale, in [0,1]
%   OUTPUT V  : popolazione trial, n x pop_size, in [0,1]^n (dopo il fold di bound)
    [n, pop_size] = size(X);
    V = zeros(n, pop_size);

    for i = 1:pop_size
        pool = 1:pop_size;
        pool(i) = [];
        r = pool(randperm(pop_size - 1, 3));   % r1,r2,r3 distinti fra loro e dal target i

        donor = X(:, r(1)) + F * (X(:, r(2)) - X(:, r(3)));

        trial = X(:, i);
        j_rand = randi(n);                     % almeno una componente forzata dal donor
        cross = rand(n, 1) < CR;
        cross(j_rand) = true;
        trial(cross) = donor(cross);

        V(:, i) = trial;
    end

    V = de_reflect_bounds(V);
end
