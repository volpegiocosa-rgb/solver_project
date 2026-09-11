function other = giano_build_other(cfg)
% GIANO_BUILD_OTHER  Costruisce la struct 'other' (contenitore ENV/AER/MOT/
%   GUI/MIS/MASS + runtime, stesso formato consumato da TSTO/source/eom.m,
%   guidance.m, simulator.m) a partire dalle sub-struct di cfg, SENZA
%   leggere alcun file.
%
%   Porting 1:1 di TSTO/source/interface.m (rif. giano-design.md Gate 2):
%   stessa identica logica di mapping, con la sola differenza che i valori
%   arrivano da cfg.LV/cfg.ENV/cfg.atmosphere/cfg.aero_ascent/cfg.GUID/
%   cfg.GUIDANCE_VARS/cfg.MIS (struct gia' in memoria, costruite dal
%   chiamante di giano.m) invece che da un fopen/fgetl su CSV in
%   input_dir. Verificato bit-esatto (isequaln) contro interface.m sui 3
%   dataset TSTO (reference_LV, validation_test, validation_test_2) con
%   uno script di verifica usa-e-getta, non incluso nel pacchetto
%   (rif. giano-design.md, Gate 2).
%
%   INPUT  : cfg   (struct con le sub-struct LV/ENV/atmosphere/aero_ascent/
%                   GUID/GUIDANCE_VARS/MIS, rif. header giano.m)
%   OUTPUT : other (struct ENV/AER/MOT/GUI/MIS/MASS + runtime, identica a
%                   quella prodotta da TSTO/source/interface.m)

    LV   = cfg.LV;
    ENVc = cfg.ENV;
    GUIc = cfg.GUID;
    GVAR = cfg.GUIDANCE_VARS;
    MISc = cfg.MIS;
    ATMO = cfg.atmosphere;
    AERO = cfg.aero_ascent;

    other = struct();

    % -------------------------------------------------------------------
    % ENV (ambiente) -> other.ENV   [costanti WGS84 + sito di lancio]
    % -------------------------------------------------------------------
    other.ENV.Req     = ENVc.Req;
    other.ENV.Rpole   = ENVc.Rpole;
    other.ENV.f       = ENVc.f;
    other.ENV.omega_E = ENVc.omega_E;
    other.ENV.mu      = ENVc.mu;
    other.ENV.lat     = ENVc.lat;
    other.ENV.lon     = ENVc.lon;
    other.ENV.hpad    = ENVc.hpad;
    other.ENV.wgs84   = [ENVc.Req, ENVc.f];

    % Tabelle atmosferiche (US Standard Atmosphere 1976): in interface.m
    % arrivano da atmosphere.csv (colonne indicizzate da un header),
    % qui direttamente dai campi nominati di cfg.atmosphere.
    other.ENV.altitude            = ATMO.altitude(:);
    other.ENV.ambient_pressure    = ATMO.PAtm(:);
    other.ENV.atmospheric_density = ATMO.rho(:);
    other.ENV.sound_speed         = ATMO.Vsound(:);

    % -------------------------------------------------------------------
    % MASS (masse veicolo) -> other.MASS   [rif. interface.m S2b]
    % -------------------------------------------------------------------
    other.MASS.M0       = LV.M0;
    other.MASS.Mfairing = LV.Mfairing;
    other.MASS.Minert1  = LV.Minert1;
    other.MASS.Minert2  = LV.Minert2;
    other.MASS.MProp1   = LV.MProp1;
    other.MASS.MProp2   = LV.MProp2;
    other.MASS.Mpayload = LV.Mpayload;

    % -------------------------------------------------------------------
    % AER (aerodinamica) -> other.AER   [griglia 2D Cd(Mach, AoA)]
    % -------------------------------------------------------------------
    other.AER.Sref = LV.Sref;
    other.AER.Mach = AERO.Mach(:);
    other.AER.AoA  = AERO.AoA(:)';
    other.AER.Cd   = AERO.Cd;

    % -------------------------------------------------------------------
    % MOT (propulsione) -> other.MOT   [array a 2 elementi]
    % -------------------------------------------------------------------
    other.MOT(1).vacuum_thrust           = LV.Thrust1;
    other.MOT(1).mass_flow_rate          = LV.MR1;
    other.MOT(1).nozzle_exit_area        = LV.Aexit1;
    other.MOT(1).number_of_ignite_engine = LV.n_engine1;
    other.MOT(2).vacuum_thrust           = LV.Thrust2;
    other.MOT(2).mass_flow_rate          = LV.MR2;
    other.MOT(2).nozzle_exit_area        = LV.Aexit2;
    other.MOT(2).number_of_ignite_engine = LV.n_engine2;

    % -------------------------------------------------------------------
    % GUI (guida) -> other.GUI   [azimut + variabili di guida baseline]
    % -------------------------------------------------------------------
    other.GUI.launch_azimuth        = GUIc.AZ;
    other.GUI.timeHS_Sep_control    = GUIc.timeHS_Sep_control;
    other.GUI.flux_HS_Sep           = GUIc.flux_HS_Sep;
    other.GUI.zkick                 = GVAR.zkick;
    other.GUI.pitch_over_starting   = GVAR.pitch_over_starting;
    other.GUI.pitch                 = [GVAR.pitch_c1, GVAR.pitch_c2];
    other.GUI.transition_starting   = GVAR.transition_starting;
    other.GUI.pitch_rate_transition = GVAR.pitch_rate_transition;
    other.GUI.pitch_at_transition   = GVAR.pitch_at_transition;
    other.GUI.insertion_starting    = GVAR.insertion_starting;
    other.GUI.AoA_rate              = GVAR.AoA_rate;
    other.GUI.plane_controller      = [GVAR.plane_controller_kp, ...
                                       GVAR.plane_controller_kd, ...
                                       GVAR.plane_controller_ki];
    other.GUI.active_stage          = 1;
    other.GUI.last_pitch            = 0;
    other.GUI.last_yaw               = GUIc.AZ;

    % Rotazione Ol -> In (rif. interface.m per la derivazione completa):
    % versori Est/Nord/Up del sito di lancio espressi nel frame In
    % (ECEF congelato a t0), da lat/lon. Non dipende da AZ.
    lat = ENVc.lat;
    lon = ENVc.lon;
    e_hat = [-sin(lon);            cos(lon);            0      ];
    n_hat = [-sin(lat)*cos(lon);  -sin(lat)*sin(lon);   cos(lat)];
    u_hat = [ cos(lat)*cos(lon);   cos(lat)*sin(lon);   sin(lat)];
    other.GUI.InOl                  = [e_hat, n_hat, u_hat];

    % -------------------------------------------------------------------
    % MIS (missione) -> other.MIS
    % -------------------------------------------------------------------
    other.MIS.apogee_altitude_target     = MISc.apogee_altitude_target;
    other.MIS.perigee_altitude_target    = MISc.perigee_altitude_target;
    other.MIS.target_orbital_inclination = MISc.target_orbital_inclination;

    % -------------------------------------------------------------------
    % Campi di controllo runtime (aggiornati da simulator.m per fase)
    % -------------------------------------------------------------------
    other.isignite = false;
    other.phase    = 0;

end
