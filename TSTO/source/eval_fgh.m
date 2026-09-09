function OPT = eval_fgh(RES, other)
	% eval_fgh  Riduce l'esito di una simulazione a [f, g, h] per
	%           l'ottimizzatore esterno (CMA-ES/ARCH, solver_project), come
	%           da interface_specification.md §5.1.
	%
	% Firma adattata rispetto al placeholder di CLAUDE.md ("eval_fgh(T,Y)"),
	% come esplicitamente consentito da CLAUDE.md §7 ("possono essere
	% adattate"): si usa RES (gia' prodotta da create_output.m dentro
	% simulator.m, con l'ultima riga = ultimo istante di qualunque
	% condizione di arresto, propulsa o meno, interface_specification.md
	% §3.4) invece di ricalcolare da T,Y grezzi apogeo/perigeo/inclinazione:
	% quei valori sono gia' colonne di RES (theApogeeAltitude,
	% thePerigeeAltitude, theInclination), evitando di duplicare la logica
	% orbitale di create_output.m. 'other' serve per i target di missione
	% (other.MIS.*, non disponibili in RES) e per Mpayload (other.MASS.*,
	% decisione di progetto sotto).
	%
	% DECISIONE DI PROGETTO (rif. sessione di integrazione con solver_project,
	% conferma utente): la massa payload (other.MASS.Mpayload, LV.csv) e'
	% ora una VARIABILE DI DESIGN (11a componente di x, vedi traj_problem.m),
	% non piu' un valore fisso. L'obiettivo passa quindi dal proxy precedente
	% (massa residua a fine missione, -RES.theMass(end)) alla metrica di
	% performance diretta: f = -Mpayload (massimizzare il payload), con la
	% traiettoria che entra SOLO nei vincoli h (fattibilita' orbitale). Il
	% vecchio proxy era gia' dichiarato "se non valido, va sostituita qui"
	% nell'header precedente di questo file -- sostituzione ora eseguita.
	%
	% Input  : RES    (struct, output di create_output.m/simulator.m)
	%          other  (struct ENV/AER/MOT/GUI/MIS/MASS finale, secondo
	%                  output di simulator.m; qui si usano other.MIS e
	%                  other.MASS.Mpayload)
	% Output : OPT.f  (scalare, da minimizzare)  = -other.MASS.Mpayload
	%                  (massa payload, variabile di design in x, non un
	%                  esito della simulazione: dipende solo da 'other',
	%                  non da RES).
	%          OPT.g  (1x1, vincolo g<=0)         = margine di delta-v del burn
	%                  di injection, ADIMENSIONALE (vedi sezione dedicata sotto).
	%                  Sostituisce il placeholder [] di
	%                  interface_specification.md §5.1.
	%          OPT.h  (vettore 3x1, vincoli h=0)  = errore residuo su
	%                  perigeo/apogeo/inclinazione rispetto al target di
	%                  missione (other.MIS), stesso ordine di
	%                  interface_specification.md §5.1:
	%                    (1) perigee_altitude_target  - perigee_achieved
	%                    (2) apogee_altitude_target   - apogee_achieved
	%                    (3) target_orbital_inclination - inclination_achieved

	if isempty(RES) || ~isfield(RES, 'theMass') || isempty(RES.theMass)
		error('eval_fgh:emptyRES', 'RES vuota o priva di theMass: nessun istante simulato da valutare.');
	end

	apogee_achieved      = RES.theApogeeAltitude(end);
	perigee_achieved     = RES.thePerigeeAltitude(end);
	inclination_achieved = RES.theInclination(end);

	OPT.f = -other.MASS.Mpayload;
	OPT.g = eval_dv_margin_constraint(other);
	% Propellente residuo dello stadio 2 a fine missione. NON e' un vincolo:
	% e' una DIAGNOSTICA usata dal metodo di continuazione esterno
	% (solver_project/real_case/run_continuation.m) come base del predittore.
	% Motivo (rif. CLAUDE.md S11 Fase 5): il limite superiore del payload e'
	% l'esaurimento del propellente di stadio 2 (END_PROP2), quindi questa
	% quantita' va a zero ESATTAMENTE sul muro, mentre OPT.g no (il muro
	% arriva prima che il margine di delta-v si annulli). E' quindi la
	% variabile giusta su cui estrapolare.
	OPT.prop_residual = RES.theMass(end) ...
	                    - (other.MASS.Minert2 + other.MASS.Mpayload);
	OPT.h = [other.MIS.perigee_altitude_target    - perigee_achieved; ...
	         other.MIS.apogee_altitude_target     - apogee_achieved; ...
	         other.MIS.target_orbital_inclination - inclination_achieved];
