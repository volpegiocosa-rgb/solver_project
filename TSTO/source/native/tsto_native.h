/* tsto_native.h -- prototipi C per libtsto_native.so
 *
 * Libreria Fortran ISO_C_BINDING standalone (nessuna dipendenza da
 * Octave): eom_core.f90 compilato da solo con
 *   gfortran -shared -fPIC -o libtsto_native.so eom_core.f90
 * Riusabile da qualunque programma C/C++ (o altro linguaggio con FFI
 * verso ABI C: Python via ctypes, MATLAB via loadlibrary, ecc.),
 * linkando -ltsto_native. Vedi README.md per il comando di build e
 * test_standalone.c per un esempio d'uso completo senza Octave.
 *
 * Layout di 'scalars'/'s' (31 o 38 elementi) ed 'InOl' (3x3,
 * column-major): vedi il commento in testa a eom_core.f90 e
 * build_eom_native_params.m (lato Octave) per come costruirli da una
 * struct 'other' di TSTO.
 */
#ifndef TSTO_NATIVE_H
#define TSTO_NATIVE_H

#ifdef __cplusplus
extern "C" {
#endif

/* dy = eom(t, y, other) -- porting di eom.m + guidance.m (fasi 1-6). */
void eom_native_f(double t, const double y[8], const double s[31], const double InOl[9],
                   int n_env, const double env_alt[], const double env_rho[],
                   const double env_c[], const double env_p[],
                   int n_mach, int n_aoa, const double aer_mach[], const double aer_aoa[],
                   const double aer_cd[], double dy[8]);

/* [value, isterminal, direction] = phase_event(t, y, other, phase) --
 * porting di phase_event.m. val/isterminal/direction sono sempre
 * dimensionati 3 (il massimo); solo i primi *n_out elementi sono
 * validi (2 per le fasi 4/5, 3 per le altre). */
void phase_event_native_f(double t, const double y[8], const double s[38], const double InOl[9],
                           int phase, double val[3], double isterminal[3], double direction[3],
                           int *n_out);

/* Porting di simulator.m S3 (fasi 1-6) + rk5.m + kinematic_step.m:
 * integra dalla fine della fase 0 (y0/t0) fino al boundary fase6->7
 * (o a un arresto anticipato), SENZA accumulare la storia T/Y (solo
 * lo stato finale, coerente con config.minimal_output=true, l'unico
 * caso usato dall'ottimizzatore -- vedi header del sorgente Fortran).
 *
 * status in uscita: 0 = raggiunta fase 7 normalmente (il chiamante
 * deve proseguire con la fase 7-8, fuori da questa libreria); 1 =
 * END_CRASH; 2 = END_PROP2; 3 = errore interno/rete di sicurezza
 * (nessun evento entro tmax_phase, troppi passi RK5, o troppe
 * transizioni di fase -- non atteso in condizioni normali). */
void tsto_phases16_f(const double y0[8], double t0, const double s_base[38], const double InOl[9],
                      int n_env, const double env_alt[], const double env_rho[],
                      const double env_c[], const double env_p[],
                      int n_mach, int n_aoa, const double aer_mach[], const double aer_aoa[],
                      const double aer_cd[],
                      double tmin, double tmax, double tmax_phase, double frac, double tol_t,
                      int max_iter_evt,
                      double y_final[8], double *t_final, int *status);

#ifdef __cplusplus
}
#endif

#endif /* TSTO_NATIVE_H */
