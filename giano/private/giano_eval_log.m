function out = giano_eval_log(action, record)
% GIANO_EVAL_LOG  Accumulatore in memoria delle valutazioni di
%   giano_traj_cost.m (rif. giano-design.md H6: sostituisce
%   real_case/traj_cost.m che scriveva su real_case/eval_log.csv --
%   qui NESSUNA scrittura su file, solo un array in memoria).
%
%   Stesso pattern stateful di real_case/traj_cost.m (persistent
%   log_fid/n_eval_global), qui applicato a un cell array invece che a un
%   file descriptor. Interfaccia a "macchina a stati" con tre azioni:
%     'reset'  azzera l'accumulatore (DA CHIAMARE a inizio di ogni run di
%              giano(), altrimenti si sommerebbero valutazioni di run
%              diversi nella stessa sessione Matlab)
%     'append' aggiunge un record (struct), assegna un eval_id progressivo
%     'get'    restituisce il cell array accumulato finora (per costruire
%              out.opt_log a fine ottimizzazione)
%
%   LIMITE DICHIARATO (coerente con CLAUDE.md S2 "Parallelizzazione
%   VIETATA", nessuna chiamata concorrente prevista in questo progetto):
%   lo stato e' un persistent a livello di sessione Matlab, quindi
%   giano() NON e' rientrante -- una chiamata a giano() deve completare
%   (reset -> append* -> get) prima che ne inizi un'altra nella stessa
%   sessione. Non un problema per l'uso previsto (una chiamata alla
%   volta, coerente col resto del progetto), ma dichiarato esplicitamente
%   invece di lasciarlo implicito.
%
%   INPUT  : action   'reset' | 'append' | 'get'
%            record   (solo per 'append') struct da accodare
%   OUTPUT : out       []                  per 'reset'
%                      eval_id (scalare)   per 'append'
%                      cell array          per 'get'

    persistent log_cell n_calls

    switch action
        case 'reset'
            log_cell = {};
            n_calls  = 0;
            out = [];
        case 'append'
            n_calls = n_calls + 1;
            record.eval_id = n_calls;
            log_cell{end + 1} = record;
            out = n_calls;
        case 'get'
            out = log_cell;
        otherwise
            error('giano:badEvalLogAction', ...
                'giano_eval_log: azione ''%s'' non riconosciuta (reset|append|get).', action);
    end

end
