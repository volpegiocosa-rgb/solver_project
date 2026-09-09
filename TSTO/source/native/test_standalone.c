/* test_standalone.c -- prova che libtsto_native.so funziona SENZA
 * Octave: nessun header/libreria Octave qui, solo tsto_native.h + libc.
 *
 * Non e' un test di validazione fisica (quello e' fatto in Octave,
 * validate_tsto_native.m, confrontando contro le formule .m originali,
 * gia' verificate identiche in sessione): qui lo scopo e' solo
 * dimostrare che la libreria e' un artefatto standalone riutilizzabile
 * -- si compila, si linka e gira in un programma C puro.
 *
 * Build:
 *   gcc test_standalone.c -L. -ltsto_native -Wl,-rpath,'$ORIGIN' -o test_standalone
 * Run (senza Octave):
 *   ./test_standalone
 */
#include <stdio.h>
#include <math.h>
#include "tsto_native.h"

int main(void)
{
    /* Tabelle atmosfera/aero minime (sintetiche, non i CSV reali di
     * TSTO): bastano a dimostrare che l'interpolazione gira senza
     * errori, la correttezza fisica e' validata a parte in Octave. */
    const int n_env = 3;
    double env_alt[3] = {0.0, 50000.0, 100000.0};
    double env_rho[3] = {1.225, 1.0e-3, 5.5e-7};
    double env_c[3]   = {340.0, 300.0, 280.0};
    double env_p[3]   = {101325.0, 80.0, 0.032};

    const int n_mach = 2, n_aoa = 2;
    double aer_mach[2] = {0.0, 5.0};
    double aer_aoa[2]  = {0.0, 10.0};
    double aer_cd[4]   = {0.3, 0.35, 0.32, 0.40}; /* column-major [n_mach x n_aoa] */

    /* InOl=identita' (semplificazione): NON e' la vera rotazione
     * sito-di-lancio->inerziale (che dipenderebbe da lat/lon reali,
     * costruita da interface.m). Con pos sul pad all'equatore
     * (Req,0,0) la verticale locale vera e' +X, ma con InOl=identita'
     * il case 1 di guidance.m (uOl=[0;0;1]) punta la spinta lungo +Z
     * globale invece che lungo la verticale locale: il veicolo non
     * contrasta la gravita' radiale e l'evento "quota=0" scatta quasi
     * subito (status=1, END_CRASH, atteso qui). Ininfluente per lo
     * scopo di questo test (provare che la libreria linka/gira senza
     * Octave): la correttezza fisica vera e' validata a parte in
     * Octave con InOl reale (validate_tsto_native.m). */
    double InOl[9] = {1,0,0, 0,1,0, 0,0,1};

    /* scalars(38), stesso layout di build_eom_native_params.m
     * (indici 1-based nel commento Fortran -> 0-based qui). */
    double s[38];
    s[0]  = 3.986004418e14;   /* mu */
    s[1]  = 6378137.0;        /* Req */
    s[2]  = 1.0/298.257223563;/* f */
    s[3]  = 7.2921159e-5;     /* omega_E */
    s[4]  = 10.0;             /* Sref */
    s[5]  = 250.0;  s[6] = 9;   s[7] = 7.6e6; s[8] = 0.9;   /* MOT(1) */
    s[9]  = 27.0;   s[10] = 1;  s[11] = 9.34e5; s[12] = 1.3; /* MOT(2) */
    s[13] = 1.0;               /* active_stage */
    s[14] = 1.0;               /* isignite */
    s[15] = 1.0;               /* phase */
    s[16] = 1.5707963267949;   /* launch_azimuth (90 deg, est) */
    s[17] = 10.0;              /* pitch_over_starting */
    s[18] = -0.001; s[19] = 0.0; /* pitch(1),pitch(2) [rad/s^2] */
    s[20] = 0.0;  s[21] = 1.5707963267949; /* last_pitch, last_yaw */
    s[22] = 0.01;               /* pitch_rate_transition */
    s[23] = 30.0;                /* transition_starting */
    s[24] = 1.4;                 /* pitch_at_transition */
    s[25] = 200.0;                /* insertion_starting */
    s[26] = 0.0;                  /* AoA_rate */
    s[27] = 0.5; s[28] = 0.1; s[29] = 0.01; /* plane_controller kp,kd,ki */
    s[30] = 0.9;                  /* target_orbital_inclination */
    s[31] = 120.0;                 /* zkick */
    s[32] = 5000.0;                /* Minert1 */
    s[33] = 1000.0;                /* Minert2 */
    s[34] = 90000.0;               /* MProp2 */
    s[35] = 1700.0;                /* Mfairing */
    s[36] = 4000.0;                /* Mpayload */
    s[37] = 400000.0;              /* apogee_altitude_target */

    /* Stato iniziale: pad all'equatore (lon=lat=0), co-rotante con la
     * Terra + piccola velocita' verticale (rif. y0 "dopo fase 0"). */
    double pos_x = s[1];
    double vel_y = s[3] * pos_x;   /* omega_E x pos, componente Est */
    double y0[8] = { pos_x, 0.0, 0.0,
                      0.0, vel_y, 50.0,
                      5000.0 + 1000.0 + 400000.0 + 90000.0 + 1700.0 + 4000.0, /* mass0 */
                      0.0 };

    double dy[8];
    eom_native_f(0.0, y0, s /* solo i primi 31 letti */, InOl,
                 n_env, env_alt, env_rho, env_c, env_p,
                 n_mach, n_aoa, aer_mach, aer_aoa, aer_cd, dy);

    printf("eom_native_f: dy = [");
    for (int i = 0; i < 8; i++) printf(" %.6e", dy[i]);
    printf(" ]\n");

    double val[3], isterm[3], dirn[3];
    int n_out = 0;
    phase_event_native_f(0.0, y0, s, InOl, 1, val, isterm, dirn, &n_out);
    printf("phase_event_native_f (phase 1): n_out=%d val=[%.6e %.6e %.6e]\n",
           n_out, val[0], val[1], val[2]);

    double y_final[8], t_final;
    int status = -1;
    tsto_phases16_f(y0, 0.0, s, InOl,
                     n_env, env_alt, env_rho, env_c, env_p,
                     n_mach, n_aoa, aer_mach, aer_aoa, aer_cd,
                     0.05, 2.0, 1000.0, 0.05, 1.0e-6, 40,
                     y_final, &t_final, &status);

    printf("tsto_phases16_f: status=%d t_final=%.6f y_final = [", status, t_final);
    for (int i = 0; i < 8; i++) printf(" %.6e", y_final[i]);
    printf(" ]\n");

    printf("OK: libtsto_native.so linked and executed with no Octave involved.\n");
    return 0;
}
