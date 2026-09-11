function other_run = giano_build_other_run(x, other)
% GIANO_BUILD_OTHER_RUN  Sovrascrive le variabili di design su una copia
%   di 'other' e reinizializza lo stato runtime pre-lancio -- porting 1:1
%   della sezione 1 di TSTO/source/traj_problem.m (righe ~100-120),
%   duplicato qui DELIBERATAMENTE (rif. giano-design.md Gate 6) perche'
%   traj_problem.m non espone questo passo separatamente (lo fa e poi
%   chiama simulator.m con config.minimal_output=true SEMPRE, senza modo
%   di richiedere l'output completo -- rif. header giano_full_res.m) e
%   TSTO e' un repository esterno che non si vuole modificare per un
%   dettaglio del solo giano.m. Se il layout delle 10 variabili di design
%   cambiasse in TSTO/source/traj_problem.m, questa function va
%   aggiornata in coppia (stesso ordine fisico di
%   giano_design_var_order.m).
%
%   INPUT  : x         10x1, GIA' preparato da giano_prepare_x.m (clip +
%                       deg->rad: unita' native TSTO su tutte le
%                       componenti, radianti sugli angoli)
%            other     struct "pristine" (giano_build_other.m)
%   OUTPUT : other_run  copia di 'other' con GUI/MASS sovrascritte dalle
%                       10 variabili di design e lo stato runtime
%                       (active_stage/last_pitch/last_yaw/isignite/phase)
%                       reinizializzato allo stato pre-lancio

    other_run = other;

    other_run.GUI.zkick                 = x(1);
    other_run.GUI.pitch_over_starting   = x(2);
    other_run.GUI.pitch                 = [x(3), x(4)];
    other_run.GUI.transition_starting   = x(5);
    other_run.GUI.pitch_rate_transition = x(6);
    other_run.GUI.insertion_starting    = x(7);
    other_run.GUI.AoA_rate              = x(8);
    other_run.GUI.plane_controller(1)   = x(9);
    other_run.MASS.Mpayload             = x(10);

    other_run.GUI.active_stage = 1;
    other_run.GUI.last_pitch   = 0;
    other_run.GUI.last_yaw     = other_run.GUI.launch_azimuth;
    other_run.isignite         = false;
    other_run.phase            = 0;

end
