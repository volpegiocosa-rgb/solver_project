! eom_core.f90 -- porting Fortran del blocco derivata di stato TSTO
! (eom.m + guidance.m casi 1-6 + funzioni ausiliarie chiamate).
!
! Motivazione (rif. solver_project/CLAUDE.md S11 Fase 5, sessione
! "requisito 5 minuti"): eom.m/guidance.m sono chiamate 7 volte per punto
! RK5 accettato (k1..k6 di rk5.m + 1 di kinematic_step.m); misurato in
! sessione: ~5.7 ms/chiamata su Octave interpretato, per un contenuto di
! calcolo minimo -- costo quasi certamente dominato dall'overhead
! dell'interprete (dispatch di funzione, accesso a struct annidate), non
! da lavoro numerico reale. Questo file replica ESATTAMENTE le formule
! della sorgente Octave (stesso ordine di operazioni, stesse clamp) per
! eliminare quell'overhead.
!
! Scope: SOLO le fasi 1-6 (le uniche integrate da rk5.m -- le fasi 7-8
! sono istantanee, mai chiamate nel loop ODE, CLAUDE.md TSTO S5).
! phase_event.m NON e' ancora portato (chiamato 1 volta per punto
! accettato, non 7 come eom.m: priorita' minore, da riconsiderare solo se
! resta un collo di bottiglia dopo aver misurato lo speedup di questo file).
!
! Layout del vettore scalars(31) (costruito una volta per fase da
! build_eom_native_params.m, NON ad ogni chiamata):
!   1  mu                       17 launch_azimuth
!   2  Req (wgs84(1))           18 pitch_over_starting
!   3  f   (wgs84(2))           19 pitch(1)  [pitch_c1]
!   4  omega_E                  20 pitch(2)  [pitch_c2]
!   5  Sref                     21 last_pitch
!   6  mass_flow_rate stadio1   22 last_yaw
!   7  number_of_ignite_engine1 23 pitch_rate_transition
!   8  vacuum_thrust stadio1    24 transition_starting
!   9  nozzle_exit_area stadio1 25 pitch_at_transition
!   10 mass_flow_rate stadio2   26 insertion_starting
!   11 number_of_ignite_engine2 27 AoA_rate
!   12 vacuum_thrust stadio2    28 plane_controller(1) kp
!   13 nozzle_exit_area stadio2 29 plane_controller(2) kd
!   14 active_stage (1|2)       30 plane_controller(3) ki
!   15 isignite (0|1)           31 target_orbital_inclination
!   16 phase (1..6)
!
! Tabelle ENV (env_alt/env_rho/env_c/env_p, lunghezza n_env, ordinate
! crescenti -- verificato issorted() in sessione) e AER (aer_mach/aer_aoa
! crescenti, aer_cd(n_mach,n_aoa): righe=Mach, colonne=AoA, layout
! column-major nativo Octave == column-major nativo Fortran, passate
! dallo shim C++ con Matrix::fortran_vec(), nessun riordino necessario).

module eom_core_mod
  use, intrinsic :: iso_c_binding
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private
  public :: eom_native_f
  public :: phase_event_native_f
  public :: tsto_phases16_f

  real(c_double), parameter :: PI_  = 3.14159265358979323846d0
  real(c_double), parameter :: HALFPI_ = 1.57079632679489661923d0

