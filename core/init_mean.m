function xmean = init_mean(opts, n)
% INIT_MEAN  Sceglie il punto iniziale xmean (rif. CLAUDE.md S5.1).
%   Priorita': opts.x0 (guess utente, GIA' normalizzato in [0,1] da solver.m)
%   -> singolo campione Sobol -> centro 0.5. CMA-ES parte da UN SOLO punto,
%   non da una popolazione (S5.1): Sobol qui produce un unico xmean, non un
%   insieme di individui.
%
%   OUTPUT xmean : vettore colonna n x 1 in spazio normalizzato [0,1].

    if isfield(opts, 'x0') && ~isempty(opts.x0)
        xmean = opts.x0(:);
        assert(numel(xmean) == n, ...
            'init_mean:badX0', 'opts.x0 deve avere lunghezza n (%d attesi, %d ricevuti).', ...
            n, numel(xmean));
        return
    end

    switch opts.init_mode
        case 'center'
            xmean = 0.5 * ones(n, 1);
        case 'sobol'
            % idx>=2: idx=0 e idx=1 sono degeneri (rif. sobol_point.m). Il seed
            % sceglie QUALE punto della sequenza usare (varia tra run "vergini"
            % con seed diverso, resta riproducibile a parita' di seed).
            idx = mod(opts.seed, 65536) + 2;
            xmean = sobol_point(n, idx);
        otherwise
            % Non dovrebbe accadere: parse_opts valida gia' opts.init_mode (S6).
            error('init_mean:badInitMode', ...
                'opts.init_mode deve essere ''sobol'' o ''center'' (validato in parse_opts).');
    end
end
