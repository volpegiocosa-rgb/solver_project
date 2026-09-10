function xb = de_reflect_bounds(x)
% DE_REFLECT_BOUNDS  Ripiegamento periodico in [0,1] per il bound handling della popolazione
%   DE (rif. piano di sessione "confronto DE vs CMA-ES+ARCH").
%
% MOTIVO (rif. io/bound_transform.m header, misurato sul caso reale TSTO): un semplice CLIP
%   al bordo collassa candidati distinti fuori dominio sullo STESSO punto di bordo -> f e
%   vincoli identici -> nessun segnale di selezione (misurato: popolazione CMA-ES intrappolata
%   su un angolo del dominio per 1100+ generazioni prima del fix). Qui si usa lo stesso
%   ripiegamento periodico (mirroring, nessun plateau: punti distinti fuori dominio restano
%   distinti dopo il fold) gia' validato in io/bound_transform.m, ma SENZA la patch quadratica
%   ai bordi: quella serve a CMA-ES per la continuita' C1 richiesta dall'adattamento di
%   covarianza; DE e' comparativo (Deb's rule confronta punti, non segue un gradiente), non
%   ha bisogno di un mapping liscio -- solo che il ripiegamento preservi la distinzione fra
%   candidati. Per questo e' un file a se' (non io/bound_transform.m con al->0, valore non
%   ammesso dal suo assert al>0).
%
%   Vettorizzato: opera elementwise su qualunque shape (es. l'intera popolazione n x pop_size
%   in un'unica chiamata, rif. de/de_ask.m).
%
%   INPUT  x  : array, tipicamente in [0,1] ma non garantito (es. un candidato appena mutato)
%   OUTPUT xb : stessa shape di x, componenti in [0,1]
    lb = 0;
    ub = 1;
    span = ub - lb;
    period = 2 * span;

    xb = mod(x - lb, period);
    fold = xb > span;
    xb(fold) = period - xb(fold);
    xb = xb + lb;
end
