function xn = bound_transform_inv(xb, al)
% BOUND_TRANSFORM_INV  Inversa di io/bound_transform.m sul ramo principale
%   (l'unico invertibile: [lb-al, ub+al] -> [0,1], rif. bound_transform.m).
%
% SERVE per un solo scopo (rif. solver.m): portare il guess utente opts.x0,
%   che vive nel BOX [0,1]^n dopo la normalizzazione, nello spazio NON
%   vincolato in cui parte il motore. Senza questo passaggio xmean = x0
%   verrebbe poi ri-trasformato in un punto diverso da x0 vicino ai bordi
%   (dove la trasformazione non e' l'identita'), cioe' il solver non
%   partirebbe dal punto richiesto dall'utente.
%
%   INPUT  xb : vettore in [0,1] (componenti fuori da [0,1] sono un errore
%               del chiamante: la normalizzazione di un x0 dentro i bounds
%               fisici sta per costruzione in [0,1])
%          al : come in bound_transform.m (default 0.05)
%   OUTPUT xn : stessa forma di xb, in spazio non vincolato, tale che
%               bound_transform(bound_transform_inv(xb)) == xb
    if nargin < 2 || isempty(al)
        al = 0.05;
    end

    lb = 0;
    ub = 1;
    sz = size(xb);
    v = xb(:);
    assert(all(v >= lb - 1e-12 & v <= ub + 1e-12), 'bound_transform_inv:outOfBox', ...
        'xb deve stare in [0,1] (spazio normalizzato, rif. io/normalize.m).');
    v = min(max(v, lb), ub);        % solo arrotondamenti numerici

    xn = v;
    lo = v < (lb + al);
    hi = v > (ub - al);
    xn(lo) = (lb - al) + 2 * sqrt(al * (v(lo) - lb));
    xn(hi) = (ub + al) - 2 * sqrt(al * (ub - v(hi)));

    xn = reshape(xn, sz);
end
