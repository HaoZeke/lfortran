subroutine bench_lsoda(nrep, y1, y2, y3, istate)
  implicit none
  integer, intent(in) :: nrep
  double precision, intent(out) :: y1, y2, y3
  integer, intent(out) :: istate
  integer :: i, neq, itol, itask, iopt, jt, lrw, liw, rep
  double precision :: t, tout, rtol, atol
  double precision :: y(3), rwork(200)
  integer :: iwork(40)
  external robertson, dummy_jac
  neq = 3
  itol = 1
  rtol = 1.0d-6
  atol = 1.0d-8
  itask = 1
  iopt = 0
  lrw = 200
  liw = 40
  jt = 2
  y1 = 0.0d0
  y2 = 0.0d0
  y3 = 0.0d0
  istate = 0
  do rep = 1, nrep
    y(1) = 1.0d0
    y(2) = 0.0d0
    y(3) = 0.0d0
    t = 0.0d0
    tout = 1.0d4
    istate = 1
    do i = 1, 20
      rwork(i) = 0.0d0
    end do
    do i = 1, 40
      iwork(i) = 0
    end do
    call lsoda(robertson, neq, y, t, tout, itol, rtol, atol, itask, &
        istate, iopt, rwork, lrw, iwork, liw, dummy_jac, jt)
    if (istate < 0) exit
  end do
  y1 = y(1)
  y2 = y(2)
  y3 = y(3)
end subroutine bench_lsoda

subroutine robertson(neq, t, y, ydot)
  implicit none
  integer :: neq
  double precision :: t, y(*), ydot(*)
  double precision :: y1, y2, y3
  y1 = y(1)
  y2 = y(2)
  y3 = y(3)
  ydot(1) = -0.04d0*y1 + 1.0d4*y2*y3
  ydot(2) = 0.04d0*y1 - 1.0d4*y2*y3 - 3.0d7*y2*y2
  ydot(3) = 3.0d7*y2*y2
end subroutine robertson

subroutine dummy_jac(neq, t, y, ml, mu, pd, nrowpd)
  implicit none
  integer :: neq, ml, mu, nrowpd
  double precision :: t, y(*), pd(nrowpd, *)
end subroutine dummy_jac