end


function g = eval_dv_margin_constraint(other)
	% Vincolo di disuguaglianza sul bilancio di delta-v del burn di injection
	% (fase 8 di simulator.m, other.INJ):
	%
	%     g = (dv_required - dv_available) / ue2  <= 0
	%
	% MOTIVO (rif. solver_project/real_case/diagnostic_plan.md, T1 -- misurato,
	% non congetturato): injection_target_orbit.m centra apogeo/perigeo/
	% inclinazione PER COSTRUZIONE ogni volta che il propellente residuo basta,
	% e satura quando non basta. Le tre uguaglianze OPT.h sono quindi quasi
	% binarie (~1e-9 su TUTTO l'insieme ammissibile, ordini di grandezza fuori):
	% l'insieme ammissibile e' una REGIONE, non una varieta' di codimensione 3,
	% e al suo interno non c'e' alcun gradiente che orienti l'ottimizzatore.
	% Il vincolo che limita davvero la missione (e quindi il payload) e' che il
	% delta-v necessario all'injection stia dentro quello erogabile: e' continuo
	% e monotono, informativo anche in pieno infeasible, e diventa ATTIVO
	% all'ottimo (il payload sale finche' il margine va a zero).
	%
	% SCALA (scelta di progetto, dichiarata): la normalizzazione e' ue2 =
	% vacuum_thrust/mass_flow_rate dello stadio 2, una COSTANTE del veicolo --
	% non una grandezza che varia col candidato. Deve essere costante: dividere
	% per dv_available (che dipende da x) cambierebbe l'ordinamento fra
	% candidati, non solo la scala, rompendo l'invarianza monotona richiesta al
	% ranking (rif. CLAUDE.md S5.2). ue2 rende g adimensionale e di ordine 1,
	% cioe' confrontabile con la violazione delle uguaglianze normalizzata da
	% arch_rank.m (che divide per eps_eq): senza questo, un vincolo in m/s
	% (ordine 1e2-1e3) dominerebbe il ranking sulla violazione.
	%
	% FASE 8 NON RAGGIUNTA (crash, suborbitale, trigger di fase mancato):
	% il bilancio di delta-v non esiste. Si restituisce un valore positivo
	% grande, g_unreached: e' un GUESS DICHIARATO (rif. CLAUDE.md S7), scelto
	% sopra i valori plausibili del ramo continuo (dv mancante fino a ~2-3 ue2)
	% cosi' che una missione che non arriva nemmeno all'injection resti sempre
	% peggiore, in ranking, di una che ci arriva. Non e' una penalita' additiva
	% sull'obiettivo (vietata da CLAUDE.md S5.2): e' il valore del vincolo in
	% un caso in cui la fisica non lo definisce.
	g_unreached = 10;

	if ~isfield(other, 'INJ') || ~isfield(other.INJ, 'reached')
		error('eval_fgh:noINJ', ...
		      ['other.INJ assente: il bilancio di delta-v del burn di ' ...
		       'injection e'' prodotto da simulator.m (fase 8). Chiamare ' ...
		       'eval_fgh con la ''other'' restituita da simulator.m, non ' ...
		       'con quella di partenza.']);
	end

	ue2 = other.MOT(2).vacuum_thrust / other.MOT(2).mass_flow_rate;

	if ~other.INJ.reached || ~isfinite(other.INJ.dv_margin)
		g = g_unreached;
		return;
	end

	g = other.INJ.dv_margin / ue2;
end
