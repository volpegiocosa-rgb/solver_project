function r = giano_ratio_tsiolkovsky(m_pl, prop_residual, other)
% GIANO_RATIO_TSIOLKOVSKY  Rateo di scambio payload/propellente sotto
%   l'ipotesi di Delta-v invariante (equazione del razzo), porting 1:1 di
%   real_case/run_continuation.m::local_ratio_tsiolkovsky (nessuna
%   modifica alla formula: pura funzione delle masse del veicolo, gia'
%   priva di I/O nell'originale).
%
%   R = m_i/m_f con m_i = Minert2+MProp2+m_pl (accensione stadio 2),
%   m_f = Minert2+prop_residual+m_pl (fine missione), r = R/(R-1).
%
%   USO: solo come PRIMO guess quando non esiste ancora una pendenza
%   misurata (rif. giano_push_to_wall.m) -- sovrastima per costruzione
%   (ignora che il Delta-v richiesto cresce col payload e che il muro e'
%   una tangenza, non un esaurimento graduale, rif. header di
%   real_case/run_continuation.m per la misura completa), quindi genera
%   un bracket superiore con una sola valutazione invece di essere preso
%   come valore accurato.
%
%   INPUT  : m_pl            payload del punto noto [kg]
%            prop_residual   propellente residuo stadio 2 al quel punto [kg]
%            other           struct fisica (other.MASS.Minert2/.MProp2)
%   OUTPUT : r                rateo dMpayload/dMprop stimato

    D = other.MASS.Minert2;
    P = other.MASS.MProp2;
    R = (D + P + m_pl) / (D + prop_residual + m_pl);
    if R <= 1
        r = 1;
    else
        r = R / (R - 1);
    end

end
