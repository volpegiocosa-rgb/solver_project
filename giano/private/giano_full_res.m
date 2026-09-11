function RES = giano_full_res(x_best, other)
% GIANO_FULL_RES  Ri-simulazione del punto migliore con output COMPLETO
%   (rif. giano-design.md Gate 6, H8, INT-001): TSTO/source/traj_problem.m
%   usa SEMPRE config.minimal_output=true durante l'ottimizzazione (rif.
%   CLAUDE.md S11 Fase 5, "requisito 5 minuti" -- create_output.m e'
%   costoso, e durante l'ottimizzazione serve solo l'ultimo istante),
%   quindi RES (TSTO/interface_specification.md S3) non viene mai
%   costruita durante il loop. Questa function la produce UNA SOLA VOLTA,
%   a fine ottimizzazione, sul solo punto migliore.
%
%   Compone giano_prepare_x.m (Gate 4/6, clip+deg2rad) e
%   giano_build_other_run.m (Gate 6, sovrascrittura GUI/MASS) e chiama
%   TSTO/source/simulator.m DIRETTAMENTE (non traj_problem.m, che non
%   permette di richiedere l'output completo) con
%   config.minimal_output=false (esplicito, anche se e' gia' il default
%   di simulator.m quando il campo manca -- dichiarato, non implicito) e
%   config.silent=true (necessario: senza, simulator.m chiamerebbe
%   plotter.m/write_log.m, che SCRIVONO file -- rif. CON-001, verificato
%   leggendo simulator.m S520-524).
%
%   INPUT  : x_best  10x1, punto migliore in unita' MISTE (stessa
%                    convenzione di cfg.design_variables: gradi sulle
%                    componenti angolari, rif. giano_prepare_x.m)
%            other   struct "pristine" + other.opt_bounds/.ang_idx (rif.
%                    giano.m, Gate 3/5 -- STESSA 'other' usata durante
%                    l'ottimizzazione, invariata)
%   OUTPUT : RES     struct completa (TSTO/interface_specification.md S3)

    x_native = giano_prepare_x(x_best, other);
    other_run = giano_build_other_run(x_native, other);

    config = struct();
    config.other          = other_run;
    config.silent         = true;
    config.minimal_output = false;

    % Passthrough opzionale (rif. giano-design.md H11), stessa fonte di
    % giano_traj_cost.m (other.sim_opts, impostato da giano.m da
    % cfg.opts): qui verso simulator.m direttamente, non attraverso
    % traj_problem.m (che questa function bypassa apposta, rif. header).
    if isfield(other, 'sim_opts')
        sf = fieldnames(other.sim_opts);
        for k = 1:numel(sf)
            config.(sf{k}) = other.sim_opts.(sf{k});
        end
    end

    RES = simulator(config);

end
