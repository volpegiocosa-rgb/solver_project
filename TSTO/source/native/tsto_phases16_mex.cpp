// tsto_phases16_mex.cpp -- shim MEX (MATLAB/Windows) per tsto_phases16_f
// (eom_core.f90): porting Fortran di simulator.m S3 (fasi 1-6) + rk5.m +
// kinematic_step.m. Equivalente MATLAB di tsto_phases16_oct.cc: vedi
// header di eom_mex.cpp per il razionale generale (API mex.h vs
// octave/oct.h, stesso kernel Fortran, stesso layout dati, non
// compilato/eseguito in questa sessione -- nessun MATLAB disponibile
// sull'ambiente Linux).
//
// Il nome del file compilato DEVE essere tsto_phases16_native.mexw64
// (simulator.m: exist('tsto_phases16_native','file')==3, il fast-path
// piu' veloce, attivo solo con config.minimal_output=true).

#include "mex.h"
#include "tsto_native.h"

void mexFunction (int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{
  if (nrhs != 17)
    {
      mexErrMsgIdAndTxt ("tsto:tsto_phases16_native:nargin",
        "tsto_phases16_native: attesi 17 argomenti (y0, t0, scalars, InOl, "
        "env_alt, env_rho, env_c, env_p, aer_mach, aer_aoa, aer_cd, "
        "tmin, tmax, tmax_phase, frac, tol_t, max_iter_evt)");
    }

  const mxArray *y0_a       = prhs[0];
  double t0                 = mxGetScalar (prhs[1]);
  const mxArray *scalars_a  = prhs[2];
  const mxArray *InOl_a     = prhs[3];
  const mxArray *env_alt_a  = prhs[4];
  const mxArray *env_rho_a  = prhs[5];
  const mxArray *env_c_a    = prhs[6];
  const mxArray *env_p_a    = prhs[7];
  const mxArray *aer_mach_a = prhs[8];
  const mxArray *aer_aoa_a  = prhs[9];
  const mxArray *aer_cd_a   = prhs[10];
  double tmin                = mxGetScalar (prhs[11]);
  double tmax                = mxGetScalar (prhs[12]);
  double tmax_phase          = mxGetScalar (prhs[13]);
  double frac                = mxGetScalar (prhs[14]);
  double tol_t               = mxGetScalar (prhs[15]);
  int max_iter_evt           = static_cast<int> (mxGetScalar (prhs[16]));

  mwSize n_env  = mxGetNumberOfElements (env_alt_a);
  mwSize n_mach = mxGetNumberOfElements (aer_mach_a);
  mwSize n_aoa  = mxGetNumberOfElements (aer_aoa_a);

  if (mxGetNumberOfElements (y0_a) != 8
      || mxGetNumberOfElements (scalars_a) < 38
      || mxGetM (InOl_a) != 3 || mxGetN (InOl_a) != 3)
    {
      mexErrMsgIdAndTxt ("tsto:tsto_phases16_native:dims",
        "tsto_phases16_native: dimensioni non valide su y0 (attesi 8), "
        "scalars (attesi >=38) o InOl (attesi 3x3)");
    }
  if (mxGetNumberOfElements (env_rho_a) != n_env
      || mxGetNumberOfElements (env_c_a) != n_env
      || mxGetNumberOfElements (env_p_a) != n_env)
    {
      mexErrMsgIdAndTxt ("tsto:tsto_phases16_native:dims",
        "tsto_phases16_native: env_rho/env_c/env_p devono avere la stessa lunghezza di env_alt");
    }
  if (mxGetM (aer_cd_a) != n_mach || mxGetN (aer_cd_a) != n_aoa)
    {
      mexErrMsgIdAndTxt ("tsto:tsto_phases16_native:dims",
        "tsto_phases16_native: aer_cd deve avere dimensione [n_mach x n_aoa]");
    }

  mxArray *y_final_a = mxCreateDoubleMatrix (8, 1, mxREAL);
  double t_final = 0.0;
  int status = -1;

  tsto_phases16_f (mxGetPr (y0_a), t0, mxGetPr (scalars_a), mxGetPr (InOl_a),
                    static_cast<int> (n_env), mxGetPr (env_alt_a), mxGetPr (env_rho_a),
                    mxGetPr (env_c_a), mxGetPr (env_p_a),
                    static_cast<int> (n_mach), static_cast<int> (n_aoa),
                    mxGetPr (aer_mach_a), mxGetPr (aer_aoa_a), mxGetPr (aer_cd_a),
                    tmin, tmax, tmax_phase, frac, tol_t, max_iter_evt,
                    mxGetPr (y_final_a), &t_final, &status);

  plhs[0] = y_final_a;
  if (nlhs > 1) plhs[1] = mxCreateDoubleScalar (t_final);
  if (nlhs > 2) plhs[2] = mxCreateDoubleScalar (static_cast<double> (status));
}
