function state = ipop_restart(state, opts)
% IPOP_RESTART  Restart con popolazione crescente (rif. CLAUDE.md S5.1).
%   A ogni restart: raddoppia lambda e campiona un NUOVO xmean da Sobol +
%   jitter (qui Sobol sceglie il CENTRO, non gli individui — la popolazione
%   resta campionata da cmaes_ask a ogni generazione). Il jitter rompe la
%   regolarita' di usare indici Sobol consecutivi a ogni restart.
%
%   Reinizializza covarianza/evolution-path (nuovo init_state.m) ma preserva
%   il budget di valutazioni gia' consumato (state.counteval) e il contatore
%   dei restart, cosi' che cmaes_core.m possa applicare i criteri di stop
%   sull'intero run (non per-restart).
    n = state.n;
    lambda_new = 2 * state.lambda;
    n_restarts_new = state.n_restarts + 1;

    idx = mod(opts.seed + n_restarts_new, 65536) + 2;
    xmean_base = sobol_point(n, idx);
    jitter = 0.01 * randn(n, 1);
    xmean_new = min(max(xmean_base + jitter, 0), 1);

    counteval_carry = state.counteval;
    state = init_state(xmean_new, opts.sigma0, n, lambda_new);
    state.counteval = counteval_carry;
    state.n_restarts = n_restarts_new;
end
