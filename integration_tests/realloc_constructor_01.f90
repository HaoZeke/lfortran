! An array constructor assigned to an allocatable array allocates it,
! including a constructor that reads the array being assigned.
program realloc_constructor_01
implicit none
integer, allocatable :: a(:)
character(len=8), allocatable :: c(:)
type :: item
    integer :: n
end type item
type(item), allocatable :: items(:)

a = [1, 2, 3]
if (size(a) /= 3) error stop 1
if (a(1) /= 1 .or. a(2) /= 2 .or. a(3) /= 3) error stop 2
a = [a, 4]
if (size(a) /= 4) error stop 3
if (a(1) /= 1 .or. a(4) /= 4) error stop 4

c = [character(len=8) :: "ab", "cd"]
if (size(c) /= 2) error stop 5
if (c(1) /= "ab" .or. c(2) /= "cd") error stop 6

items = [item(5), item(6)]
if (size(items) /= 2) error stop 7
if (items(1)%n /= 5 .or. items(2)%n /= 6) error stop 8

! The constructor is stored in another allocatable, then assigned across.
block
    character(len=:), allocatable :: list(:), kludge(:)
    list = [character(len=2) :: "ab"]
    kludge = [character(len=2) :: "xy", list]
    list = kludge
    if (size(list) /= 2) error stop 9
    if (list(1) /= "xy" .or. list(2) /= "ab") error stop 10
end block

block
    type :: command
        character(len=:), allocatable :: name(:)
    end type command
    type(command) :: cmd
    cmd%name = [character(len=3) :: "run"]
    cmd%name = [character(len=3) :: "run", "app"]
    if (size(cmd%name) /= 2) error stop 11
    if (cmd%name(1) /= "run" .or. cmd%name(2) /= "app") error stop 12
end block
end program realloc_constructor_01
