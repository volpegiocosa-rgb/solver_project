function [x_out, m_out, ratio, n_eval] = giano_push_to_wall(x_in, other, ...
                                            tol_con, ub_pl, ratio, i_payload, push_opts)
% GIANO_PUSH_TO_WALL  Predictor-corrector in massa: spinge il payload di
%   un punto feasible fino al proprio "muro" (rif. giano-design.md Gate
%   5c-1, porting di real_case/run_continuation.m::local_push_to_wall,
%   stessa logica, zero file I/O -- usa giano_eval_feasibility.m invece
%   di real_case/traj_cost.m).
%
%   Predittore : m_try = m + ratio_safety * r * prop_residual (sovrastima
%                per costruzione -> genera il bracket superiore con 1
%                sola valutazione, rif. giano_ratio_tsiolkovsky.m per il
%                perche').
%   Correttore : bisezione dentro il bracket ottenuto, fino a bisect_tol.
%   Apprendimento: r ri-misurato come dm/d(prop_residual) fra i due punti
%                feasible piu' vicini al muro (curva convessa: un r unico
%                non basta, misurato in real_case/run_continuation.m).
%
%   INPUT  : x_in       10x1, punto di partenza (deve essere feasible;
%                       se non lo e' o non ha propellente residuo
%                       misurabile, viene restituito invariato)
%            other      struct "pristine" + opt_bounds/ang_idx/log_level
%            tol_con    3x1, tolleranze assolute per-vincolo
%            ub_pl      upper bound fisico del payload (box dell'utente)
%            ratio      rateo dMpayload/dMprop noto ([] se nessuna stima
%                       precedente disponibile -> primo guess Tsiolkovsky)
%            i_payload  indice del payload dentro il vettore x (10x1),
%                       rif. giano_build_design_vectors.m
%            push_opts  struct con .push_max .ratio_safety .bisect_tol
%                       .bisect_max (rif. cfg.opts, Gate 5c-3)
%   OUTPUT : x_out, m_out   punto/payload spinti al muro (o invariati)
%            ratio           rateo aggiornato (appreso dai punti valutati)
%            n_eval          numero di valutazioni spese qui dentro

    n_eval = 0;

    [feas, ~, ~, pr] = giano_eval_feasibility(x_in, other, tol_con);
    n_eval = n_eval + 1;
    if ~feas || ~isfinite(pr) || pr <= 0
        x_out = x_in;
        m_out = x_in(i_payload);
        return;
    end

    x_lo  = x_in;
    m_lo  = x_in(i_payload);
    pr_lo = pr;
    m_hi  = NaN;   % primo payload infeasible noto

    if isempty(ratio) || ~isfinite(ratio) || ratio <= 0
        ratio = giano_ratio_tsiolkovsky(m_lo, pr_lo, other);
    end

    % --- fase predittiva --------------------------------------------------
    for k = 1:push_opts.push_max
        m_try = min(m_lo + push_opts.ratio_safety * ratio * pr_lo, ub_pl);
        if m_try - m_lo < push_opts.bisect_tol
            break;
        end
        x_try = x_lo;
        x_try(i_payload) = m_try;
        [feas_t, ~, ~, pr_t] = giano_eval_feasibility(x_try, other, tol_con);
        n_eval = n_eval + 1;
        if feas_t
            d_pr = pr_lo - pr_t;
            if d_pr > 0
                ratio = (m_try - m_lo) / d_pr;
            end
            x_lo  = x_try;
            m_lo  = m_try;
            pr_lo = pr_t;
            if m_lo >= ub_pl - push_opts.bisect_tol
                break;
            end
        else
            m_hi = m_try;
            break;
        end
    end

    % --- fase correttiva: bisezione nel bracket [m_lo, m_hi] --------------
    if isfinite(m_hi)
        n_bis = 0;
        while (m_hi - m_lo) > push_opts.bisect_tol && n_bis < push_opts.bisect_max
            m_mid = 0.5 * (m_lo + m_hi);
            x_try = x_lo;
            x_try(i_payload) = m_mid;
            [feas_t, ~, ~, pr_t] = giano_eval_feasibility(x_try, other, tol_con);
            n_eval = n_eval + 1;
            n_bis  = n_bis + 1;
            if feas_t
                d_pr = pr_lo - pr_t;
                if d_pr > 0
                    ratio = (m_mid - m_lo) / d_pr;
                end
                x_lo  = x_try;
                m_lo  = m_mid;
                pr_lo = pr_t;
            else
                m_hi = m_mid;
            end
        end
    end

    x_out = x_lo;
    m_out = m_lo;

end
