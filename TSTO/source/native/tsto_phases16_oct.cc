// tsto_phases16_oct.cc -- shim oct-file per tsto_phases16_f (eom_core.f90):
// porting Fortran di simulator.m S3 (fasi 1-6) + rk5.m + kinematic_step.m.
//
// Nessuna logica di simulazione qui: solo marshaling Octave<->Fortran,
// stesso pattern di eom_oct.cc/phase_event_oct.cc. Vedi il commento in
// testa a tsto_phases16_f (eom_core.f90) per il layout di 's_base'
// (38 elementi, IDENTICO a build_eom_native_params.m) e la semantica
// di 'status' in uscita.

#include <octave/oct.h>

extern "C" {
  void tsto_phases16_f (const double *y0, double t0, const double *s_base, const double *InOl,
                         int n_env, const double *env_alt, const double *env_rho,
                         const double *env_c, const double *env_p,
                         int n_mach, int n_aoa, const double *aer_mach, const double *aer_aoa,
                         const double *aer_cd,
                         double tmin, double tmax, double tmax_phase, double frac, double tol_t,
                         int max_iter_evt,
                         double *y_final, double *t_final, int *status);
}

DEFUN_DLD (tsto_phases16_native, args, ,
           "[y_final, t_final, status] = tsto_phases16_native(y0, t0, scalars, InOl, \\\n\
    env_alt, env_rho, env_c, env_p, aer_mach, aer_aoa, aer_cd, \\\n\
    tmin, tmax, tmax_phase, frac, tol_t, max_iter_evt)\n\
Shim oct-file per il kernel Fortran tsto_phases16_f (porting di\n\
simulator.m S3 fasi 1-6 + rk5.m + kinematic_step.m). status: 0 = raggiunta\n\
fase 7 (il chiamante Octave prosegue con injection_target_orbit.m), 1 =\n\
END_CRASH, 2 = END_PROP2, 3 = errore interno/rete di sicurezza.")
{
  octave_value_list retval;

  if (args.length () != 17)
    {
      error ("tsto_phases16_native: attesi 17 argomenti (y0, t0, scalars, InOl, "
             "env_alt, env_rho, env_c, env_p, aer_mach, aer_aoa, aer_cd, "
             "tmin, tmax, tmax_phase, frac, tol_t, max_iter_evt)");
      return retval;
    }

  ColumnVector y0       = args(0).column_vector_value ();
  double t0              = args(1).double_value ();
  ColumnVector scalars   = args(2).column_vector_value ();
  Matrix InOl             = args(3).matrix_value ();
  ColumnVector env_alt   = args(4).column_vector_value ();
  ColumnVector env_rho   = args(5).column_vector_value ();
  ColumnVector env_c     = args(6).column_vector_value ();
  ColumnVector env_p     = args(7).column_vector_value ();
  ColumnVector aer_mach  = args(8).column_vector_value ();
  ColumnVector aer_aoa   = args(9).column_vector_value ();
  Matrix aer_cd           = args(10).matrix_value ();
  double tmin             = args(11).double_value ();
  double tmax             = args(12).double_value ();
  double tmax_phase       = args(13).double_value ();
  double frac             = args(14).double_value ();
  double tol_t            = args(15).double_value ();
  int max_iter_evt        = static_cast<int> (args(16).double_value ());

  if (y0.numel () != 8 || scalars.numel () < 38
      || InOl.rows () != 3 || InOl.cols () != 3)
    {
      error ("tsto_phases16_native: dimensioni non valide su y0 (attesi 8), "
             "scalars (attesi >=38) o InOl (attesi 3x3)");
      return retval;
    }

  octave_idx_type n_env  = env_alt.numel ();
  octave_idx_type n_mach = aer_mach.numel ();
  octave_idx_type n_aoa  = aer_aoa.numel ();

  if (env_rho.numel () != n_env || env_c.numel () != n_env || env_p.numel () != n_env)
    {
      error ("tsto_phases16_native: env_rho/env_c/env_p devono avere la stessa lunghezza di env_alt");
      return retval;
    }
  if (aer_cd.rows () != n_mach || aer_cd.cols () != n_aoa)
    {
      error ("tsto_phases16_native: aer_cd deve avere dimensione [n_mach x n_aoa]");
      return retval;
    }

  ColumnVector y_final (8);
  double t_final = 0.0;
  int status = -1;

  tsto_phases16_f (y0.fortran_vec (), t0, scalars.fortran_vec (), InOl.fortran_vec (),
                    static_cast<int> (n_env), env_alt.fortran_vec (), env_rho.fortran_vec (),
                    env_c.fortran_vec (), env_p.fortran_vec (),
                    static_cast<int> (n_mach), static_cast<int> (n_aoa),
                    aer_mach.fortran_vec (), aer_aoa.fortran_vec (), aer_cd.fortran_vec (),
                    tmin, tmax, tmax_phase, frac, tol_t, max_iter_evt,
                    y_final.fortran_vec (), &t_final, &status);

  retval(0) = y_final;
  retval(1) = t_final;
  retval(2) = static_cast<double> (status);
  return retval;
}
