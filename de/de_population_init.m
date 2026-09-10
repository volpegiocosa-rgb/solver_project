function X0 = de_population_init(n, pop_size, opts)
% DE_POPULATION_INIT  Popolazione iniziale in [0,1]^n per il solver DE (rif. piano di
%   sessione "confronto DE vs CMA-ES+ARCH"; analogo -- esteso a un insieme di punti -- di
%   core/init_mean.m, che sceglie invece un singolo xmean per CMA-ES).
%
%   Copertura quasi-uniforme via Sobol (riuso core/sobol_point.m, stessa tabella Joe-Kuo
%   gia' validata e licenziata, limite n<=40 ereditato). idx=2..pop_size+1 per evitare i
%   punti degeneri idx=0/1 (tutti-0 / tutti-0.5 in ogni dimensione, rif. core/sobol_point.m
%   e core/init_mean.m per lo stesso vincolo).
%
%   Per n>40: fallback ESPLICITO (warning, non silenzioso, rif. CLAUDE.md S7) a
%   campionamento uniforme casuale -- copertura iniziale meno regolare ma nessun errore
%   bloccante qui (a differenza di core/sobol_point.m/io/parse_opts.m). NOTA: se questa
%   funzione e' raggiunta tramite solver_de.m/io/parse_opts_de.m con opts.init_mode='sobol'
%   (default ereditato da parse_opts.m) e opts.x0 assente, n>40 viene gia' intercettato PRIMA
%   da parse_opts.m con un errore esplicito (stesso limite, verifica ridondante ma innocua
%   per il caso reale, n=10) -- il fallback qui sotto e' raggiungibile solo chiamando questa
%   funzione direttamente (es. de/de_smoke_test.m) o con opts.init_mode='center' (che salta
%   il controllo di parse_opts.m ma non quello di core/sobol_point.m). Non risolto per
%   scelta: fuori scope per n=10 del caso reale (rif. piano di sessione, item (c)).
%
%   Se opts.x0 e' presente (gia' normalizzato in [0,1] dal chiamante, rif. solver_de.m):
%   sovrascrive la colonna 1. A differenza di CMA-ES (dove x0 diventa il 100% del peso
%   iniziale, xmean), qui x0 e' diluito a 1 membro su pop_size -- differenza strutturale
%   accettata fra un algoritmo a singolo punto e uno a popolazione, non un difetto.
%
%   opts.init_mode (sobol|center, ereditato da parse_opts.m) e' IGNORATO qui: ha semantica
%   di scelta di un SINGOLO punto (mean CMA-ES), non di costruzione di una popolazione.
%
%   INPUT  n        : dimensione (runtime, mai cablata)
%          pop_size : numero di individui
%          opts     : struct opts (letto solo opts.x0)
%   OUTPUT X0       : n x pop_size, componenti in [0,1]
    if n <= 40
        X0 = zeros(n, pop_size);
        for k = 1:pop_size
            X0(:, k) = sobol_point(n, k + 1);
        end
    else
        warning('de_population_init:sobolDimCap', ...
            ['n=%d > 40: tabella Sobol Joe-Kuo imbarcata non copre questa dimensione ' ...
             '(rif. core/sobol_point.m). Fallback a campionamento uniforme casuale, ' ...
             'copertura iniziale meno regolare (non bloccante).'], n);
        X0 = rand(n, pop_size);
    end

    if isfield(opts, 'x0') && ~isempty(opts.x0)
        X0(:, 1) = opts.x0(:);
    end
end
