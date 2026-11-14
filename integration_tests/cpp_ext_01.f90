! `.F90`, `.F`, `.FOR`, and `.fpp` are preprocessed without `--cpp`.
! `--no-cpp` turns that off. The bodies are valid as free form and as
! fixed form, which is how gfortran reads `.F`, `.FOR`, and `.fpp`.
program cpp_ext_01
implicit none
character(len=1024) :: compiler
character(len=16) :: ext(4)
integer :: nanswer(4)
integer :: i, length, status, exitstat, got, ios
logical :: lfortran

ext = [character(len=16) :: "F90", "F", "FOR", "fpp"]
nanswer = [1, 2, 3, 4]
call get_environment_variable("LFORTRAN", compiler, length, status)
if (status /= 0 .or. length <= 0) compiler = "lfortran"
lfortran = index(compiler, "lfortran") > 0

do i = 1, 4
    call compile_and_run(ext(i), nanswer(i), i)
end do

call run_compiler("--no-cpp", "-nocpp", "F90", exitstat)
if (exitstat == 0) error stop 9

contains

    subroutine compile_and_run(extension, answer, n)
        character(len=*), intent(in) :: extension
        integer, intent(in) :: answer, n
        integer :: exitstat, got
        call write_source("cpp_ext_01_src." // trim(extension), answer)
        call run_compiler("", "", extension, exitstat)
        if (exitstat /= 0) error stop n
        call execute_command_line("./cpp_ext_01_bin > cpp_ext_01_out", &
            exitstat=exitstat)
        if (exitstat /= 0) error stop 10 + n
        open(unit=12, file="cpp_ext_01_out", status="old")
        read(12, *) got
        close(12)
        if (got /= answer) error stop 20 + n
    end subroutine compile_and_run

    subroutine write_source(filename, answer)
        character(len=*), intent(in) :: filename
        integer, intent(in) :: answer
        open(unit=10, file=filename, status="replace")
        write(10, '(a)') "      program p"
        write(10, '(a)') "#if 0"
        write(10, '(a)') "      notfortran"
        write(10, '(a,i0)') "      print *, ", answer
        write(10, '(a)') "#endif"
        write(10, '(a,i0)') "      print *, ", answer
        write(10, '(a)') "      end"
        close(10)
    end subroutine write_source

    subroutine run_compiler(lf_flag, gf_flag, extension, exitstat)
        character(len=*), intent(in) :: lf_flag, gf_flag, extension
        integer, intent(out) :: exitstat
        character(len=4096) :: cmd
        character(len=32) :: flag
        if (lfortran) then
            flag = lf_flag
        else
            flag = gf_flag
        end if
        cmd = '"' // trim(compiler) // '" ' // trim(flag) // &
            " cpp_ext_01_src." // trim(extension) // " -o cpp_ext_01_bin"
        call execute_command_line(trim(cmd), exitstat=exitstat)
    end subroutine run_compiler

end program cpp_ext_01
