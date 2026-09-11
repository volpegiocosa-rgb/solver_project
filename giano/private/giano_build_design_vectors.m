function [x0, lb, ub, ang_idx, i_payload] = giano_build_design_vectors(design_variables)
% GIANO_BUILD_DESIGN_VECTORS  Assembla x0/lb/ub (10x1, ordine fisico fisso
%   di TSTO/source/traj_problem.m) a partire da cfg.design_variables,
%   accedendo ai campi PER NOME (rif. giano-design.md H10) tramite l'unica
%   fonte d'ordine giano_design_var_order.m -- l'ordine con cui il
%   chiamante ha assegnato i campi di design_variables non conta.
%
%   Deriva anche, sempre per nome (mai per posizione cablata, rif. H4/H3):
%     ang_idx    indici (dentro il vettore x a 10 componenti) delle
%                variabili in GRADI, da convertire in radianti prima di
%                traj_problem.m. Insieme fisso {pitch_c1, pitch_c2,
%                pitch_rate_transition, AoA_rate} -- stesso insieme di
%                oggi (real_case/traj_cost.m ang_idx=[3,4,6,8]), ma
%                derivato dal NOME del campo invece che da un array di
%                indici letterali: sopravvive a qualunque riordino dei
%                campi in cfg.design_variables.
%     i_payload  indice di 'Mpayload' dentro il vettore x (oggi usato dal
%                predittore Tsiolkovsky della continuazione, Gate 5).
%
%   INPUT  : design_variables  struct con i 10 campi di
%                               giano_design_var_order.m, ciascuno con
%                               .x0 .lb .ub (numerici scalari)
%   OUTPUT : x0, lb, ub         10x1, ordine fisico fisso
%            ang_idx            vettore indici (dentro 1:10) da convertire
%                               deg->rad
%            i_payload          indice scalare di Mpayload

    order = giano_design_var_order();
    n = numel(order);

    x0 = zeros(n, 1);
    lb = zeros(n, 1);
    ub = zeros(n, 1);

    for k = 1:n
        name = order{k};
        if ~isfield(design_variables, name)
            error('giano:missingDesignVariable', ...
                'cfg.design_variables.%s mancante (rif. giano_design_var_order.m).', name);
        end
        v = design_variables.(name);
        if ~isfield(v, 'x0') || ~isfield(v, 'lb') || ~isfield(v, 'ub')
            error('giano:badDesignVariable', ...
                'cfg.design_variables.%s deve avere i campi .x0 .lb .ub.', name);
        end
        if v.lb > v.ub
            error('giano:badDesignVariableBounds', ...
                'cfg.design_variables.%s: lb (%g) > ub (%g).', name, v.lb, v.ub);
        end
        x0(k) = v.x0;
        lb(k) = v.lb;
        ub(k) = v.ub;
    end

    % --- variabili angolari (gradi, da convertire in radianti) ----------
    % Insieme fisso PER NOME (contratto con traj_problem.m/eom.m interni,
    % che lavorano in radianti): non dipende dall'ordine di 'order' sopra,
    % ricalcolato ogni volta con ismember per restare corretto anche se
    % l'ordine fisico dovesse cambiare in futuro.
    angular_names = {'pitch_c1', 'pitch_c2', 'pitch_rate_transition', 'AoA_rate'};
    ang_idx = find(ismember(order, angular_names));

    % --- indice della massa payload ---------------------------------------
    i_payload = find(strcmp(order, 'Mpayload'));

end
