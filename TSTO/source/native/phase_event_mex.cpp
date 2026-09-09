// phase_event_mex.cpp -- shim MEX (MATLAB/Windows) per phase_event_native_f
// (eom_core.f90). Equivalente MATLAB di phase_event_oct.cc: vedi header
// di eom_mex.cpp per il razionale generale (API mex.h vs octave/oct.h,
// stesso kernel Fortran, stesso layout dati, non compilato/eseguito in
// questa sessione -- nessun MATLAB disponibile sull'ambiente Linux).
//
// Il nome del file compilato DEVE essere phase_event_native.mexw64
// (simulator.m: exist('phase_event_native','file')==3).

#include "mex.h"
#include "tsto_native.h"

void mexFunction (int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{
  if (nrhs != 5)
    {
      mexErrMsgIdAndTxt ("tsto:phase_event_native:nargin",
        "phase_event_native: attesi 5 argomenti (t, y, scalars, InOl, phase)");
    }

  double t = mxGetScalar (prhs[0]);
  const mxArray *y_a       = prhs[1];
  const mxArray *scalars_a = prhs[2];
  const mxArray *InOl_a    = prhs[3];
  int phase = static_cast<int> (mxGetScalar (prhs[4]));

  if (mxGetNumberOfElements (y_a) != 8
      || mxGetNumberOfElements (scalars_a) < 38
      || mxGetM (InOl_a) != 3 || mxGetN (InOl_a) != 3)
    {
      mexErrMsgIdAndTxt ("tsto:phase_event_native:dims",
        "phase_event_native: dimensioni non valide su y (attesi 8), scalars (attesi >=38) o InOl (attesi 3x3)");
    }

  double val[3] = {0.0, 0.0, 0.0};
  double isterminal[3] = {0.0, 0.0, 0.0};
  double direction[3] = {0.0, 0.0, 0.0};
  int n_out = 0;

  phase_event_native_f (t, mxGetPr (y_a), mxGetPr (scalars_a), mxGetPr (InOl_a),
                         phase, val, isterminal, direction, &n_out);

  if (n_out <= 0 || n_out > 3)
    {
      mexErrMsgIdAndTxt ("tsto:phase_event_native:phase",
        "phase_event_native: fase non valida o n_out inatteso (%d)", n_out);
    }

  mxArray *V_a  = mxCreateDoubleMatrix (n_out, 1, mxREAL);
  mxArray *IT_a = mxCreateDoubleMatrix (n_out, 1, mxREAL);
  mxArray *D_a  = mxCreateDoubleMatrix (n_out, 1, mxREAL);

  double *V  = mxGetPr (V_a);
  double *IT = mxGetPr (IT_a);
  double *D  = mxGetPr (D_a);
  for (int i = 0; i < n_out; i++)
    {
      V[i]  = val[i];
      IT[i] = isterminal[i];
      D[i]  = direction[i];
    }

  plhs[0] = V_a;
  if (nlhs > 1) plhs[1] = IT_a;
  if (nlhs > 2) plhs[2] = D_a;
}