contains

  pure function norm3(v) result(n)
    real(c_double), intent(in) :: v(3)
    real(c_double) :: n
    n = sqrt(v(1)*v(1) + v(2)*v(2) + v(3)*v(3))
  end function norm3

  pure function vers3(v) result(u)
    real(c_double), intent(in) :: v(3)
    real(c_double) :: u(3), n
    n = norm3(v)
    if (n > 1.0d-12) then
      u = v / n
    else
      u = 0.0d0
    end if
  end function vers3

  pure function cross3(a, b) result(c)
    real(c_double), intent(in) :: a(3), b(3)
    real(c_double) :: c(3)
    c(1) = a(2)*b(3) - a(3)*b(2)
    c(2) = a(3)*b(1) - a(1)*b(3)
    c(3) = a(1)*b(2) - a(2)*b(1)
  end function cross3

  pure function dot3(a, b) result(d)
    real(c_double), intent(in) :: a(3), b(3)
    real(c_double) :: d
    d = a(1)*b(1) + a(2)*b(2) + a(3)*b(3)
  end function dot3

  pure function matvec3(M, v) result(r)
    real(c_double), intent(in) :: M(3,3), v(3)
    real(c_double) :: r(3)
    r = matmul(M, v)
  end function matvec3

  pure function mattvec3(M, v) result(r)
    real(c_double), intent(in) :: M(3,3), v(3)
    real(c_double) :: r(3)
    r = matmul(transpose(M), v)
  end function mattvec3

  pure function setOl_f(pitch, yaw) result(u)
    real(c_double), intent(in) :: pitch, yaw
    real(c_double) :: u(3)
    u(1) = cos(pitch) * sin(yaw)
    u(2) = cos(pitch) * cos(yaw)
    u(3) = sin(pitch)
  end function setOl_f

  subroutine vect2angleOl_f(uOl, pitch, yaw)
    real(c_double), intent(in)  :: uOl(3)
    real(c_double), intent(out) :: pitch, yaw
    real(c_double) :: z
    z = min(1.0d0, max(-1.0d0, uOl(3)))
    pitch = asin(z)
    yaw   = atan2(uOl(1), uOl(2))
  end subroutine vect2angleOl_f

  subroutine eval_aero_angle_f(relative_speed, pos, u_ref, incidence, sideslip)
    real(c_double), intent(in)  :: relative_speed(3), pos(3), u_ref(3)
    real(c_double), intent(out) :: incidence, sideslip
    real(c_double) :: x_hat(3), z_hat(3), y_hat(3), u1, u2, u3
    x_hat = vers3(relative_speed)
    z_hat = vers3(cross3(pos, relative_speed))
    y_hat = cross3(z_hat, x_hat)
    u1 = dot3(x_hat, u_ref)
    u2 = dot3(y_hat, u_ref)
    u3 = dot3(z_hat, u_ref)
    incidence = atan2(u2, u1)
    sideslip  = atan2(u3, u1)
  end subroutine eval_aero_angle_f

  pure function eval_AoA_f(u, relative_speed) result(AoA)
    real(c_double), intent(in) :: u(3), relative_speed(3)
    real(c_double) :: AoA, vr, cosAoA
    vr = norm3(relative_speed)
    if (vr > 1.0d-3) then
      cosAoA = dot3(u, relative_speed) / vr
      cosAoA = min(1.0d0, max(-1.0d0, cosAoA))
      AoA = acos(cosAoA)
    else
      AoA = 0.0d0
    end if
  end function eval_AoA_f

  pure function eval_relative_speed_f(pos, vel, omega_E) result(rs)
    real(c_double), intent(in) :: pos(3), vel(3), omega_E
    real(c_double) :: rs(3), omega_vec(3)
    omega_vec = (/ 0.0d0, 0.0d0, omega_E /)
    rs = vel - cross3(omega_vec, pos)
  end function eval_relative_speed_f

  pure function cart2geo_alt(pos, Req, f) result(alt)
    real(c_double), intent(in) :: pos(3), Req, f
    real(c_double) :: alt
    real(c_double) :: e2, x, y, z, p, lat, lat_new, sinlat, N
    integer :: iter
    e2 = f * (2.0d0 - f)
    x = pos(1); y = pos(2); z = pos(3)
    p = sqrt(x*x + y*y)
    if (p < 1.0d-9) then
      alt = abs(z) - Req * sqrt(1.0d0 - e2)
      return
    end if
    lat = atan2(z, p*(1.0d0 - e2))
    do iter = 1, 10
      sinlat = sin(lat)
      N   = Req / sqrt(1.0d0 - e2*sinlat*sinlat)
      alt = p/cos(lat) - N
      lat_new = atan2(z, p*(1.0d0 - e2*N/(N+alt)))
      if (abs(lat_new - lat) < 1.0d-12) then
        lat = lat_new
        exit
      end if
      lat = lat_new
    end do
    sinlat = sin(lat)
    N   = Req / sqrt(1.0d0 - e2*sinlat*sinlat)
    alt = p/cos(lat) - N
  end function cart2geo_alt

  pure function interp1_lin(x, y, n, xq) result(yq)
    integer(c_int), intent(in) :: n
    real(c_double), intent(in) :: x(n), y(n), xq
    real(c_double) :: yq, t
    integer :: i
    if (n == 1) then
      yq = y(1)
      return
    end if
    i = n - 1
    do i = 1, n-1
      if (xq <= x(i+1)) exit
    end do
    if (i > n-1) i = n-1
    t = (xq - x(i)) / (x(i+1) - x(i))
    yq = y(i) + t*(y(i+1) - y(i))
  end function interp1_lin

  pure function interp2_lin(aoa, mach, cd, n_mach, n_aoa, aoaq, machq) result(cdq)
    integer(c_int), intent(in) :: n_mach, n_aoa
    real(c_double), intent(in) :: aoa(n_aoa), mach(n_mach), cd(n_mach, n_aoa)
    real(c_double), intent(in) :: aoaq, machq
    real(c_double) :: cdq
    integer :: ix, iy
    real(c_double) :: tx, ty, z00, z01, z10, z11

    if (n_aoa == 1) then
      ix = 1; tx = 0.0d0
    else
      do ix = 1, n_aoa-1
        if (aoaq <= aoa(ix+1)) exit
      end do
      if (ix > n_aoa-1) ix = n_aoa-1
      tx = (aoaq - aoa(ix)) / (aoa(ix+1) - aoa(ix))
    end if

    if (n_mach == 1) then
      iy = 1; ty = 0.0d0
    else
      do iy = 1, n_mach-1
        if (machq <= mach(iy+1)) exit
      end do
      if (iy > n_mach-1) iy = n_mach-1
      ty = (machq - mach(iy)) / (mach(iy+1) - mach(iy))
    end if

    z00 = cd(iy,   ix)
    z01 = cd(iy,   ix+1)
    z10 = cd(iy+1, ix)
    z11 = cd(iy+1, ix+1)

    cdq = (1.0d0-ty)*((1.0d0-tx)*z00 + tx*z01) + ty*((1.0d0-tx)*z10 + tx*z11)
  end function interp2_lin

  subroutine guidance_native(s, InOl, t, pos, vel, relative_speed, phase, uIn)
    real(c_double), intent(in)  :: s(31), InOl(3,3), t, pos(3), vel(3), relative_speed(3)
    integer(c_int), intent(in)  :: phase
    real(c_double), intent(out) :: uIn(3)

    real(c_double) :: uOl(3), dt, pitch, yaw, pitch_rate, incidence, sideslip
    real(c_double) :: u_ref(3), uOl_rel(3), rel_ol(3), pitch_rel, yaw_rel
    real(c_double) :: h(3), nh, actual_incl, err, yaw_corr, AoA_cmd

    select case (phase)
    case (1)
      uOl = (/ 0.0d0, 0.0d0, 1.0d0 /)
      uIn = matvec3(InOl, uOl)

    case (2)
      dt    = t - s(18)
      pitch = HALFPI_ + s(19)*dt*dt + s(20)*dt
      yaw   = s(17)
      uOl   = setOl_f(pitch, yaw)
      uIn   = matvec3(InOl, uOl)

    case (3)
      u_ref = matvec3(InOl, setOl_f(s(21), s(22)))
      call eval_aero_angle_f(relative_speed, pos, u_ref, incidence, sideslip)
      if (incidence > 0.0d0) then
        pitch_rate = -s(23)
      else if (incidence < 0.0d0) then
        pitch_rate = s(23)
      else
        pitch_rate = 0.0d0
      end if
      dt    = t - s(24)
      pitch = pitch_rate*dt + s(25)
      yaw   = s(17)
      uOl   = setOl_f(pitch, yaw)
      uIn   = matvec3(InOl, uOl)

    case (4, 5)
      rel_ol  = mattvec3(InOl, relative_speed)
      uOl_rel = vers3(rel_ol)
      call vect2angleOl_f(uOl_rel, pitch, yaw)
      yaw = s(17)
      uOl = setOl_f(pitch, yaw)
      uIn = matvec3(InOl, uOl)

    case (6)
      rel_ol  = mattvec3(InOl, relative_speed)
      uOl_rel = vers3(rel_ol)
      call vect2angleOl_f(uOl_rel, pitch_rel, yaw_rel)

      h  = cross3(pos, vel)
      nh = norm3(h)
      if (nh > 1.0d-9) then
        actual_incl = acos(min(1.0d0, max(-1.0d0, h(3)/nh)))
      else
        actual_incl = 0.0d0
      end if
      err      = s(31) - actual_incl
      yaw_corr = (s(28) + s(29) + s(30)) * err
      yaw      = yaw_rel + yaw_corr

      dt      = t - s(26)
      AoA_cmd = s(27) * dt
      pitch   = pitch_rel + AoA_cmd

      uOl = setOl_f(pitch, yaw)
      uIn = matvec3(InOl, uOl)

    case default
      uIn = 0.0d0
    end select
  end subroutine guidance_native

  subroutine eom_native_f(t, y, s, InOl, n_env, env_alt, env_rho, env_c, env_p, &
                           n_mach, n_aoa, aer_mach, aer_aoa, aer_cd, dy) &
                           bind(C, name="eom_native_f")
    real(c_double), intent(in), value :: t
    real(c_double), intent(in) :: y(8)
    real(c_double), intent(in) :: s(31)
    real(c_double), intent(in) :: InOl(3,3)
    integer(c_int), intent(in), value :: n_env
    real(c_double), intent(in) :: env_alt(n_env), env_rho(n_env), env_c(n_env), env_p(n_env)
    integer(c_int), intent(in), value :: n_mach, n_aoa
    real(c_double), intent(in) :: aer_mach(n_mach), aer_aoa(n_aoa)
    real(c_double), intent(in) :: aer_cd(n_mach, n_aoa)
    real(c_double), intent(out) :: dy(8)

    real(c_double) :: mu, Req, f, omega_E, Sref
    real(c_double) :: mfr(2), nie(2), vt(2), nea(2)
    integer :: active_stage, phase, st
    logical :: isignite
    real(c_double) :: pos(3), vel(3), mass
    real(c_double) :: rm, g(3)
    real(c_double) :: alt, alt_q, rho, sound_speed, p_amb
    real(c_double) :: relative_speed(3), vrel, Mach
    real(c_double) :: uIn(3), AoA
    real(c_double) :: Cd, Mach_q, AoA_q, AoA_deg
    real(c_double) :: Drag(3), rv(3), qdyn
    real(c_double) :: mass_flow_rate, thrust, vacuum_thrust
    real(c_double) :: vectorized_thrust(3), not_grav(3)

    mu = s(1); Req = s(2); f = s(3); omega_E = s(4); Sref = s(5)
    mfr(1) = s(6);  nie(1) = s(7);  vt(1) = s(8);  nea(1) = s(9)
    mfr(2) = s(10); nie(2) = s(11); vt(2) = s(12); nea(2) = s(13)
    active_stage = nint(s(14))
    isignite     = (s(15) /= 0.0d0)
    phase        = nint(s(16))

    pos  = y(1:3)
    vel  = y(4:6)
    mass = y(7)

    rm = norm3(pos)
    g  = -mu/rm**3 * pos

    alt   = cart2geo_alt(pos, Req, f)
    alt_q = min(max(alt, env_alt(1)), env_alt(n_env))
    rho         = interp1_lin(env_alt, env_rho, n_env, alt_q)
    sound_speed = interp1_lin(env_alt, env_c,   n_env, alt_q)
    p_amb       = interp1_lin(env_alt, env_p,   n_env, alt_q)

    relative_speed = eval_relative_speed_f(pos, vel, omega_E)
    vrel = norm3(relative_speed)
    Mach = vrel / sound_speed

    call guidance_native(s, InOl, t, pos, vel, relative_speed, phase, uIn)
    AoA = eval_AoA_f(uIn, relative_speed)

    if (active_stage == 1) then
      Mach_q  = min(max(Mach, aer_mach(1)), aer_mach(n_mach))
      AoA_deg = AoA * 180.0d0 / PI_
      AoA_q   = min(max(AoA_deg, aer_aoa(1)), aer_aoa(n_aoa))
      Cd = interp2_lin(aer_aoa, aer_mach, aer_cd, n_mach, n_aoa, AoA_q, Mach_q)
    else
      Cd = 0.0d0
    end if

    if (vrel > 0.1d0) then
      rv   = vers3(relative_speed)
      qdyn = 0.5d0 * rho * Cd * Sref * vrel*vrel
      Drag = qdyn * rv
    else
      Drag = 0.0d0
    end if

    st = active_stage
    mass_flow_rate = 0.0d0
    thrust         = 0.0d0
    if (isignite) then
      mass_flow_rate = mfr(st) * nie(st)
      vacuum_thrust  = vt(st) * nie(st)
      thrust         = vacuum_thrust - p_amb * nea(st) * nie(st)
    end if

    vectorized_thrust = thrust * uIn
    not_grav = vectorized_thrust/mass - Drag/mass

    dy(1:3) = vel
    dy(4:6) = not_grav + g
    dy(7)   = -mass_flow_rate
    dy(8)   = norm3(not_grav)
  end subroutine eom_native_f

  pure function eval_apogee_altitude_f(pos, vel, mu, Req) result(apogee_altitude)
    ! Porting di eval_apogee_altitude.m (quota di apogeo osculante,
    ! approssimazione sferica -- usata da phase_event.m case 6).
    real(c_double), intent(in) :: pos(3), vel(3), mu, Req
    real(c_double) :: apogee_altitude
    real(c_double) :: r, v, energy, a, h(3), e_vec(3), e, apogee_radius
    r = norm3(pos)
    v = norm3(vel)
    energy = v*v/2.0d0 - mu/r
    a = -mu / (2.0d0*energy)
    h = cross3(pos, vel)
    e_vec = cross3(vel, h)/mu - pos/r
    e = norm3(e_vec)
    apogee_radius = a * (1.0d0 + e)
    apogee_altitude = apogee_radius - Req
  end function eval_apogee_altitude_f

  subroutine phase_event_native_f(t, y, s, InOl, phase, val, isterminal, direction, n_out) &
                                   bind(C, name="phase_event_native_f")
    ! Porting di phase_event.m. Layout di 's': vedi build_eom_native_params.m
    ! (1-31 condivisi con eom_native_f, 32-38 aggiunti qui). val/isterminal/
    ! direction sono sempre dimensionati 3 (il massimo, fasi 1/2/3/6): per
    ! le fasi 4/5 (2 componenti) solo i primi n_out elementi sono validi --
    ! lo shim oct-file tronca a n_out prima di restituire a Octave, stessa
    ! semantica a lunghezza variabile dell'originale.
    real(c_double), intent(in), value :: t
    real(c_double), intent(in) :: y(8)
    real(c_double), intent(in) :: s(38)
    real(c_double), intent(in) :: InOl(3,3)
    integer(c_int), intent(in), value :: phase
    real(c_double), intent(out) :: val(3)
    real(c_double), intent(out) :: isterminal(3)
    real(c_double), intent(out) :: direction(3)
    integer(c_int), intent(out) :: n_out

    real(c_double) :: pos(3), vel(3), mass
    real(c_double) :: mu, Req, f, omega_E
    real(c_double) :: last_pitch, last_yaw, transition_starting, insertion_starting
    real(c_double) :: zkick, Minert1, Minert2, MProp2, Mfairing, Mpayload, apogee_target
    real(c_double) :: altitude, altitude_zero_ev
    real(c_double) :: dead_mass_stage1, dead_mass_stage2
    real(c_double) :: relative_speed(3), u_ref(3), incidence, sideslip
    real(c_double) :: apogee_altitude

    mu = s(1); Req = s(2); f = s(3); omega_E = s(4)
    last_pitch = s(21); last_yaw = s(22)
    transition_starting = s(24)
    insertion_starting  = s(26)
    zkick    = s(32)
    Minert1  = s(33)
    Minert2  = s(34)
    MProp2   = s(35)
    Mfairing = s(36)
    Mpayload = s(37)
    apogee_target = s(38)

    pos  = y(1:3)
    vel  = y(4:6)
    mass = y(7)

    altitude = cart2geo_alt(pos, Req, f)
    altitude_zero_ev = altitude

    dead_mass_stage1 = Minert1 + Minert2 + MProp2 + Mfairing + Mpayload
    dead_mass_stage2 = Minert2 + Mpayload

    val = 0.0d0; isterminal = 0.0d0; direction = 0.0d0

    select case (phase)
    case (1)
      val(1) = altitude - zkick
      val(2) = altitude_zero_ev
      val(3) = mass - dead_mass_stage1
      isterminal(1:3) = 1.0d0
      direction = (/ 1.0d0, -1.0d0, -1.0d0 /)
      n_out = 3

    case (2)
      val(1) = t - transition_starting
      val(2) = altitude_zero_ev
      val(3) = mass - dead_mass_stage1
      isterminal(1:3) = 1.0d0
      direction = (/ 1.0d0, -1.0d0, -1.0d0 /)
      n_out = 3

    case (3)
      relative_speed = eval_relative_speed_f(pos, vel, omega_E)
      u_ref = matvec3(InOl, setOl_f(last_pitch, last_yaw))
      call eval_aero_angle_f(relative_speed, pos, u_ref, incidence, sideslip)
      val(1) = incidence
      val(2) = altitude_zero_ev
      val(3) = mass - dead_mass_stage1
      isterminal(1:3) = 1.0d0
      direction = (/ 0.0d0, -1.0d0, -1.0d0 /)
      n_out = 3

    case (4)
      val(1) = mass - dead_mass_stage1
      val(2) = altitude_zero_ev
      isterminal(1:2) = 1.0d0
      direction(1) = -1.0d0
      direction(2) = -1.0d0
      n_out = 2

    case (5)
      val(1) = t - insertion_starting
      val(2) = altitude_zero_ev
      isterminal(1:2) = 1.0d0
      direction(1) = 1.0d0
      direction(2) = -1.0d0
      n_out = 2

    case (6)
      apogee_altitude = eval_apogee_altitude_f(pos, vel, mu, Req)
      val(1) = apogee_altitude - apogee_target
      val(2) = altitude_zero_ev
      val(3) = mass - dead_mass_stage2
      isterminal(1:3) = 1.0d0
      direction = (/ 1.0d0, -1.0d0, -1.0d0 /)
      n_out = 3

    case default
      n_out = 0
    end select
  end subroutine phase_event_native_f

  subroutine rk5_step_native(t, y, h, s, InOl, n_env, env_alt, env_rho, env_c, env_p, &
       n_mach, n_aoa, aer_mach, aer_aoa, aer_cd, y_next)
    ! Un singolo passo RK5 (stadi di Butcher, righe 175-182 di rk5.m),
    ! usando eom_native_f come 'f'. Fattorizzata perche' richiamata sia
    ! dal loop principale sia dalla localizzazione eventi (sotto-passi).
    real(c_double), intent(in) :: t, y(8), h
    real(c_double), intent(in) :: s(38), InOl(3,3)
    integer(c_int), intent(in) :: n_env, n_mach, n_aoa
    real(c_double), intent(in) :: env_alt(n_env), env_rho(n_env), env_c(n_env), env_p(n_env)
    real(c_double), intent(in) :: aer_mach(n_mach), aer_aoa(n_aoa), aer_cd(n_mach, n_aoa)
    real(c_double), intent(out) :: y_next(8)

    real(c_double) :: k1(8), k2(8), k3(8), k4(8), k5(8), k6(8), dy(8)

    call eom_native_f(t, y, s(1:31), InOl, n_env, env_alt, env_rho, env_c, env_p, &
         n_mach, n_aoa, aer_mach, aer_aoa, aer_cd, dy)
    k1 = h * dy

    call eom_native_f(t + 0.25d0*h, y + 0.25d0*k1, s(1:31), InOl, n_env, env_alt, env_rho, env_c, env_p, &
         n_mach, n_aoa, aer_mach, aer_aoa, aer_cd, dy)
    k2 = h * dy

    call eom_native_f(t + 0.25d0*h, y + 0.125d0*k1 + 0.125d0*k2, s(1:31), InOl, n_env, env_alt, env_rho, env_c, env_p, &
         n_mach, n_aoa, aer_mach, aer_aoa, aer_cd, dy)
    k3 = h * dy

    call eom_native_f(t + 0.5d0*h, y - 0.5d0*k2 + k3, s(1:31), InOl, n_env, env_alt, env_rho, env_c, env_p, &
         n_mach, n_aoa, aer_mach, aer_aoa, aer_cd, dy)
    k4 = h * dy

    call eom_native_f(t + 0.75d0*h, y + 0.1875d0*k1 + 0.5625d0*k4, s(1:31), InOl, n_env, env_alt, env_rho, env_c, env_p, &
         n_mach, n_aoa, aer_mach, aer_aoa, aer_cd, dy)
    k5 = h * dy

    call eom_native_f(t + h, y - (3.0d0/7.0d0)*k1 + (2.0d0/7.0d0)*k2 + (12.0d0/7.0d0)*k3 &
         - (12.0d0/7.0d0)*k4 + (8.0d0/7.0d0)*k5, s(1:31), InOl, n_env, env_alt, env_rho, env_c, env_p, &
         n_mach, n_aoa, aer_mach, aer_aoa, aer_cd, dy)
    k6 = h * dy

    y_next = y + (7.0d0*k1 + 32.0d0*k3 + 12.0d0*k4 + 32.0d0*k5 + 7.0d0*k6) / 90.0d0
  end subroutine rk5_step_native

  subroutine localize_event_native(tn, yn, h, s, InOl, &
       n_env, env_alt, env_rho, env_c, env_p, n_mach, n_aoa, aer_mach, aer_aoa, aer_cd, &
       idx, val_lo, val_hi, y_hi, tol_t, max_iter, t_evt, y_evt)
    ! Porting di localize_event (rk5.m righe 186-269): secante
    ! safeguarded (Illinois) sul bracket [tn, tn+h], ogni tentativo
    ! valutato ri-integrando un sotto-passo RK5 da (tn,yn) -- non
    ! interpolando linearmente (rif. commento nel corpo di rk5.m sul
    ! perche': errore di posizione altrimenti dell'ordine della corda,
    ! misurato 1613 m su validation_test_2, stesso ordine della
    ! tolleranza di missione).
    real(c_double), intent(in) :: tn, yn(8), h
    real(c_double), intent(in) :: s(38), InOl(3,3)
    integer(c_int), intent(in) :: n_env, n_mach, n_aoa
    real(c_double), intent(in) :: env_alt(n_env), env_rho(n_env), env_c(n_env), env_p(n_env)
    real(c_double), intent(in) :: aer_mach(n_mach), aer_aoa(n_aoa), aer_cd(n_mach, n_aoa)
    integer(c_int), intent(in) :: idx
    real(c_double), intent(in) :: val_lo, val_hi, y_hi(8), tol_t
    integer(c_int), intent(in) :: max_iter
    real(c_double), intent(out) :: t_evt, y_evt(8)

    real(c_double) :: a, b, fa, fb, y_b(8), s_best, y_best(8), y_s(8)
    real(c_double) :: ss, margin, fs
    real(c_double) :: val(3), isterm(3), dirn(3)
    integer(c_int) :: n_out, it

    a = 0.0d0; fa = val_lo
    b = h;     fb = val_hi
    y_b = y_hi

    if (abs(fa) <= abs(fb)) then
      s_best = a; y_best = yn
    else
      s_best = b; y_best = y_b
    end if

    do it = 1, max_iter
      if ((b - a) <= tol_t) exit

      if (fb /= fa) then
        ss = a + (b - a) * fa / (fa - fb)
      else
        ss = 0.5d0 * (a + b)
      end if
      margin = 0.01d0 * (b - a)
      if ((.not. ieee_is_finite(ss)) .or. ss <= a + margin .or. ss >= b - margin) then
        ss = 0.5d0 * (a + b)
      end if

      call rk5_step_native(tn, yn, ss, s, InOl, n_env, env_alt, env_rho, env_c, env_p, &
           n_mach, n_aoa, aer_mach, aer_aoa, aer_cd, y_s)
      call phase_event_native_f(tn + ss, y_s, s, InOl, nint(s(16), c_int), val, isterm, dirn, n_out)
      fs = val(idx)

      if (abs(fs) <= abs(fa) .and. abs(fs) <= abs(fb)) then
        s_best = ss; y_best = y_s
      end if

      if (fs == 0.0d0) then
        t_evt = tn + ss; y_evt = y_s
        return
      end if

      if ((fa < 0.0d0) .eqv. (fs < 0.0d0)) then
        a = ss; fa = fs
        fb = fb * 0.5d0
      else
        b = ss; fb = fs; y_b = y_s
        fa = fa * 0.5d0
      end if
    end do

    if ((b - a) <= tol_t) then
      y_evt = y_b
      t_evt = tn + b
    else
      y_evt = y_best
      t_evt = tn + s_best
    end if
  end subroutine localize_event_native

  subroutine rk5_native(t0_loc, y0_loc, tmin, tmax, tend, frac, s, InOl, &
       n_env, env_alt, env_rho, env_c, env_p, n_mach, n_aoa, aer_mach, aer_aoa, aer_cd, &
       tol_t, max_iter_evt, t_end, y_end, fired, rk5_status)
    ! Porting di rk5.m (righe 50-167) + kinematic_step.m: loop RK5 a
    ! passo cinematico clippato [tmin,tmax], con detection eventi
    ! (cambio di segno + vincolo di direzione) e localizzazione via
    ! localize_event_native. NON accumula T/Y (rif. header del file):
    ! solo lo stato corrente.
    real(c_double), intent(in) :: t0_loc, y0_loc(8), tmin, tmax, tend, frac
    real(c_double), intent(in) :: s(38), InOl(3,3)
    integer(c_int), intent(in) :: n_env, n_mach, n_aoa
    real(c_double), intent(in) :: env_alt(n_env), env_rho(n_env), env_c(n_env), env_p(n_env)
    real(c_double), intent(in) :: aer_mach(n_mach), aer_aoa(n_aoa), aer_cd(n_mach, n_aoa)
    real(c_double), intent(in) :: tol_t
    integer(c_int), intent(in) :: max_iter_evt
    real(c_double), intent(out) :: t_end, y_end(8)
    integer(c_int), intent(out) :: fired, rk5_status

    real(c_double) :: tn, yn(8), h, y_next(8), t_next, dy(8)
    real(c_double) :: val_old(3), val_new(3), isterm(3), dirn(3)
    real(c_double) :: v, a, t_evt, y_evt(8)
    integer(c_int) :: n_out, idx, step_count, max_steps, phase_i
    logical :: terminated, is_correct_dir

    tn = t0_loc
    yn = y0_loc
    max_steps = ceiling((tend - t0_loc) / tmin) + 10
    step_count = 0
    fired = 0
    rk5_status = 0
    phase_i = nint(s(16), c_int)

    call phase_event_native_f(tn, yn, s, InOl, phase_i, val_old, isterm, dirn, n_out)

    do
      if (tn >= tend) then
        rk5_status = 1   ! nessun evento entro tmax_phase (simulator:noEventTriggered)
        t_end = tn; y_end = yn
        return
      end if

      step_count = step_count + 1
      if (step_count > max_steps) then
        rk5_status = 2   ! troppi passi (rk5:tooManySteps)
        t_end = tn; y_end = yn
        return
      end if

      call eom_native_f(tn, yn, s(1:31), InOl, n_env, env_alt, env_rho, env_c, env_p, &
           n_mach, n_aoa, aer_mach, aer_aoa, aer_cd, dy)
      v = norm3(yn(4:6))
      a = norm3(dy(4:6))
      if (a > 1.0d-6) then
        h = frac * (v / a)
      else
        h = tmax   ! tau "infinito": stesso esito di frac*Inf poi clippato a tmax
      end if
      if (h < tmin) h = tmin
      if (h > tmax) h = tmax
      if (tn + h > tend) h = tend - tn

      call rk5_step_native(tn, yn, h, s, InOl, n_env, env_alt, env_rho, env_c, env_p, &
           n_mach, n_aoa, aer_mach, aer_aoa, aer_cd, y_next)
      t_next = tn + h

      call phase_event_native_f(t_next, y_next, s, InOl, phase_i, val_new, isterm, dirn, n_out)

      terminated = .false.
      do idx = 1, n_out
        if (val_old(idx)*val_new(idx) <= 0.0d0 .and. val_old(idx) /= val_new(idx)) then
          is_correct_dir = (dirn(idx) == 0.0d0) .or. &
               (dirn(idx) == 1.0d0 .and. val_new(idx) > val_old(idx)) .or. &
               (dirn(idx) == -1.0d0 .and. val_new(idx) < val_old(idx))
          if (is_correct_dir) then
            call localize_event_native(tn, yn, h, s, InOl, &
                 n_env, env_alt, env_rho, env_c, env_p, n_mach, n_aoa, aer_mach, aer_aoa, aer_cd, &
                 idx, val_old(idx), val_new(idx), y_next, tol_t, max_iter_evt, t_evt, y_evt)
            fired = idx
            if (isterm(idx) > 0.5d0) then
              t_end = t_evt
              y_end = y_evt
              rk5_status = 0
              terminated = .true.
              exit
            end if
          end if
        end if
      end do

      if (terminated) return

      tn = t_next
      yn = y_next
      val_old = val_new
    end do
  end subroutine rk5_native

  subroutine tsto_phases16_f(y0, t0, s_base, InOl, &
       n_env, env_alt, env_rho, env_c, env_p, &
       n_mach, n_aoa, aer_mach, aer_aoa, aer_cd, &
       tmin, tmax, tmax_phase, frac, tol_t, max_iter_evt, &
       y_final, t_final, status) bind(C, name="tsto_phases16_f")
    ! Porting di simulator.m S3 (fasi 1-6) + rk5.m + kinematic_step.m.
    ! Rif. solver_project/CLAUDE.md S11 Fase 5, sessione "TSTO libreria
    ! standalone": elimina l'orchestrazione Octave residua attorno a
    ! eom_native_f/phase_event_native_f (gia' native), che oggi gira ad
    ! ogni passo RK5/localizzazione evento. Fase 7-8
    ! (injection_target_orbit.m) restano in Octave per decisione utente
    ! (costo O(1) per valutazione, non hot-path).
    !
    ! Semplificazione deliberata rispetto a rk5.m: NON accumula la
    ! storia T/Y (serve solo a create_output.m per il reporting
    ! completo, mai usato durante l'ottimizzazione: traj_problem.m usa
    ! sempre config.minimal_output=true, che legge solo Y(end,:)).
    !
    ! Layout di s_base(38): IDENTICO a build_eom_native_params.m
    ! (condiviso con eom_native_f/phase_event_native_f). Gli elementi
    ! 14 (active_stage), 15 (isignite), 16 (phase), 21 (last_pitch),
    ! 22 (last_yaw), 25 (pitch_at_transition) sono qui SOVRASCRITTI ad
    ! ogni fase dalla macchina a stati (equivalente a
    ! other.GUI.*/other.isignite/other.phase mutati da simulator.m
    ! S3a/3b/3g/3h): s_base li fornisce solo come valore INIZIALE (fase
    ! 1, stadio 1, motore acceso), non letti da guidance_native in fase 1.
    !
    ! status di uscita (mappato 1:1 su termination_reason di
    ! simulator.m S3h):
    !   0 = raggiunto il boundary fase6->fase7 (evento 1 in fase 6,
    !       "apogeo target raggiunto"): il chiamante Octave deve
    !       proseguire con fase 7-8 (flight_to_apogee.m +
    !       injection_target_orbit.m), invariate.
    !   1 = END_CRASH (quota=0 in una qualunque fase 1-6)
    !   2 = END_PROP2 (propellente stadio2 esaurito in fase 6 prima di
    !       raggiungere l'apogeo target)
    !   3 = errore interno (nessun evento entro tmax_phase, oppure
    !       troppi passi RK5 o troppe transizioni di fase: rete di
    !       sicurezza, equivalente agli error() di
    !       simulator.m:noEventTriggered / rk5:tooManySteps /
    !       simulator:tooManyPhaseIterations, che qui non possono
    !       essere sollevati come eccezioni Octave)
    real(c_double), intent(in) :: y0(8)
    real(c_double), intent(in), value :: t0
    real(c_double), intent(in) :: s_base(38)
    real(c_double), intent(in) :: InOl(3,3)
    integer(c_int), intent(in), value :: n_env
    real(c_double), intent(in) :: env_alt(n_env), env_rho(n_env), env_c(n_env), env_p(n_env)
    integer(c_int), intent(in), value :: n_mach, n_aoa
    real(c_double), intent(in) :: aer_mach(n_mach), aer_aoa(n_aoa)
    real(c_double), intent(in) :: aer_cd(n_mach, n_aoa)
    real(c_double), intent(in), value :: tmin, tmax, tmax_phase, frac, tol_t
    integer(c_int), intent(in), value :: max_iter_evt
    real(c_double), intent(out) :: y_final(8)
    real(c_double), intent(out) :: t_final
    integer(c_int), intent(out) :: status

    real(c_double) :: s(38)
    integer(c_int) :: phase, fired, iteration, rk5_status
    real(c_double) :: t_start, y_start(8), t_ph_end, y_ph_end(8), tend
    real(c_double) :: relative_speed(3), u_end(3), last_pitch, last_yaw

    s = s_base
    t_start = t0
    y_start = y0
    phase = 1
    status = 3   ! sentinella: sovrascritta prima di ogni return "normale"

    do iteration = 1, 14
      ! --- 3a. staging (separazione 1' stadio + fairing a fine fase 4) ---
      if (phase <= 4) then
        s(14) = 1.0d0
      else
        if (nint(s(14)) == 1) then
          y_start(7) = y_start(7) - s(33) - s(36)   ! Minert1 + Mfairing
        end if
        s(14) = 2.0d0
      end if

      ! --- 3b. motore acceso/spento; fase corrente ------------------------
      if (phase == 5) then
        s(15) = 0.0d0
      else
        s(15) = 1.0d0
      end if
      s(16) = dble(phase)

      ! --- 3e. integrazione fase corrente (rk5.m) --------------------------
      tend = t_start + tmax_phase
      call rk5_native(t_start, y_start, tmin, tmax, tend, frac, s, InOl, &
           n_env, env_alt, env_rho, env_c, env_p, n_mach, n_aoa, aer_mach, aer_aoa, aer_cd, &
           tol_t, max_iter_evt, t_ph_end, y_ph_end, fired, rk5_status)

      if (rk5_status /= 0) then
        status = 3
        y_final = y_ph_end
        t_final = t_ph_end
        return
      end if

      t_start = t_ph_end
      y_start = y_ph_end

      ! --- 3g. memoria di guida (last_pitch/last_yaw; pitch_at_transition) -
      relative_speed = eval_relative_speed_f(y_start(1:3), y_start(4:6), s(4))
      call guidance_native(s(1:31), InOl, t_start, y_start(1:3), y_start(4:6), &
           relative_speed, phase, u_end)
      call vect2angleOl_f(mattvec3(InOl, u_end), last_pitch, last_yaw)
      s(21) = last_pitch
      s(22) = last_yaw
      if (phase == 2) then
        s(25) = last_pitch
      end if

      ! --- 3h. fase successiva, secondo l'evento scattato ------------------
      select case (phase)
      case (1, 2, 3)
        select case (fired)
        case (1)
          phase = phase + 1
        case (2)
          status = 1; y_final = y_start; t_final = t_start; return
        case (3)
          phase = 5
        end select
      case (4)
        select case (fired)
        case (1)
          phase = 5
        case (2)
          status = 1; y_final = y_start; t_final = t_start; return
        end select
      case (5)
        select case (fired)
        case (1)
          phase = 6
        case (2)
          status = 1; y_final = y_start; t_final = t_start; return
        end select
      case (6)
        select case (fired)
        case (1)
          status = 0; y_final = y_start; t_final = t_start; return
        case (2)
          status = 1; y_final = y_start; t_final = t_start; return
        case (3)
          status = 2; y_final = y_start; t_final = t_start; return
        end select
      end select
    end do

    ! troppe transizioni di fase (equivalente a
    ! simulator:tooManyPhaseIterations): rete di sicurezza, non atteso.
    status = 3
    y_final = y_start
    t_final = t_start
  end subroutine tsto_phases16_f

end module eom_core_mod
