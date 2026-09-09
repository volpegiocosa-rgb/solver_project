function [v_final, dv_delivered, residual_mass, ...
          apogee_reached, perigee_reached, inclination_reached, ...
          dv_required, dv_available] = ...
          injection_target_orbit( ...
              r0, v0, m0, available_propellant, ...
              apogee_target, perigee_target, inclination_target, ...
              ENV, ue)
%INJECTION_TARGET_ORBIT Impulsive injection toward a target Keplerian orbit.
%
% The target orbit is defined by:
%   - apogee altitude;
%   - perigee altitude;
%   - inclination.
%
% The burn position r0 may be any point of the target orbit. In the
% general case, up to four target velocities are compatible with the
% imposed apsides and inclination:
%   - two compatible orbital planes;
%   - two radial branches, with increasing or decreasing radius.
%
% The candidate requiring the minimum impulsive delta-v from v0 is used.
% If the available propellant is insufficient, all available delta-v is
% delivered in the direction of the selected maneuver.
%
% INPUTS
%   r0                    [3x1] [m]       inertial position at the burn
%   v0                    [3x1] [m/s]     inertial velocity before the burn
%   m0                    [kg]            mass before the burn
%   available_propellant  [kg]            usable propellant mass
%   apogee_target         [m]             target altitude above ENV.Req
%   perigee_target        [m]             target altitude above ENV.Req
%   inclination_target    [rad]           target inclination in [0, pi]
%   ENV.mu                [m^3/s^2]       gravitational parameter
%   ENV.Req               [m]             reference equatorial radius
%   ue                    [m/s]           effective exhaust velocity
%
% OUTPUTS
%   v_final               [3x1] [m/s]     inertial velocity after the burn
%   dv_delivered          [m/s]           delivered delta-v magnitude
%   residual_mass         [kg]            mass after the burn
%   apogee_reached        [m]             achieved altitude above ENV.Req
%   perigee_reached       [m]             achieved altitude above ENV.Req
%   inclination_reached   [rad]           achieved inclination
%   dv_required           [m/s]           delta-v needed to reach the target
%   dv_available          [m/s]           delta-v the residual propellant can
%                                         deliver (Tsiolkovsky). The pair is
%                                         exported so that the external
%                                         optimizer can constrain the mission
%                                         with the INEQUALITY that actually
%                                         limits it, dv_required <=
%                                         dv_available, instead of relying on
%                                         the terminal equalities alone (which
%                                         this routine satisfies BY
%                                         CONSTRUCTION whenever the propellant
%                                         is sufficient, and saturates
%                                         otherwise). Rif. solver_project
%                                         CLAUDE.md S11 Fase 5 / real_case/
%                                         diagnostic_plan.md (T1).
%
% NOTES
%   - The maneuver is impulsive.
%   - The dynamics are Keplerian and use a two-body model.
%   - For a parabolic or hyperbolic final trajectory, apogee_reached = Inf.

    validate_inputs( ...
        r0, v0, m0, available_propellant, ...
        apogee_target, perigee_target, inclination_target, ...
        ENV, ue);

    r0 = r0(:);
    v0 = v0(:);

    % Proiezione radiale del punto di burn sull'intervallo ammissibile
    % [rp_target, ra_target], usata SOLO per calcolare il delta-v richiesto.
    % Serve perche' una manovra IMPULSIVA cambia la velocita' ma non la
    % posizione: il punto di burn deve appartenere all'orbita target,
    % altrimenti (target circolare) il problema geometrico non ha soluzione.
    % validate_inputs ammette uno scarto fino a radius_tolerance, che e'
    % errore di localizzazione dell'evento di apogeo (vedi nota la' sopra),
    % e qui lo si assorbe proiettando.
    % IMPORTANTE: l'orbita RAGGIUNTA e' valutata sul punto VERO (r0, non
    % r0_burn) con la v_final ottenuta -- cosi' lo scarto non viene nascosto:
    % ricompare nei residui h e la feasibility resta giudicata sul residuo
    % reale (rif. CLAUDE.md S7: non mascherare un errore dentro il modello).
    % Scarti maggiori della tolleranza NON vengono proiettati: restano un
    % errore, che simulator.m/traj_problem.m trattano come missione non
    % chiusa (violazione pagata dai residui h).
    r_norm_burn = norm(r0);
    r_admissible = min(max(r_norm_burn, ENV.Req + perigee_target), ...
                       ENV.Req + apogee_target);
    r0_burn = r0;
    if r_admissible ~= r_norm_burn
        r0_burn = r0 * (r_admissible / r_norm_burn);
    end

    required_delta_v = eval_injection_delta_v( ...
        r0_burn, v0, apogee_target, perigee_target, inclination_target, ENV);

    [v_final, dv_delivered, residual_mass, dv_required, dv_available] = ...
        deliver_delta_v( ...
            v0, required_delta_v, m0, available_propellant, ue);

    [apogee_reached, perigee_reached, inclination_reached] = ...
        orbital_apsides_inclination( ...
            r0, v_final, ENV.mu, ENV.Req);

