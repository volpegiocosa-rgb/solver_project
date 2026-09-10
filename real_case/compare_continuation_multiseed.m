function compare_continuation_multiseed()
% COMPARE_CONTINUATION_MULTISEED  Confronto multi-seed DE+Deb vs CMA-ES+ARCH sulla stessa
%   logica di continuazione (rif. results/de_vs_cmaes_continuation.md per il confronto a
%   singolo seed, gia' favorevole a DE: +1.9% payload, -44% valutazioni, 1.7x piu' veloce).
%   Verifica se quel vantaggio e' sistematico o un caso singolo.
%
%   Per ogni seed in {1..5} e ogni solver ('solver'=CMA-ES+ARCH, 'solver_de'=DE+Deb):
%   run_continuation() FRESCA (nessun warm_start.mat portato da una run all'altra --
%   altrimenti i seed si contaminerebbero, il primo che gira "regalerebbe" il suo punto
%   certificato al successivo). Stesso optimizer_settings.csv, stesso dataset per entrambi
%   i solver e tutti i seed. Il warm_start.mat pre-esistente dell'utente (se presente) viene
%   messo da parte PRIMA e ripristinato IDENTICO alla fine (nessuna perdita di stato).
%
%   Output: results/de_vs_cmaes_continuation_multiseed.{csv,md}
%
%   NOTA: file di FUNZIONE (non script) -- richiede una funzione ausiliaria locale
%   (r_idx_of), non supportata in coda a un file script in Octave (a differenza di
%   MATLAB R2016b+, verificato in sessione).

    here = fileparts(mfilename('fullpath'));
    addpath(here);

    seed_file = fullfile(here, 'warm_start.mat');
    backup_file = fullfile(here, 'warm_start_user_backup_multiseed.mat');

    had_existing = exist(seed_file, 'file') == 2;
    if had_existing
        copyfile(seed_file, backup_file);
        fprintf('warm_start.mat pre-esistente messo da parte in %s.\n', backup_file);
    end

    seeds = 1:5;
    % Portfolio di solver (rif. optimizer_settings.csv, campo solver_choice): 1=CMA-ES+ARCH,
    % 2=DE+Deb. solver_labels e' solo per etichettare righe/report, non entra nella chiamata.
    solver_choices = [1, 2];
    solver_labels = {'cmaes_arch', 'de_deb'};

    n_rows = numel(seeds) * numel(solver_choices);
    rows = struct('solver', cell(1, n_rows), 'seed', cell(1, n_rows), ...
        'mpayload', cell(1, n_rows), 'feasible', cell(1, n_rows), ...
        'n_eval', cell(1, n_rows), 'n_stage_completed', cell(1, n_rows), ...
        'wall_clock_s', cell(1, n_rows));

    r_idx = 0;
    for si = 1:numel(seeds)
        for sj = 1:numel(solver_choices)
            r_idx = r_idx + 1;
            if exist(seed_file, 'file') == 2
                delete(seed_file);
            end

            fprintf('\n\n##### seed=%d solver=%s #####\n', seeds(si), solver_labels{sj});
            t0 = tic;
            out = run_continuation(struct('seed', seeds(si), 'solver_choice', solver_choices(sj)));
            wall_clock_s = toc(t0);

            if isfield(out, 'Mpayload') && ~isempty(out.Mpayload)
                mp = out.Mpayload;
            else
                mp = NaN;
            end

            rows(r_idx).solver = solver_labels{sj};
            rows(r_idx).seed = seeds(si);
            rows(r_idx).mpayload = mp;
            rows(r_idx).feasible = out.feasible;
            rows(r_idx).n_eval = out.n_eval;
            rows(r_idx).n_stage_completed = size(out.stage_log, 1);
            rows(r_idx).wall_clock_s = wall_clock_s;

            fprintf('\n>>> RIEPILOGO seed=%d solver=%s: Mpayload=%.6g feasible=%d n_eval=%d wall=%.1fs\n\n', ...
                seeds(si), solver_labels{sj}, mp, out.feasible, out.n_eval, wall_clock_s);
        end
    end

    if exist(seed_file, 'file') == 2
        delete(seed_file);
    end
    if had_existing
        movefile(backup_file, seed_file);
        fprintf('warm_start.mat pre-esistente ripristinato (nessuna perdita di stato).\n');
    end

    % === output CSV ==========================================================
    results_dir = fullfile(here, '..', 'results');
    csv_out = fullfile(results_dir, 'de_vs_cmaes_continuation_multiseed.csv');
    fid = fopen(csv_out, 'w');
    fprintf(fid, 'solver,seed,mpayload_kg,feasible,n_eval,n_stage_completed,wall_clock_s\n');
    for k = 1:n_rows
        fprintf(fid, '%s,%d,%.6g,%d,%d,%d,%.3f\n', ...
            rows(k).solver, rows(k).seed, rows(k).mpayload, rows(k).feasible, ...
            rows(k).n_eval, rows(k).n_stage_completed, rows(k).wall_clock_s);
    end
    fclose(fid);
    fprintf('CSV scritto: %s\n', csv_out);

    % === output Markdown ====================================================
    md_out = fullfile(results_dir, 'de_vs_cmaes_continuation_multiseed.md');
    fid = fopen(md_out, 'w');
    fprintf(fid, '# Confronto multi-seed DE+Deb vs CMA-ES+ARCH -- logica di continuazione\n\n');
    fprintf(fid, 'Stessa procedura di `results/de_vs_cmaes_continuation.md` (singolo seed), ripetuta su %d seed di partenza (1..%d). ', numel(seeds), numel(seeds));
    fprintf(fid, 'Ogni run parte da zero (nessun `warm_start.mat` ereditato da un''altra run/seed). Stesso `optimizer_settings.csv`, stesso dataset `validation_test_2`, per entrambi i solver.\n\n');

    fprintf(fid, '| solver | seed | Mpayload [kg] | feasible | n_eval | stadi completati | wall_clock [s] |\n');
    fprintf(fid, '|---|---|---|---|---|---|---|\n');
    for k = 1:n_rows
        fprintf(fid, '| %s | %d | %.6g | %d | %d | %d | %.1f |\n', ...
            rows(k).solver, rows(k).seed, rows(k).mpayload, rows(k).feasible, ...
            rows(k).n_eval, rows(k).n_stage_completed, rows(k).wall_clock_s);
    end
    fprintf(fid, '\n');

    for sj = 1:numel(solver_labels)
        mask = strcmp({rows.solver}, solver_labels{sj});
        mp = [rows(mask).mpayload];
        wc = [rows(mask).wall_clock_s];
        ne = [rows(mask).n_eval];
        fe = [rows(mask).feasible];
        fprintf(fid, '## Aggregato: %s\n\n', solver_labels{sj});
        fprintf(fid, '- Mpayload: mediana=%.6g kg, media=%.6g kg, min=%.6g kg, max=%.6g kg\n', ...
            median(mp), mean(mp), min(mp), max(mp));
        fprintf(fid, '- n_eval: mediana=%.0f, media=%.0f\n', median(ne), mean(ne));
        fprintf(fid, '- wall clock: mediana=%.1fs, media=%.1fs\n', median(wc), mean(wc));
        fprintf(fid, '- feasible: %d/%d seed\n\n', sum(fe), numel(fe));
    end

    fprintf(fid, '## Confronto diretto per seed (DE - CMA-ES)\n\n');
    fprintf(fid, '| seed | Mpayload DE [kg] | Mpayload CMA-ES [kg] | delta [kg] | delta [%%] | wall DE [s] | wall CMA-ES [s] | speedup |\n');
    fprintf(fid, '|---|---|---|---|---|---|---|---|\n');
    for si = 1:numel(seeds)
        idx_de = r_idx_of(rows, 'de_deb', seeds(si));
        idx_cma = r_idx_of(rows, 'cmaes_arch', seeds(si));
        mp_de = rows(idx_de).mpayload;
        mp_cma = rows(idx_cma).mpayload;
        wc_de = rows(idx_de).wall_clock_s;
        wc_cma = rows(idx_cma).wall_clock_s;
        fprintf(fid, '| %d | %.6g | %.6g | %+.1f | %+.2f | %.1f | %.1f | %.2fx |\n', ...
            seeds(si), mp_de, mp_cma, mp_de - mp_cma, 100 * (mp_de - mp_cma) / mp_cma, ...
            wc_de, wc_cma, wc_cma / wc_de);
    end
    fclose(fid);
    fprintf('Markdown scritto: %s\n', md_out);
end


function idx = r_idx_of(rows, solver_name, seed_val)
    idx = find(strcmp({rows.solver}, solver_name) & [rows.seed] == seed_val, 1);
end
