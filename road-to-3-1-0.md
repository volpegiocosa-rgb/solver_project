# Creare un toolbox informale per uso su Matlab in ambiente Windwows

## Obiettivo
- creare una function di interfaccia che peremetta di includere la versione 3.0.0 in un programma più grande

## Contenuto ed esclusioni del toolbox
- Package sintetico con solo il necessario (no test, documentazione, validazione)
- includere file `.mex` necessari
- `helper-giano.md` riporta tutte le istruzioni che l'utente finale deve seguire per utilizzarlo

## Firma del toolbox
- la funzione di interfaccia è `giano.m`

### Input
- ogni file `.csv` è una *struct* passata in argomento

### Ouput
- quanto previsto in `/TSTO/interface_specification.md` in output
- diagnostica del processo di simulazione in `opt_log`

## Regole generali
- no leggere da file
- no scrivere su file

## Plan
- fornisci un piano di sviluppo
- ogni punto è un *gate* che necessita mia approvazione
- il plan deve includere anche la validazione
- il plan deve essere strutturato da non sperecare *token* (ottimizzazione risorse)

## Output della task
- release 3.1.0 con asset che abbia un file `.zip` con 
-- `giano.m` in v 1.0.0
-- subfunction
-- `helper-giano.md` 
-- altro materiale che ritieni opportuno

## Macchina target
- Windows 10 - Matlab 2026b

**chiedi informazioni per contraddizioni o mancanze**

