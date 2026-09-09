# native/ — libreria Fortran standalone per la simulazione TSTO

Porting Fortran ISO_C_BINDING di `eom.m`+`guidance.m` (fasi 1-6),
`phase_event.m`, e (sessione "TSTO libreria standalone", rif.
`solver_project/CLAUDE.md` §11 Fase 5) dell'intera orchestrazione
attorno ad essi: il loop RK5 (`rk5.m`), il controllo del passo
cinematico (`kinematic_step.m`) e la macchina a stati delle fasi 1-6
(`simulator.m` §3). La fase 7-8 (`injection_target_orbit.m`, meccanica
orbitale closed-form, costo O(1) per valutazione) resta in Octave,
invariata, per decisione utente.

**Architettura in due livelli** (richiesta esplicita utente: una vera
libreria standalone, non solo codice Fortran annegato dentro un
binario Octave-specifico):

1. **`libtsto_native.so`** — libreria condivisa STANDALONE, compilata
   da `eom_core.f90` da solo, **nessuna dipendenza da Octave**.
   Riusabile da qualunque programma C/C++ o altro linguaggio con FFI
   verso ABI C (Python `ctypes`, MATLAB `loadlibrary`, ecc.).
2. **Shim `.oct`** (`eom_oct.cc`, `phase_event_oct.cc`,
   `tsto_phases16_oct.cc`) — consumatori SOTTILI che linkano
   dinamicamente `libtsto_native.so`: nessuna logica, solo marshaling
   Octave↔ABI-C.

Misurato in sessione: 412.9x su `eom.m`/`guidance.m`, 44.9x su
`phase_event.m` (sessioni precedenti); **~2.7-4.75x aggiuntivo**
end-to-end su `traj_cost.m` dopo il porting di RK5/eventi/macchina a
stati (30 campioni random-in-bounds, stesso seed, stessa sessione:
mean 39.9ms→8.4ms, mediana 19.9ms→7.3ms, max 126ms→28.9ms); un run
CMA-ES reale completo (`real_case/run_real_case.m`, seed=1,
max_eval=12000) e' sceso a **110s totali (~9.1ms/eval medio)**.

## File

- `eom_core.f90` — **unico sorgente Fortran**. Contiene `eom_native_f`,
  `phase_event_native_f` (kernel fisici, fasi 1-6 + eventi) e
  `tsto_phases16_f` (orchestrazione: RK5 + localizzazione eventi +
  macchina a stati fasi 1-6), tutti `bind(C)`.
- `tsto_native.h` — header C con i prototipi `extern "C"` delle tre
  funzioni sopra: include questo file per usare la libreria da un
  programma C/C++ puro (vedi `test_standalone.c`).
- `test_standalone.c` — programma C dimostrativo, **nessuna dipendenza
  da Octave**: linka `libtsto_native.so` e chiama le tre funzioni su
  uno stato sintetico. Prova concreta (non solo dichiarata) che la
  libreria e' riusabile fuori da Octave.
- `eom_oct.cc`, `phase_event_oct.cc`, `tsto_phases16_oct.cc` — shim
  oct-file (marshaling Octave↔ABI-C, nessuna logica fisica).
- `libtsto_native.so`, `eom_native.oct`, `phase_event_native.oct`,
  `tsto_phases16_native.oct`, `test_standalone` — **compilati, NON
  versionati** (vedi `.gitignore`): vanno ricostruiti dopo ogni clone.
- `validate_tsto_native.m` — validazione persistente (confronta il
  fast-path nativo `tsto_phases16_native` contro il path interpretato
  su una batteria di casi; vedi intestazione del file per il metodo).
- `tsto_native.def` — tabella di export (sorgente, TRACCIATO) per
  generare la import library Windows a partire da `tsto_native.dll`;
  vedi sezione "Windows / MATLAB" sotto.
- `eom_mex.cpp`, `phase_event_mex.cpp`, `tsto_phases16_mex.cpp` — shim
  MEX (sorgenti, TRACCIATI): equivalenti MATLAB di `eom_oct.cc` /
  `phase_event_oct.cc` / `tsto_phases16_oct.cc` (stesso kernel Fortran,
  stesso layout dati/argomenti, API `mex.h` invece di `octave/oct.h`).
  Da compilare SU Windows con `mex` — vedi sezione "Windows / MATLAB".
- `tsto_native.dll`, `libtsto_native.dll.a`, `*.mexw64`,
  `test_standalone_win.exe` — **compilati, NON versionati** (analoghi
  Windows dei file Linux sopra): vanno ricostruiti dopo ogni clone.

## Build

