
dv/dv_pkg.sv

dv/fp_add_tb.sv

dv/float.c

--timing
-j 0
-Wall
--assert
--trace-fst
--trace-structs
--main-top-name "-"

// Run with +verilator+rand+reset+2
--x-assign unique
--x-initial unique

-Werror-IMPLICIT
-Werror-USERERROR
-Werror-LATCH

// Required for some compilers
-CFLAGS -std=c++20
