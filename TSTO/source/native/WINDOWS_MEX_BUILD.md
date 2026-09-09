# Come compilare i MEX Windows/MATLAB (`.mexw64`)

Guida operativa per completare **su una macchina Windows con MATLAB installato**
la parte che non può essere fatta in ambiente Linux di sviluppo (nessun MATLAB
disponibile lì). Rif. `README.md` di questa cartella, sezione "Windows / MATLAB",
e `solver_project/CLAUDE.md` §11 Fase 5.

## Stato attuale (cosa è già fatto, cosa manca)

| Cosa | Stato |
|------|-------|
| `eom_core.f90` (kernel Fortran, unico sorgente) | ✅ fatto, invariato |
| `tsto_native.dll` (DLL Windows, cross-compilata da Linux con MinGW-w64) | ✅ fatto e verificato sotto Wine |
| `eom_mex.cpp`, `phase_event_mex.cpp`, `tsto_phases16_mex.cpp` (sorgenti shim MEX) | ✅ scritti, compilati e verificati con `mex.h` reale (versione `.mexa64` Linux) |
| `eom_native.mexw64`, `phase_event_native.mexw64`, `tsto_phases16_native.mexw64` | ❌ **DA FARE** — richiedono `mex` reale su Windows |
| Esecuzione reale dentro MATLAB (chiamata delle funzioni, confronto con `validate_tsto_native.m`) | ❌ **DA FARE** — mai testato dentro un processo MATLAB vero |

In breve: il codice sorgente e la DLL sono pronti e verificati quanto possibile
senza Windows. Manca solo l'ultimo passo di compilazione + verifica, che
**deve** girare su Windows perché `mex` (compilatore MATLAB) non è disponibile
sull'ambiente Linux di sviluppo.

## Prerequisiti su Windows

- MATLAB installato, con licenza attiva.
- Un compilatore C++ configurato per `mex`: la prima volta lanciare
  ```matlab
  mex -setup C++
  ```
  e scegliere **MinGW-w64** (add-on gratuito MathWorks, consigliato — coerente
  con la DLL già cross-compilata con MinGW) oppure Visual Studio (richiede la
  `.lib` MSVC, vedi nota sotto).

## File da portare su Windows

Dalla release GitHub `v2.1.0` (asset `tsto_native_windows_v2.1.0.zip`):
- `tsto_native.dll`
- `libtsto_native.dll.a` (import library MinGW)

Dal repository clonato (già tracciati in git, nessun download extra):
- `tsto_native.h`
- `eom_mex.cpp`, `phase_event_mex.cpp`, `tsto_phases16_mex.cpp`

Metti tutti e cinque i file nella stessa cartella (es. `TSTO/source/native/`
del checkout Windows, sovrascrivendo/aggiungendo i due della release).

## Compilazione

Da MATLAB, con la cartella sopra come working directory:

```matlab
mex eom_mex.cpp libtsto_native.dll.a -output eom_native
mex phase_event_mex.cpp libtsto_native.dll.a -output phase_event_native
mex tsto_phases16_mex.cpp libtsto_native.dll.a -output tsto_phases16_native
```

Il nome d'uscita **deve** essere esattamente `eom_native` / `phase_event_native`
/ `tsto_phases16_native` (senza questo, `simulator.m` non li rileva —
usa `exist(nome,'file')==3`, lo stesso meccanismo già in uso per i `.oct`
su Octave/Linux; nessuna modifica a `simulator.m` necessaria).

Se preferisci Visual Studio invece di MinGW-w64, serve prima generare la
`.lib` in formato MSVC dalla tabella di export già tracciata (`tsto_native.def`,
nel repository), **su Windows**:
```
lib /def:tsto_native.def /machine:x64 /out:tsto_native.lib
```
e poi sostituire `libtsto_native.dll.a` con `tsto_native.lib` nei tre comandi
`mex` sopra.

## Verifica

Output atteso: `MEX completed successfully` per ciascuno dei tre comandi,
senza errori né warning di linking.

Poi, per verificare che il risultato sia numericamente corretto (non solo che
compili), lancia da MATLAB, nella stessa cartella:
```matlab
run('validate_tsto_native.m')
```
Confronta il fast-path nativo (`tsto_phases16_native`, appena compilato)
contro il path interpretato (`eom.m`/`guidance.m`/`phase_event.m`/`rk5.m`) su
una batteria di casi — nominali, casuali entro i bound, ai bordi del dominio,
e il caso patologico noto (`pitch_rate_transition=0`). Attesa: stessa
tolleranza relativa già verificata su Linux (`.oct`/`.mexa64`), differenze
nell'ordine del rumore di floating-point (worst case osservato 2.9e-13 su
Linux, tolleranza dello script 1e-6).

## Dove mettere i `.mexw64` finali

Sul path MATLAB, accanto a `simulator.m` — cioè in `TSTO/source/native/`
stesso (già sul path se il progetto aggiunge `source/**`). Non vanno
committati in git (compilati, non versionati — stesso principio di `.oct`/
`.so`/`.dll`, vedi `TSTO/.gitignore`).