Richiede il toolchain di sviluppo Octave (pacchetto Debian/Ubuntu
`octave-dev`, fornisce `mkoctfile`), un compilatore Fortran (`gfortran`)
e un compilatore C (`gcc`, solo per `test_standalone.c`).

```bash
sudo apt install octave-dev gfortran gcc   # se non gia' presenti
cd source/native

# 1) libreria Fortran standalone (nessuna dipendenza Octave)
gfortran -shared -fPIC -o libtsto_native.so eom_core.f90

# 2) shim Octave, linkati dinamicamente alla libreria standalone
#    (rpath assoluto: mkoctfile non propaga $ORIGIN in modo affidabile
#    al linker interno, verificato in sessione -- usare il pwd assoluto
#    e' comunque corretto perche' i .oct vanno RICOSTRUITI ad ogni
#    clone, rif. sopra: il path e' sempre quello del checkout corrente)
NATIVE_DIR=$(pwd)
mkoctfile eom_oct.cc            -L. -ltsto_native -Wl,-rpath,"$NATIVE_DIR" -o eom_native.oct
mkoctfile phase_event_oct.cc    -L. -ltsto_native -Wl,-rpath,"$NATIVE_DIR" -o phase_event_native.oct
mkoctfile tsto_phases16_oct.cc  -L. -ltsto_native -Wl,-rpath,"$NATIVE_DIR" -o tsto_phases16_native.oct

# 3) (opzionale) prova standalone, SENZA Octave
gcc test_standalone.c -L. -ltsto_native -Wl,-rpath,"$NATIVE_DIR" -lm -o test_standalone
./test_standalone

# 4) validazione numerica (native vs interpretato)
octave --no-gui -qf --eval "run('validate_tsto_native.m')"
```

## Windows / MATLAB

Stesso sorgente Fortran unico (`eom_core.f90`), stessa architettura in
due livelli, ma **due tappe separate** perche' vanno fatte su due
macchine diverse:

**Tappa A — build della DLL (fatta e verificata in questa sessione,
su Linux, con il cross-compilatore MinGW-w64: nessuna macchina Windows
necessaria per QUESTA tappa).**

```bash
sudo apt install gcc-mingw-w64-x86-64 gfortran-mingw-w64-x86-64   # se non gia' presenti
cd source/native

# 1) DLL standalone, linkata staticamente (nessuna dipendenza dal
#    runtime MinGW sulla macchina di destinazione -- verificato con
#    objdump -p: solo KERNEL32.dll/msvcrt.dll, sempre presenti)
x86_64-w64-mingw32-gfortran -shared -O2 \
  -static -static-libgfortran -static-libgcc \
  -Wl,--export-all-symbols \
  -o tsto_native.dll eom_core.f90

# 2) import library MinGW dalla tabella di export tracciata
#    (necessaria per linkare la DLL da un compilatore Windows: una DLL
#    da sola non basta al linker, serve un file con i nomi dei simboli)
x86_64-w64-mingw32-dlltool -d tsto_native.def -D tsto_native.dll -l libtsto_native.dll.a

# 3) (opzionale) prova standalone via Wine, SENZA MATLAB.
#    ATTENZIONE al nome ambiguo: nella stessa cartella convive anche
#    libtsto_native.so (tappa Linux sopra) -- linkare con -ltsto_native
#    risolve sull'.so sbagliato (matchato prima del .dll.a), serve il
#    path esplicito alla import library:
x86_64-w64-mingw32-gcc -O2 test_standalone.c ./libtsto_native.dll.a \
  -static -static-libgcc -o test_standalone_win.exe
wine test_standalone_win.exe
```

Se serve la `.lib` in formato MSVC invece della `.dll.a` MinGW
(compilatore `mex -setup C++` impostato su Visual Studio), generarla
SU Windows dallo stesso `tsto_native.def` con lo strumento MSVC:
```
lib /def:tsto_native.def /machine:x64 /out:tsto_native.lib
```

