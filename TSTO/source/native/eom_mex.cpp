// eom_mex.cpp -- shim MEX (MATLAB/Windows) per il kernel Fortran eom_core.f90.
//
// Equivalente MATLAB di eom_oct.cc (stesso kernel Fortran, stesso layout
// dati, stesso ordine di argomenti): l'unica differenza e' l'API di
// marshaling (mex.h/mxArray invece di octave/oct.h), perche' MATLAB e
// Octave usano interfacce oct-file/mex-file incompatibili tra loro pur
// condividendo lo stesso layout column-major dei dati (mxGetPr, come
// fortran_vec() lato Octave, restituisce il puntatore diretto, nessun
// riordino necessario). Nessuna logica fisica qui.
//
// Compilare SOLO su Windows con MATLAB (mex -setup C++ con un
// compilatore supportato: MinGW-w64 -- add-on gratuito MathWorks -- o
// MSVC), linkando tsto_native.dll tramite la import library generata
// da tsto_native.def. Vedi README.md (sezione Windows/MATLAB) per i
// comandi esatti. NON compilato/eseguito in questa sessione (nessun
// MATLAB disponibile sull'ambiente di sviluppo Linux): a differenza di
// tsto_native.dll (verificata funzionalmente sotto Wine, stesso output
// del path Octave/Linux bit-per-bit), questo shim resta sorgente non
// testata fino alla prima compilazione reale su Windows/MATLAB.
//
// Il nome del file compilato DEVE essere eom_native.mexw64: simulator.m
// rileva il fast-path con exist('eom_native','file')==3, che MATLAB
// restituisce per i file MEX esattamente come Octave per i file .oct
// -- nessuna modifica a simulator.m necessaria per questo shim.

#include "mex.h"
#include "tsto_native.h"

void mexFunction (int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{
  if (nrhs != 11)
    {
      mexErrMsgIdAndTxt ("tsto:eom_native:nargin",
        "eom_native: attesi 11 argomenti (t, y, scalars, InOl, env_alt, env_rho, env_c, env_p, aer_mach, aer_aoa, aer_cd)");
    }

  double t = mxGetScalar (prhs[0]);

  const mxArray *y_a        = prhs[1];
  const mxArray *scalars_a  = prhs[2];
  const mxArray *InOl_a     = prhs[3];
  const mxArray *env_alt_a  = prhs[4];
  const mxArray *env_rho_a  = prhs[5];
  const mxArray *env_c_a    = prhs[6];
  const mxArray *env_p_a    = prhs[7];
  const mxArray *aer_mach_a = prhs[8];
  const mxArray *aer_aoa_a  = prhs[9];
  const mxArray *aer_cd_a   = prhs[10];

  mwSize n_env  = mxGetNumberOfElements (env_alt_a);
  mwSize n_mach = mxGetNumberOfElements (aer_mach_a);
  mwSize n_aoa  = mxGetNumberOfElements (aer_aoa_a);

  if (mxGetNumberOfElements (y_a) != 8
      || mxGetNumberOfElements (scalars_a) < 31
      || mxGetM (InOl_a) != 3 || mxGetN (InOl_a) != 3)
    {
      mexErrMsgIdAndTxt ("tsto:eom_native:dims",
        "eom_native: dimensioni non valide su y (attesi 8), scalars (attesi >=31) o InOl (attesi 3x3)");
    }
  if (mxGetNumberOfElements (env_rho_a) != n_env
      || mxGetNumberOfElements (env_c_a) != n_env
      || mxGetNumberOfElements (env_p_a) != n_env)
    {
      mexErrMsgIdAndTxt ("tsto:eom_native:dims",
        "eom_native: env_rho/env_c/env_p devono avere la stessa lunghezza di env_alt");
    }
  if (mxGetM (aer_cd_a) != n_mach || mxGetN (aer_cd_a) != n_aoa)
    {
      mexErrMsgIdAndTxt ("tsto:eom_native:dims",
        "eom_native: aer_cd deve avere dimensione [n_mach x n_aoa]");
    }

  mxArray *dy_a = mxCreateDoubleMatrix (8, 1, mxREAL);

  eom_native_f (t, mxGetPr (y_a), mxGetPr (scalars_a), mxGetPr (InOl_a),
                static_cast<int> (n_env), mxGetPr (env_alt_a), mxGetPr (env_rho_a),
                mxGetPr (env_c_a), mxGetPr (env_p_a),
                static_cast<int> (n_mach), static_cast<int> (n_aoa),
                mxGetPr (aer_mach_a), mxGetPr (aer_aoa_a), mxGetPr (aer_cd_a),
                mxGetPr (dy_a));

  plhs[0] = dy_a;
}
