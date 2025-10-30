module fp_add_tb
    import float_pkg::*;
    import dv_pkg::*;
;

logic clk_i;
logic rst_ni;
logic op_ready_o;
logic op_valid_i;
float_t op_a_i;
float_t op_b_i;
logic sum_ready_i;
logic sum_valid_o;
float_t sum_data_o;

fp_add fp_add (
    .clk_i,
    .rst_ni,

    .op_ready_o,
    .op_valid_i,
    .op_a_i,
    .op_b_i,

    .sum_ready_i,
    .sum_valid_o,
    .sum_data_o
);


function automatic bit isNaN_or_isInf(float_t in);
    return (in.biased_exponent == '1);
endfunction

function automatic bit isNonZeroSubnormal(float_t in);
    return (in.mantissa != 0 && in.biased_exponent == '0);
endfunction

// Combined function
function automatic bit isUnsupportedFloat (float_t in);
    bit is_inf_or_nan   = isNaN_or_isInf(in);
    bit is_subnormal_nz = isNonZeroSubnormal(in);
    return is_inf_or_nan || is_subnormal_nz;
endfunction

function automatic float_t expected (float_t op_a, float_t op_b);
    real op_a_real = float2real(op_a);
    real op_b_real = float2real(op_b);
    real sum_real  = op_a_real + op_b_real;
    return real2float(sum_real);
endfunction

task automatic reset();
    rst_ni      = 0;
    op_valid_i  = 0;
    sum_ready_i = 0;
    repeat (10) @(posedge clk_i); #1ps;
    rst_ni = 1;
endtask

task automatic test (float_t op_a, float_t op_b);
    float_t expected_sum;
    float_t received_sum;
    bit both_zero;

    // Skip operands that cannot be handled
    if (isUnsupportedFloat(op_a) || isUnsupportedFloat(op_b)) begin
        return;
    end

    expected_sum = expected(op_a, op_b);

    // Skip expectations that cannot be represent
    if (isUnsupportedFloat(expected_sum)) begin
        return;
    end

    op_a_i     = op_a;
    op_b_i     = op_b;
    op_valid_i = 1;
    wait(op_ready_o);
    @(posedge clk_i); #1ps;
    op_valid_i = 0;

    sum_ready_i = 1;
    wait(sum_valid_o); #1ps;
    received_sum = sum_data_o;
    @(posedge clk_i); #1ps;
    sum_ready_i = 0;

    both_zero = (float2real(expected_sum) == 0.0) && (float2real(received_sum) == 0.0);
    if (both_zero) begin
        return;
    end

    if (expected_sum !== received_sum) begin
        $error("Mismatch: op_a = %e (0x%h), op_b = %e (0x%h), expected = %e (0x%h) but got %e (0x%h)",
               float2real(op_a), op_a,
               float2real(op_b), op_b,
               float2real(expected_sum), expected_sum,
               float2real(received_sum), received_sum
               );
    end
endtask

initial begin
    clk_i = 0;
    forever begin
        clk_i = !clk_i;
        #168ns;
    end
end

initial begin
    float_t rnd1, rnd2;
    float_t small_num;
    // nums for exponent testing
    int exp;
    float_t a, b;
    int bit_pos;
    int sticky_type;
    $dumpfile("dump.fst");
    $dumpvars;
    $display("Begin simulation.");
    $urandom(100);
    $timeformat(-6, 3, "us", 0);


    // e test one of the random sticky bits, sets randomly to 0 or 1
    // test every single bit in the mantissa, test putting a mantissa randomly in the
    // b is a weird rounding case, generate, a bunch a round up or down, have exponent value 23 less than the other exponent, so that the guard bit is set
    reset();

    // Random vectors
    repeat (100000) begin
        test(rand_raw_float(), rand_raw_float());
    end

    // Cancellation
    repeat (100) begin
        rnd1 = rand_raw_float();
        rnd2 = rnd1; rnd2.sign = !rnd2.sign; // opposite sign, same magnitude
        test(rnd1, rnd2);
    end

    // Precision loss due to large exponent difference (mantissa of smaller term discarded)
    test(float_t'(32'h3F800000), float_t'(32'h4B000000)); // 1 + 2^23
    test(float_t'(32'h3F800000), float_t'(32'h4B800000)); // 1 + 2^24

    // Signed zero: +0 + (-0) -> result must be +0 (sign rules for zero)
    test(float_t'(32'h00000000), float_t'(32'h80000000));

    // Exact cancellation: +1 + (-1) -> should return 0
    test(float_t'(32'h3F800000), float_t'(32'hBF800000));

    // Near cancellation: +1.0000001 + (-1) -> result should be small positive subnormal
    test(float_t'(32'h3F800001), float_t'(32'hBF800000));

    // Rounding test: 1.0 + 0.25 -> check basic rounding behavior
    test(float_t'(32'h3F800000), float_t'(32'h3E800000));

    // Rounding test: 1.0000001 + 1.0 -> result = 2.0000001
    test(float_t'(32'h3F800001), float_t'(32'h3F800000));

    // Rounding test: 1.0000002 + 1.0 -> result = 2.0000002 (tests ULP resolution)
    test(float_t'(32'h3F800002), float_t'(32'h3F800000));

    // Rounding test: 1.5 + 1.25 -> expect exact 2.75
    test(float_t'(32'h3FC00000), float_t'(32'h3FA00000));

    // Large opposite-signed values with big exponent gap -> test precision retention and sign
    test(float_t'(32'hCB000000), float_t'(32'h4B000001)); // -2^23 + 2^23+1 → expect +1

    // Normalization test: 1.75 + 1.5 -> tests normalization and rounding near boundary
    test(float_t'(32'h3FE00000), float_t'(32'h3FC00000)); // 1.75 + 1.5 = 3.25

    // More tests
    // Normal + very large number -> tests handling of exponent overflow
    test(float_t'(32'h3F800000), float_t'(32'h4C800000));

    // Largest finite float + 1.0 -> tests overflow to INF
    test(float_t'(32'h7F7FFFFF), float_t'(32'h3F800000));

    // 1.0 + large negative -> checks for significant cancellation
    test(float_t'(32'h3F800000), float_t'(32'hB8000000));

    // Max float + max float -> checks for overflow/saturation to INF
    test(float_t'(32'h7F7FFFFF), float_t'(32'h7F7FFFFF));

    // Smallest positive subnormal + itself -> subnormal precision test
    test(float_t'(32'h00000001), float_t'(32'h00000001));

    // Rounding: guard=0, round=0, sticky=0 -> should round down, stays 1.0
    test(float_t'(32'h3F800000), float_t'(32'h33800000));

    // Rounding: guard=0, round=0, sticky=1 -> should round up due to sticky
    test(float_t'(32'h3F800000), float_t'(32'h33800001));

    // Rounding tie-even case: guard=1, round=0, sticky=0 -> should round to even (stays 1.0)
    test(float_t'(32'h3F800000), float_t'(32'h34000000));

    // Rounding up: guard=1, round=0, sticky=1 -> should round up to 1.0 + 1 ULP
    test(float_t'(32'h3F800000), float_t'(32'h34000001));

    // random number
    // fuzzing around the edge case
    repeat (1000) begin
        a = rand_raw_float();
        b = rand_raw_float();

        a.biased_exponent = $urandom_range(100, 127);

        b.biased_exponent = a.biased_exponent - $urandom_range(25, 40);

        test(a, b);
    end

    test(float_t'(32'h00000001), float_t'(32'h00800000));
    test(float_t'(32'h3F800000), float_t'(32'h34000001));


    $display("End simulation.");
    $finish;
end

endmodule