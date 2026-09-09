% MAIN  Entry point per l'utente finale: ottimizzazione del payload del
%   lanciatore TSTO (due stadi, propulsione liquida, Falcon 9-like) con il
%   metodo di CONTINUAZIONE A STADI (release 2.0.0).
%
%   COSA FA
%   Massimizza la massa payload rispettando i vincoli di missione
%   (quota di perigeo, quota di apogeo, inclinazione) e il vincolo di
%   margine di delta-v del burn di injection. Il metodo alterna:
%     - stadi di ricerca CMA-ES+ARCH sulla guida (9 variabili) e sul payload;
%     - un PUSH del payload al proprio limite fisico a guida congelata,
%       via predittore in massa + bisezione (poche valutazioni);
%     - un RATCHET del bound inferiore del payload al livello certificato,
%       cosi' il segmento gia' esplorato non viene ri-cercato.
%
%   COME SI CONFIGURA
%   Tutti i controlli (numero di stadi, budget di valutazioni e iterazioni
%   per stadio, restart IPOP per stadio, passo iniziale, tolleranze del
%   predittore) sono opzioni di run_continuation. Vedere l'header di
%   real_case/run_continuation.m e il README per i preset misurati.
%
%   PREREQUISITI
%   - Octave (testato su 9.4.0). Per la velocita' massima compilare i
%     kernel Fortran nativi (~150-400x): vedi TSTO/source/native/README.md.
%     Senza compilarli funziona comunque, con fallback interpretato.
%   - Nient'altro: TSTO e' incluso in questo repository (cartella TSTO/).
%
%   STATO / RISULTATI MISURATI: vedere README.md.

here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, 'real_case'));

out = run_continuation();

fprintf('\n================ RISULTATO ================\n');
fprintf('Mpayload    = %.1f kg\n', out.Mpayload);
fprintf('feasible    = %d\n', out.feasible);
fprintf('valutazioni = %d\n', out.n_eval);
fprintf('Il punto certificato e'' salvato in real_case/warm_start.mat:\n');
fprintf('un nuovo lancio di main.m RIPARTE da qui e migliora, non ricomincia.\n');
