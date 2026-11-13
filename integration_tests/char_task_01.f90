program char_task_01
implicit none
character(len=60) :: task
character(len=2) :: short
integer :: i
task = 'START'
if (task(1:5) /= 'START') error stop
if (task(6:6) /= ' ') error stop
do i = 1, 4
    call step(task)
end do
if (task(1:4) /= 'STOP') error stop
if (task(5:5) /= ' ') error stop
short = 'ABCD'
if (short /= 'AB') error stop
if (.not. ('FG' == 'FG  ')) error stop
if (.not. ('FGX' > 'FG')) error stop
if ('FG' > 'FGX') error stop
contains
    subroutine step(task)
        character(len=*) :: task
        if (task(1:5) == 'START') then
            task = 'FG'
        else if (task(1:2) == 'FG') then
            task = 'NEW_X'
        else if (task(1:5) == 'NEW_X') then
            task = 'CONV'
        else if (task(1:4) == 'CONV') then
            task = 'STOP'
        else
            task = 'ERROR'
        end if
    end subroutine
end program
