function xb = bound_transform(xn, al)
% BOUND_TRANSFORM  Mappa R^n -> [0,1]^n per il bound handling del motore
%   (rif. CLAUDE.md S5.1/S6, gap dichiarato in Fase 2 e risolto qui).
%
% MOTIVO (misurato, non teorico -- rif. real_case/diagnostic_plan.md, T2):
%   cmaes_ask.m campiona senza vincoli di bound (invarianza affine, come
%   purecmaes.m), quindi la media della distribuzione puo' uscire da [0,1]^n.
%   Finche' l'uscita veniva CLIPPATA (clip in real_case/traj_cost.m, Fase 5)
%   tutti i candidati fuori dominio collassavano sullo STESSO punto di bordo:
%   f e vincoli identici -> ranking tutto pareggi -> nessun segnale di
%   selezione. Misurato sul caso reale TSTO: dalla generazione ~76 in poi la
%   popolazione era un unico punto ripetuto 10 volte, con 9 componenti su 10
%   incollate ai bound, per 1100+ generazioni (12000 valutazioni sprecate).
%
% APPROCCIO (porting, non reinvenzione -- rif. CLAUDE.md S10):
%   Boundary transformation di Hansen (pycma, cma/boundary_transformation.py,
%   classe BoundTransform / _shift_or_mirror_into_invertible_domain +
%   patch quadratiche). Il motore lavora in uno spazio NON vincolato; la
%   trasformazione fa parte della funzione obiettivo (il motore non la vede,
%   rif. CLAUDE.md S3: /core resta ignaro). Proprieta' rilevanti:
%     - identita' nella parte interna del dominio, [al, 1-al];
%     - continua e C1 sui bound (patch quadratiche di semi-ampiezza al);
%     - mirroring periodico fuori dominio: NESSUN plateau, quindi due
%       candidati distinti fuori dominio restano distinti (e' esattamente
%       cio' che il clip distruggeva);
%     - nessuna penalita' additiva sull'obiettivo (compatibile con il divieto
%       di CLAUDE.md S5.2) e nessuna interazione con ARCH.
%
% NOTA: la trasformazione NON e' iniettiva (il mirroring ripiega lo spazio):
%   piu' punti non vincolati mappano sullo stesso punto del box. E' la
%   proprieta' accettata anche nel riferimento; l'alternativa (penalita' di
%   box) e' stata scartata dall'utente in favore di questa (decisione di
%   sessione, opzione (a) del piano).
%
%   INPUT  xn : vettore n x 1 (o 1 x n) in spazio NON vincolato
%          al : semi-ampiezza della patch quadratica ai bordi (opzionale).
%               Default 0.05 = min((ub-lb)/2, (1+|lb|)/20) del riferimento
%               valutato su lb=0, ub=1 (il dominio normalizzato di /io).
%   OUTPUT xb : stessa forma di xn, componenti in [0,1]
    if nargin < 2 || isempty(al)
        al = 0.05;
    end
    assert(al > 0 && al <= 0.5, 'bound_transform:badAl', ...
        'al deve stare in (0, 0.5] (semi-ampiezza della patch nel dominio [0,1]).');

    lb = 0;
    ub = 1;
    sz = size(xn);
    y = xn(:);

    % --- ripiegamento periodico in [lb-al, ub+al] (invertible domain) ------
    % Applicato SOLO ai punti che ne escono: il mod reintrodurrebbe altrimenti
    % un errore di arrotondamento ~1e-17 anche sui punti gia' interni, dove la
    % trasformazione deve essere l'identita' ESATTA (altrimenti opts.x0 e i
    % punti interni non tornerebbero identici a se stessi bit per bit, con
    % perdita della riproducibilita' richiesta da CLAUDE.md S8).
    span = (ub + al) - (lb - al);       % ampiezza del dominio invertibile
    period = 2 * span;
    out = y < (lb - al) | y > (ub + al);
    if any(out)
        w = mod(y(out) - (lb - al), period);
        fold = w > span;
        w(fold) = period - w(fold);
        y(out) = w + (lb - al);
    end

    % --- patch quadratiche sui due bordi, identita' all'interno -----------
    xb = y;
    lo = y < (lb + al);
    hi = y > (ub - al);
    xb(lo) = lb + (y(lo) - (lb - al)).^2 / (4 * al);
    xb(hi) = ub - (y(hi) - (ub + al)).^2 / (4 * al);

    xb = reshape(xb, sz);
end