end


function validate_inputs( ...
    r0, v0, m0, available_propellant, ...
    apogee_target, perigee_target, inclination_target, ...
    ENV, ue)
%VALIDATE_INPUTS Validate dimensions, values and target compatibility.

    validateattributes(r0, {'numeric'}, ...
        {'real', 'finite', 'vector', 'numel', 3}, ...
        mfilename, 'r0');

    validateattributes(v0, {'numeric'}, ...
        {'real', 'finite', 'vector', 'numel', 3}, ...
        mfilename, 'v0');

    validateattributes(m0, {'numeric'}, ...
        {'real', 'finite', 'scalar', 'positive'}, ...
        mfilename, 'm0');

    validateattributes(available_propellant, {'numeric'}, ...
        {'real', 'finite', 'scalar', 'nonnegative'}, ...
        mfilename, 'available_propellant');

    validateattributes(apogee_target, {'numeric'}, ...
        {'real', 'finite', 'scalar'}, ...
        mfilename, 'apogee_target');

    validateattributes(perigee_target, {'numeric'}, ...
        {'real', 'finite', 'scalar'}, ...
        mfilename, 'perigee_target');

    validateattributes(inclination_target, {'numeric'}, ...
        {'real', 'finite', 'scalar', '>=', 0.0, '<=', pi}, ...
        mfilename, 'inclination_target');

    validateattributes(ue, {'numeric'}, ...
        {'real', 'finite', 'scalar', 'positive'}, ...
        mfilename, 'ue');

    if ~isstruct(ENV) || ~isscalar(ENV)
        error('injection_target_orbit:InvalidEnvironment', ...
            'ENV must be a scalar structure.');
    end

    if ~isfield(ENV, 'mu') || ~isfield(ENV, 'Req')
        error('injection_target_orbit:InvalidEnvironment', ...
            'ENV must contain the fields mu and Req.');
    end

    validateattributes(ENV.mu, {'numeric'}, ...
        {'real', 'finite', 'scalar', 'positive'}, ...
        mfilename, 'ENV.mu');

    validateattributes(ENV.Req, {'numeric'}, ...
        {'real', 'finite', 'scalar', 'positive'}, ...
        mfilename, 'ENV.Req');

    if available_propellant >= m0
        error('injection_target_orbit:InvalidPropellantMass', ...
            'available_propellant must be strictly lower than m0.');
    end

    if perigee_target > apogee_target
        error('injection_target_orbit:InvalidTargetApsides', ...
            'perigee_target cannot exceed apogee_target.');
    end

    rp_target = ENV.Req + perigee_target;
    ra_target = ENV.Req + apogee_target;

    if rp_target <= 0.0
        error('injection_target_orbit:InvalidPerigeeRadius', ...
            'The target perigee radius must be positive.');
    end

    r_norm = norm(r0);

    if r_norm <= eps(ENV.Req)
        error('injection_target_orbit:InvalidPosition', ...
            'The norm of r0 must be greater than zero.');
    end

    % Tolleranza sul raggio del punto di burn. Il valore precedente,
    % max(1e-3, 1e-10*r), era di fatto 1 mm: sufficiente solo per un target
    % ELLITTICO, dove [rp,ra] e' un intervallo ampio (200 km in
    % input/validation_test). Con un target CIRCOLARE (input/validation_test_2:
    % perigeo = apogeo = 400 km) l'intervallo degenera in un PUNTO e il
    % controllo diventa una lama: il punto di fine coast kepleriano (fase 7 di
    % simulator.m) arriva a 0.38 m dal raggio target -- 5.6e-8 in relativo,
    % puro errore di localizzazione dell'evento di apogeo -- e la routine
    % rifiutava l'intero caso. Misurato: il dataset validation_test_2 falliva
    % anche nella configurazione nuda del suo readme (che era stata validata
    % con ode45, prima di rk5.m: cadeva dentro il millimetro per caso).
    % Il valore riflette l'ACCURATEZZA della localizzazione dell'evento di
    % apogeo, non una tolleranza fisica: con un target circolare il punto di
    % fine coast dovrebbe cadere esattamente su ra_target per costruzione
    % (fase 6 innesca quando l'apogeo osculante raggiunge il target, fase 7
    % propaga fino all'apogeo), quindi tutto lo scarto e' errore numerico.
    % REQUISITO (utente, 2026-09-09): l'accuratezza del cross-over di apogeo
    % deve essere MIGLIORE della tolleranza ammessa dalla funzione di costo.
    % Soddisfatto rifinendo la localizzazione degli eventi in rk5.m (secante
    % safeguarded con ri-integrazione RK5 del sub-passo, al posto
    % dell'interpolazione lineare precedente): scarto misurato 0.4 mm su
    % reference_LV e 4-8 mm su validation_test_2 (era rispettivamente ~0.4 m
    % e fino a 1613 m, quest'ultimo dello stesso ordine della tolleranza di
    % missione -- inaccettabile). 1 m e' quindi >100x sopra lo scarto
    % osservato (margine, non un valore al limite) e ~4 ordini di grandezza
    % SOTTO la tolleranza di missione dell'ottimizzatore (opts.tol_con = 3%
    % del target = 12 km su questo dataset).
    radius_tolerance = 1.0;

    if r_norm < rp_target - radius_tolerance || ...
       r_norm > ra_target + radius_tolerance
        error('injection_target_orbit:PositionNotOnTargetOrbit', ...
            ['The current position is not compatible with the target ', ...
             'orbit. Current radius: %.6f m; target interval: ', ...
             '[%.6f, %.6f] m.'], ...
            r_norm, rp_target, ra_target);
    end

end


function [v_final, dv_delivered, residual_mass, dv_required, dv_available] = ...
    deliver_delta_v( ...
        v0, required_delta_v, m0, available_propellant, ue)
%DELIVER_DELTA_V Deliver the requested or maximum available delta-v.

    delta_v_tolerance = 1.0e-10;

    dry_mass = m0 - available_propellant;
    dv_available = ue * log(m0 / dry_mass);
    dv_required = norm(required_delta_v);

    if dv_required <= dv_available + delta_v_tolerance
        dv_delivered = dv_required;
        v_final = v0 + required_delta_v;
        residual_mass = m0 * exp(-dv_delivered / ue);
        residual_mass = max(dry_mass, min(m0, residual_mass));
        return;
    end

    dv_delivered = dv_available;
    residual_mass = dry_mass;

    if dv_required <= delta_v_tolerance
        v_final = v0;
        return;
    end

    delta_v_direction = required_delta_v / dv_required;
    v_final = v0 + dv_delivered * delta_v_direction;

end


function [apogee_altitude, perigee_altitude, inclination] = ...
    orbital_apsides_inclination( ...
        position, velocity, mu, reference_radius)
%ORBITAL_APSIDES_INCLINATION Compute apsides and inclination from state.

    radius = norm(position);

    if radius <= eps(reference_radius)
        error('injection_target_orbit:InvalidFinalPosition', ...
            'The final position norm must be positive.');
    end

    angular_momentum = cross(position, velocity);
    angular_momentum_norm = norm(angular_momentum);

    angular_momentum_tolerance = 1.0e-12 * radius * ...
        max(norm(velocity), sqrt(mu / radius));

    if angular_momentum_norm <= angular_momentum_tolerance
        error('injection_target_orbit:DegenerateFinalOrbit', ...
            ['The final state has nearly zero angular momentum; ', ...
             'apsides and inclination are undefined.']);
    end

    cos_inclination = angular_momentum(3) / angular_momentum_norm;
    cos_inclination = max(-1.0, min(1.0, cos_inclination));
    inclination = acos(cos_inclination);

    eccentricity_vector = ...
        cross(velocity, angular_momentum) / mu - position / radius;
    eccentricity = norm(eccentricity_vector);

    semi_latus_rectum = angular_momentum_norm^2 / mu;
    perigee_radius = semi_latus_rectum / (1.0 + eccentricity);
    perigee_altitude = perigee_radius - reference_radius;

    specific_orbital_energy = ...
        0.5 * dot(velocity, velocity) - mu / radius;

    eccentricity_tolerance = 1.0e-10;
    energy_tolerance = 1.0e-12 * mu / radius;

    is_elliptic = ...
        eccentricity < 1.0 - eccentricity_tolerance && ...
        specific_orbital_energy < -energy_tolerance;

    if is_elliptic
        apogee_radius = semi_latus_rectum / (1.0 - eccentricity);
        apogee_altitude = apogee_radius - reference_radius;
    else
        apogee_altitude = Inf;
    end

end
