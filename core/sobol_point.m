function xn = sobol_point(n, idx)
% SOBOL_POINT  Restituisce il punto di indice idx (>=0) della sequenza di Sobol
%   in [0,1]^n, in ordine Gray-code (rif. CLAUDE.md S5.1, S10 nota di porting).
%
%   Implementazione self-contained: nessuna dipendenza da pacchetti opzionali
%   (rif. CLAUDE.md S2, "non su percorsi critici" — l'init di xmean senza
%   opts.x0 e' il path di default). Decisione concordata con l'utente in
%   Fase 0/1: porting diretto dei numeri di direzione, non del pacchetto
%   octave-forge 'statistics' (che fornirebbe sobolset ma introdurrebbe una
%   dipendenza esterna su un percorso critico).
%
%   FONTE (porting, rif. CLAUDE.md S10 nota di porting — citare la fonte nel
%   codice, rischio di licenza accettato dall'utente in Fase 0):
%     Algoritmo: F. Y. Kuo, sobol.cc (Gray-code direct-XOR construction),
%       https://web.maths.unsw.edu.au/~fkuo/sobol/
%     Numeri di direzione: S. Joe, F. Y. Kuo, "Constructing Sobol sequences
%       with better two-dimensional projections", SIAM J. Sci. Comput. 30
%       (2008) 2635-2654. File 'new-joe-kuo-6.21201', dimensioni d=2..40.
%     Licenza: BSD (Copyright 2008, Frances Y. Kuo e Stephen Joe). Redistribuzione
%       e uso consentiti; acknowledgment del copyright riportato qui come richiesto.
%
%   LIMITE DICHIARATO: tabella imbarcata copre SOLO n<=40 (39 dimensioni non
%   banali + 1 banale). Per n>40 servirebbe una tabella piu' estesa: errore
%   esplicito, non fallback silenzioso (rif. CLAUDE.md S7).
%
%   NOTA (guess dichiarato): idx=0 e idx=1 sono degeneri per costruzione
%   (danno rispettivamente il punto [0,...,0] e [0.5,...,0.5] in OGNI
%   dimensione, perche' il primo numero di direzione m_1 vale sempre 1 in
%   tutte le dimensioni tabulate). Chi chiama questa funzione per scegliere
%   un punto "non banale" deve usare idx>=2 (rif. init_mean.m, ipop_restart.m).
%
%   INPUT  : n   dimensione (1<=n<=40)
%            idx indice non-negativo nella sequenza (intero)
%   OUTPUT : xn  vettore colonna n x 1 in [0,1]

    if n < 1 || n > 40 || n ~= fix(n)
        error('sobol_point:dimCap', ...
            ['sobol_point supporta 1<=n<=40 (tabella Joe-Kuo imbarcata, ' ...
             'rif. CLAUDE.md S5.1/S10). n=%d non supportato: fermarsi e ' ...
             'chiedere prima di estendere la tabella.'], n);
    end
    if idx < 0 || idx ~= fix(idx)
        error('sobol_point:badIdx', 'idx deve essere un intero non negativo.');
    end

    if idx == 0
        xn = zeros(n, 1);
        return
    end

    L = floor(log2(idx)) + 1;
    g = bitxor(uint32(idx), bitshift(uint32(idx), -1));
    bitpos = find(bitget(double(g), 1:L));

    xn = zeros(n, 1);
    for j = 1:n
        V = sobol_direction_numbers(j, L);
        acc = uint32(0);
        for b = bitpos
            acc = bitxor(acc, V(b));
        end
        xn(j) = double(acc) / 2^32;
    end
end

function V = sobol_direction_numbers(j, L)
% Numeri di direzione V(1..L) (uint32, scalati su 32 bit) per la dimensione j
% (1-indicizzata: j=1 e' la dimensione banale di van der Corput in base 2,
% j=2..40 usa la riga d=j della tabella Joe-Kuo). Porting diretto della
% ricorrenza in sobol.cc (rif. header del file).
    if j == 1
        V = zeros(1, L, 'uint32');
        for i = 1:L
            V(i) = bitshift(uint32(1), 32 - i);
        end
        return
    end

    tbl = sobol_joe_kuo_table();
    row = tbl(j - 1);
    s = row.s;
    a = row.a;
    m = row.m;

    V = zeros(1, L, 'uint32');
    if L <= s
        for i = 1:L
            V(i) = bitshift(uint32(m(i)), 32 - i);
        end
    else
        for i = 1:s
            V(i) = bitshift(uint32(m(i)), 32 - i);
        end
        for i = (s + 1):L
            V(i) = bitxor(V(i - s), bitshift(V(i - s), -s));
            for k = 1:(s - 1)
                bit_k = bitand(bitshift(uint32(a), -(s - 1 - k)), uint32(1));
                if bit_k
                    V(i) = bitxor(V(i), V(i - k));
                end
            end
        end
    end
end

function tbl = sobol_joe_kuo_table()
% Tabella numeri di direzione Joe-Kuo (set 'new-joe-kuo-6.21201'), dimensioni
% d=2..40 (39 righe). Colonne originali: d, s (grado polinomio primitivo),
% a (coefficienti codificati), m_1..m_s (numeri di direzione iniziali).
% Fonte: https://web.maths.unsw.edu.au/~fkuo/sobol/ (licenza BSD, S. Joe e
% F. Y. Kuo, 2008). Trascritta 1:1 dal file scaricato, riga per riga.
    raw = { ...
        1,  0,  [1]; ...                          % d=2
        2,  1,  [1 3]; ...                        % d=3
        3,  1,  [1 3 1]; ...                       % d=4
        3,  2,  [1 1 1]; ...                       % d=5
        4,  1,  [1 1 3 3]; ...                     % d=6
        4,  4,  [1 3 5 13]; ...                    % d=7
        5,  2,  [1 1 5 5 17]; ...                  % d=8
        5,  4,  [1 1 5 5 5]; ...                   % d=9
        5,  7,  [1 1 7 11 19]; ...                 % d=10
        5,  11, [1 1 5 1 1]; ...                   % d=11
        5,  13, [1 1 1 3 11]; ...                  % d=12
        5,  14, [1 3 5 5 31]; ...                  % d=13
        6,  1,  [1 3 3 9 7 49]; ...                % d=14
        6,  13, [1 1 1 15 21 21]; ...              % d=15
        6,  16, [1 3 1 13 27 49]; ...              % d=16
        6,  19, [1 1 1 15 7 5]; ...                % d=17
        6,  22, [1 3 1 15 13 25]; ...              % d=18
        6,  25, [1 1 5 5 19 61]; ...               % d=19
        7,  1,  [1 3 7 11 23 15 103]; ...          % d=20
        7,  4,  [1 3 7 13 13 15 69]; ...           % d=21
        7,  7,  [1 1 3 13 7 35 63]; ...            % d=22
        7,  8,  [1 3 5 9 1 25 53]; ...             % d=23
        7,  14, [1 3 1 13 9 35 107]; ...           % d=24
        7,  19, [1 3 1 5 27 61 31]; ...            % d=25
        7,  21, [1 1 5 11 19 41 61]; ...           % d=26
        7,  28, [1 3 5 3 3 13 69]; ...             % d=27
        7,  31, [1 1 7 13 1 19 1]; ...             % d=28
        7,  32, [1 3 7 5 13 19 59]; ...            % d=29
        7,  37, [1 1 3 9 25 29 41]; ...            % d=30
        7,  41, [1 3 5 13 23 1 55]; ...            % d=31
        7,  42, [1 3 7 3 13 59 17]; ...            % d=32
        7,  50, [1 3 1 3 5 53 69]; ...             % d=33
        7,  55, [1 1 5 5 23 33 13]; ...            % d=34
        7,  56, [1 1 7 7 1 61 123]; ...            % d=35
        7,  59, [1 1 7 9 13 61 49]; ...            % d=36
        7,  62, [1 3 3 5 3 55 33]; ...             % d=37
        8,  14, [1 3 1 15 31 13 49 245]; ...       % d=38
        8,  21, [1 3 5 15 31 59 63 97]; ...        % d=39
        8,  22, [1 3 1 11 11 11 77 249] ...        % d=40
    };
    tbl = struct('s', raw(:, 1), 'a', raw(:, 2), 'm', raw(:, 3));
end