**Verificato in questa sessione** (Linux, `x86_64-w64-mingw32-gfortran`
14.2.0, nessun errore ne' warning): `tsto_native.dll` e' un PE32+ valido
(`file`: "PE32+ executable for MS Windows... DLL, x86-64"), esporta
esattamente `eom_native_f`/`phase_event_native_f`/`tsto_phases16_f`
(`objdump -p`, tabella export) e dipende solo da `KERNEL32.dll`/
`msvcrt.dll`. **Eseguita davvero sotto Wine** (non solo ispezionata
staticamente), linkando `test_standalone.c` contro la DLL: output
**identico bit-per-bit** alla stessa prova su `libtsto_native.so` sotto
Linux nativo (stessi valori di `dy`, `val` dell'evento, `y_final`/
`t_final`/`status`) -- prova concreta che il porting Fortran e' corretto
anche cross-compilato per Windows, non solo dichiarato.

**Tappa B — shim MEX (da fare SU Windows, con MATLAB: NON eseguita in
questa sessione, nessun MATLAB disponibile sull'ambiente di sviluppo
Linux).** Copiare su Windows `tsto_native.dll`, `libtsto_native.dll.a`
(o `tsto_native.lib` per MSVC), `tsto_native.h` e i tre `*_mex.cpp`,
poi (una volta sola, se non gia' fatto): `mex -setup C++` (MinGW-w64 —
add-on gratuito MathWorks — o Visual Studio). Compilare:
```matlab
mex eom_mex.cpp libtsto_native.dll.a -output eom_native
mex phase_event_mex.cpp libtsto_native.dll.a -output phase_event_native
mex tsto_phases16_mex.cpp libtsto_native.dll.a -output tsto_phases16_native
```
(sostituire `libtsto_native.dll.a` con `tsto_native.lib` se si usa
MSVC). Il nome d'uscita **deve** essere esattamente `eom_native` /
`phase_event_native` / `tsto_phases16_native` (produce `eom_native.
mexw64` ecc.): `simulator.m` li rileva con `exist(nome,'file')==3`,
lo stesso meccanismo gia' usato per i file `.oct` su Octave/Linux —
**nessuna modifica a `simulator.m` necessaria**, ne' qui ne' altrove.
Mettere i tre `.mexw64` risultanti sul path MATLAB accanto a
`simulator.m` (o in `source/native/`, gia' sul path se il progetto
aggiunge `source/**`).

**Aggiornamento — MATLAB e' risultato installato su questa stessa
macchina Linux** (`/usr/local/MATLAB/R2025a`, non noto prima di questa
sessione), anche se **con licenza non attivata**
(`matlab -batch` fallisce con "MathWorks Licensing Error 8" — questione
di licenza dell'utente, non affrontata ne' aggirata qui). Lo strumento
`mex` pero' **funziona indipendentemente dalla licenza** (non passa dal
motore MATLAB con licenza per la sola compilazione): i tre shim sono
stati **compilati per davvero** con l'`mex.h` reale di MathWorks, non
scritti alla cieca:
```bash
mex eom_mex.cpp -L. -ltsto_native \
    LDFLAGS='$LDFLAGS -Wl,-rpath,<NATIVE_DIR>' -output eom_native
# idem per phase_event_mex.cpp, tsto_phases16_mex.cpp
```
**Risultato**: `MEX completed successfully` sui tre file (nessun errore
di compilazione/linking contro l'API `mex.h` reale — su questa macchina
produce `.mexa64`, l'estensione Linux, ma il sorgente C++ e' identico
byte per byte a quello che produrrebbe `.mexw64` su Windows: nessun
codice platform-specific nei tre `*_mex.cpp`). Verificato anche, senza
eseguire MATLAB (bloccato dalla licenza): `file` conferma un vero ELF
shared object; `nm -D` mostra `mexFunction` correttamente esportato;
`ldd` risolve `libtsto_native.so` (le altre due dipendenze non risolte,
`libmx.so`/`libmex.so`, sono normali fuori da un processo MATLAB: sono
caricate dinamicamente da MATLAB stesso a runtime, non tramite il
resolver standard). **Resta non verificata solo l'esecuzione dentro
MATLAB** (chiamata reale delle tre funzioni e confronto con l'output
Octave, stesso metodo di `validate_tsto_native.m`), bloccata dalla
licenza non attivata — non una questione di correttezza del codice.
Da fare la prima volta con una licenza MATLAB valida (Linux o Windows,
indifferente: il sorgente e' lo stesso).

## Fallback automatico

`simulator.m` verifica `exist('tsto_phases16_native','file')==3`
(fasi 1-6 in un'unica chiamata nativa) prima di `exist('eom_native',
'file')==3`/`exist('phase_event_native','file')==3` (kernel fisici
soli, orchestrazione ancora Octave) prima di ricadere sulle funzioni
Octave interpretate (`eom.m`, `guidance.m`, `phase_event.m`,
`rk5.m`) — tre livelli, sempre corretto, via via piu' lento se un
livello di build manca. Il fast-path piu' veloce
(`tsto_phases16_native`) si attiva SOLO con `config.minimal_output=true`
(l'unico caso usato dall'ottimizzatore, che non ha bisogno della
storia T/Y completa). Se manca, `simulator.m` stampa un **avviso una
tantum per sessione Octave** (non ad ogni valutazione) invece di
ricadere in silenzio sul path piu' lento (rif. `real_case/
diagnostic_plan.md`: gia' successo una volta di non accorgersene).
