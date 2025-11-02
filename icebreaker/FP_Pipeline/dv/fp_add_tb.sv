
module fp_add_tb
    import float_pkg::*;
    import dv_pkg::*;
    ;

fp_add fp_add (/* */);

task automatic reset();
    // TODO
endtask

function automatic bit isNaN_or_isInf(float_t in);
    return (in.biased_exponent == '1);
endfunction

function automatic bit isNonZeroSubnormal(float_t in);
    return (in.mantissa != 0 && in.biased_exponent == '0);
endfunction

function automatic float_t expected(float_t op_a, float_t op_b);
    // TODO
endfunction

task automatic test(float_t op_a, float_t op_b);
    // TODO
endtask

initial begin
    $dumpfile( "dump.fst" );
    $dumpvars;
    $display( "Begin simulation." );
    $urandom(100);
    $timeformat( -6, 3, "us", 0);

    // TODO

    $display( "End simulation." );
    $finish;
end

endmodule
