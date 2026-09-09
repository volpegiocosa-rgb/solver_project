function [t, y, te, ye, ie] = rk5(f, t0, tmin, tmax, tend, y0, other, eventFcn, stepFcn)
% RK5 Fifth-order Runge-Kutta solver (Butcher, passo variabile CINEMATICO)
%   con localizzazione di zero-crossing per gli eventi, stile ode45.
%
%   Motivazione (rif. CLAUDE.md solver_project S11 Fase 5, sessione
%   fix-ode-hang): ode45/ode23s a controllo d'errore locale possono restare
%   bloccati per ore su candidati x dove la dinamica resta quasi-inerziale
%   per una finestra simulata lunga (fase 3 con pitch_rate_transition~0,
%   causa concreta diagnosticata via logging per-eval) -- il controllore
%   d'errore riduce il passo a oltranza per soddisfare RelTol/AbsTol senza
%   che questo comporti alcun vantaggio pratico (i vincoli di missione
%   hanno tolleranze late, 3% del target). rk5.m sostituisce il controllo
%   d'errore con un passo CINEMATICO (stepFcn, tipicamente kinematic_step.m
%   in questo repo: passo ~ |v|/|a|) clippato a [tmin,tmax]: il costo
%   computazionale peggiore per fase e' quindi LIMITATO per costruzione a
%   (tend-t0)/tmin passi, indipendentemente da quanto la fisica lo
%   richiederebbe per un'accuratezza stile ode45.
%
% Inputs:
%   f        - Function handle per l'ODE: dy/dt = f(t, y)  (2 argomenti,
%              stessa convenzione di chiamata gia' in uso con ode45 in
%              simulator.m, es. @(t,y) eom(t,y,other): 'other' e' gia'
%              catturato per closure, non serve ripassarlo qui)
%   t0       - Istante iniziale
%   tmin     - Passo minimo (rete di sicurezza sul costo peggiore: il
%              numero di passi per fase e' <= (tend-t0)/tmin)
%   tmax     - Passo massimo (evita passi troppo grandi nei tratti calmi,
%              a scapito della localizzazione degli eventi)
%   tend     - Istante di fine finestra di sicurezza (se la fase non
%              termina prima per via di un evento, applicare una durata
%              di sicurezza per evitare lo stallo -- stesso ruolo di
%              tspan(2) con ode45, gia' in uso come config.tmax_phase)
%   y0       - Vettore colonna delle condizioni iniziali
%   other    - Struct contenitore passata a eventFcn/stepFcn (NON a f, che
%              la riceve gia' via closure -- vedi sopra)
%   eventFcn - Handle event, stessa convenzione 'Events' di ode45 ma con
%              'other' esplicito:
%              [value, isterminal, direction] = eventFcn(t, y, other)
%   stepFcn  - Handle che propone il passo NON ancora clippato:
%              h = stepFcn(t, y, other)  (il clip a [tmin,tmax] e il
%              troncamento a tend sono responsabilita' di rk5.m, non dello
%              stepFcn, cosi' che diverse strategie di stepFcn restino
%              intercambiabili senza duplicare la logica di sicurezza)
%
% Outputs:
%   t, y     - Istanti e matrice di stato (righe = istanti, colonne = stato)
%   te, ye   - Istante e stato in cui si sono verificati gli eventi
%   ie       - Indice della condizione di evento che ha innescato lo stop

    y0 = y0(:);

    n      = 1000;   % capacita' iniziale preallocata; raddoppiata se insufficiente
    t      = zeros(n, 1);
    y      = zeros(n, length(y0));
    y(1,:) = y0.';
    t(1)   = t0;
    n_step = 1;

    % Rete di sicurezza sul numero di passi: con h sempre >= tmin (clip
    % sotto), il ciclo termina comunque entro questo numero di iterazioni;
    % l'errore qui sotto puo' scattare solo per un bug futuro su h/tmin,
    % non in condizioni normali (analogo a max_iterations in simulator.m).
    max_steps = ceil((tend - t0) / tmin) + 10;

    te = []; ye = []; ie = [];

    hasEvents = (nargin >= 8) && ~isempty(eventFcn);

    if hasEvents
        [val_old, isterminal, direction] = eventFcn(t(1), y(1,:).', other);
        numEvents = length(val_old);
    end

    while t(n_step) < tend
        if n_step > max_steps
            error('rk5:tooManySteps', ...
                  ['Superato il numero massimo di passi (%d): tmin ' ...
                   'troppo piccolo rispetto a (tend-t0), oppure bug su h.'], ...
                  max_steps);
        end

        tn = t(n_step);
        yn = y(n_step,:).';

        % --- Passo cinematico, poi clip di sicurezza -----------------
        h = stepFcn(tn, yn, other);
        if h < tmin
            h = tmin;
        end
        if h > tmax
            h = tmax;
        end
        if tn + h > tend
            h = tend - tn;
        end

        % --- Un passo RK5 (stadi di Butcher in rk5_single_step) ------
        y_next = rk5_single_step(f, tn, yn, h);
        t_next = tn + h;

        n_step = n_step + 1;
        if n_step > size(t, 1)
            t = [t; zeros(size(t,1), 1)];
            y = [y; zeros(size(y,1), size(y,2))];
        end
        t(n_step)   = t_next;
        y(n_step,:) = y_next.';

        % --- Event Detection Processing ---
        if hasEvents
            [val_new, ~, ~] = eventFcn(t_next, y_next, other);
            terminated = false;

            for idx = 1:numEvents
                % Check for a sign change (zero-crossing)
                if val_old(idx) * val_new(idx) <= 0 && val_old(idx) ~= val_new(idx)

                    % Verify direction constraint matching MATLAB logic:
                    % direction =  1 -> increasing only
                    % direction = -1 -> decreasing only
                    % direction =  0 -> any direction
                    is_correct_dir = (direction(idx) == 0) || ...
                                     (direction(idx) == 1  && val_new(idx) > val_old(idx)) || ...
                                     (direction(idx) == -1 && val_new(idx) < val_old(idx));

                    if is_correct_dir
                        % Localizzazione dell'evento per RI-INTEGRAZIONE
                        % (rif. requisito utente: l'accuratezza del
                        % cross-over dell'apogeo deve essere MIGLIORE della
                        % tolleranza ammessa dalla funzione di costo).
                        % La versione precedente interpolava LINEARMENTE
                        % tempo e stato dentro il passo: con un passo
                        % cinematico fino a tmax=2 s e |v|~7.6 km/s la corda
                        % e' ~15 km, quindi l'errore di posizione era di
                        % ordine km -- misurato 1613 m sul raggio di apogeo
                        % in input/validation_test_2, cioe' dello stesso
                        % ordine della tolleranza di missione (12 km): non
                        % accettabile. Ora il crossing e' cercato dentro il
                        % bracket [tn, tn+h] con secante safeguarded
                        % (Illinois) e ogni tentativo e' valutato integrando
                        % un sub-passo RK5 dal nodo tn: lo stato all'evento
                        % ha quindi la stessa accuratezza del quinto ordine
                        % dell'integratore, non quella di una corda.
                        [t_evt, y_evt] = localize_event( ...
                            f, eventFcn, other, idx, tn, yn, h, ...
                            val_old(idx), val_new(idx), y_next);

                        te = [te; t_evt];
                        ye = [ye; y_evt.'];
                        ie = [ie; idx];

                        % Halt integration if marked as a terminal event
                        if isterminal(idx)
                            t = t(1:n_step); t(end) = t_evt;
                            y = y(1:n_step,:); y(end,:) = y_evt.';
                            terminated = true;
                            break;
                        end
                    end
                end
            end

            if terminated, break; end
            val_old = val_new; % Cache values for the next step
        end
    end
    t = t(1:n_step); y = y(1:n_step,:);
end


function y_next = rk5_single_step(f, tn, yn, h)
% Un singolo passo RK5 (coefficienti di Butcher, quinto ordine). Estratta dal
% loop perche' la localizzazione degli eventi la richiama sui sub-passi:
% duplicare gli stadi avrebbe significato due punti da tenere in sincronia.
    k1 = h * f(tn, yn);
    k2 = h * f(tn + 1/4*h, yn + 1/4*k1);
    k3 = h * f(tn + 1/4*h, yn + 1/8*k1 + 1/8*k2);
    k4 = h * f(tn + 1/2*h, yn - 1/2*k2 + k3);
    k5 = h * f(tn + 3/4*h, yn + 3/16*k1 + 9/16*k4);
    k6 = h * f(tn + h, yn - 3/7*k1 + 2/7*k2 + 12/7*k3 - 12/7*k4 + 8/7*k5);

    y_next = yn + (7*k1 + 32*k3 + 12*k4 + 32*k5 + 7*k6) / 90;
end


function [t_evt, y_evt] = localize_event( ...
        f, eventFcn, other, idx, tn, yn, h, val_lo, val_hi, y_hi)
% Localizza il crossing della componente idx della funzione evento dentro il
% bracket [tn, tn+h], integrando un sub-passo RK5 da (tn,yn) per ogni
% tentativo -- NON interpolando fra i due estremi (rif. commento nel corpo di
% rk5.m sul perche').
%
% Metodo: secante safeguarded (Illinois). Il bracket viene sempre mantenuto
% (l'iterato che non cambia segno viene sostituito), quindi la convergenza e'
% garantita anche se la funzione evento non e' monotona nel passo, mentre sui
% casi lisci -- la norma qui -- converge in poche iterazioni invece delle ~21
% della bisezione pura su un bracket di 2 s.
%
% Tolleranza: tol_t sul bracket temporale. 1e-6 s a |v| ~ 8 km/s vale ~8 mm di
% errore di posizione, cioe' 6 ordini di grandezza sotto la tolleranza di
% missione (opts.tol_con, 3% del target = ordine 10 km). Il cap di iterazioni
% e' una rete di sicurezza (con Illinois non si arriva mai al cap sui casi
% lisci), non un parametro di taratura.
    tol_t = 1.0e-6;
    max_iter = 40;

    a = 0.0;         fa = val_lo;     % estremo sinistro (tn), valore noto
    b = h;           fb = val_hi;     % estremo destro (tn+h), valore noto
    y_b = y_hi;

    % migliore stima corrente: l'estremo con |valore| minore, cosi' che anche
    % un'uscita anticipata restituisca il punto piu' vicino al crossing
    if abs(fa) <= abs(fb)
        s_best = a;  y_best = yn;
    else
        s_best = b;  y_best = y_b;
    end

    for it = 1:max_iter
        if (b - a) <= tol_t
            break
        end

        % secante sul bracket, con clip di sicurezza dentro (a,b): se la
        % secante propone un punto degenere (funzione piatta o estremi
        % coincidenti) si ripiega sulla bisezione.
        if fb ~= fa
            s = a + (b - a) * fa / (fa - fb);
        else
            s = 0.5 * (a + b);
        end
        margin = 0.01 * (b - a);
        if ~isfinite(s) || s <= a + margin || s >= b - margin
            s = 0.5 * (a + b);
        end

        y_s = rk5_single_step(f, tn, yn, s);
        vals = eventFcn(tn + s, y_s, other);
        fs = vals(idx);

        if abs(fs) <= abs(fa) && abs(fs) <= abs(fb)
            s_best = s;  y_best = y_s;
        end

        if fs == 0
            t_evt = tn + s;  y_evt = y_s;
            return
        end

        if (fa < 0) == (fs < 0)
            % stesso segno di a -> il crossing sta in [s, b]
            a = s;  fa = fs;
            fb = fb * 0.5;          % Illinois: sgonfia l'estremo fermo
        else
            b = s;  fb = fs;  y_b = y_s;
            fa = fa * 0.5;
        end
    end

    if (b - a) <= tol_t
        % bracket chiuso: si prende l'estremo destro, che e' il primo istante
        % in cui l'evento risulta avvenuto (stessa convenzione di ode45)
        y_evt = y_b;
        t_evt = tn + b;
    else
        y_evt = y_best;
        t_evt = tn + s_best;
    end
end
