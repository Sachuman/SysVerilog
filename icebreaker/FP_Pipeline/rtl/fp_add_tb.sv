module fp_add_tb
    import float_pkg::*;
    import dv_pkg::*;
    ;

parameter CLK_PERIOD = 126ns;

logic sys_clock, reset_n;
logic dut_input_ready, dut_input_valid;
logic dut_output_ready, dut_output_valid;
float_t input_operand_a, input_operand_b;
float_t output_result;

fp_add DUT (
    .clk_i          (sys_clock),
    .rst_ni         (reset_n),
    .op_ready_o     (dut_input_ready),
    .op_valid_i     (dut_input_valid),
    .op_a_i         (input_operand_a),
    .op_b_i         (input_operand_b),
    .sum_ready_i    (dut_output_ready),
    .sum_valid_o    (dut_output_valid),
    .sum_data_o     (output_result)
);


initial begin
    sys_clock = 0;
    forever #(CLK_PERIOD/2) sys_clock = ~sys_clock;
end

function automatic bit has_infinity_or_nan(input float_t num);
    has_infinity_or_nan = (num.biased_exponent == 8'b11111111);
endfunction

function automatic bit has_nonzero_subnormal(input float_t num);
    has_nonzero_subnormal = (num.biased_exponent == 0) && (num.mantissa != 0);
endfunction

function automatic bit is_special_float(input float_t num);
    is_special_float = has_infinity_or_nan(num) || has_nonzero_subnormal(num);
endfunction

function automatic float_t calculate_reference(input float_t a, input float_t b);
    real real_a = float2real(a);
    real real_b = float2real(b);
    real real_sum = real_a + real_b;
    calculate_reference = real2float(real_sum);
endfunction

task initialize_dut();
    reset_n = 0;
    dut_input_valid = 0;
    dut_output_ready = 0;
    repeat(10) @(posedge sys_clock);
    #1ps;
    reset_n = 1;
endtask

task run_single_test(input float_t a, input float_t b);
    float_t expected_result;
    float_t captured_result;
    bit both_results_zero;

    if (is_special_float(a) || is_special_float(b)) return;


    expected_result = calculate_reference(a, b);
    if (is_special_float(expected_result)) return;

    input_operand_a = a;
    input_operand_b = b;
    dut_input_valid = 1;
    wait(dut_input_ready);
    @(posedge sys_clock);
    #1ps;
    dut_input_valid = 0;

    dut_output_ready = 1;
    wait(dut_output_valid);
    #1ps;
    captured_result = output_result;
    @(posedge sys_clock);
    #1ps;
    dut_output_ready = 0;

    both_results_zero = (float2real(expected_result) == 0.0) &&
                       (float2real(captured_result) == 0.0);

    if (!both_results_zero && (expected_result !== captured_result)) begin
        $error("TEST FAILED: A=%e[%h] + B=%e[%h] -> Expected=%e[%h], Got=%e[%h]",
               float2real(a), a,
               float2real(b), b,
               float2real(expected_result), expected_result,
               float2real(captured_result), captured_result);
    end
endtask

task execute_random_vectors(int iterations);
    $display("Executing %0d random test vectors...", iterations);
    repeat(iterations) begin
        run_single_test(rand_raw_float(), rand_raw_float());
    end
endtask



task execute_edge_cases();
    $display("Executing edge case tests...");

    run_single_test(float_t'(32'b0100_0000_0000_0000_0000_0000_0000_0000), float_t'(32'b0100_1011_0000_0000_0000_0000_0000_0000));
    run_single_test(float_t'(32'b0100_0000_0100_0000_0000_0000_0000_0000), float_t'(32'b0100_1011_1000_0000_0000_0000_0000_0000));

    run_single_test(float_t'(32'b0000_0000_0000_0000_0000_0000_0000_0000), float_t'(32'b1000_0000_0000_0000_0000_0000_0000_0000));

    run_single_test(float_t'(32'b0100_0000_0000_0000_0000_0000_0000_0000), float_t'(32'b1100_0000_0000_0000_0000_0000_0000_0000));
    run_single_test(float_t'(32'b0100_0000_1000_0000_0000_0000_0000_0001), float_t'(32'b1100_0000_1000_0000_0000_0000_0000_0000));

    run_single_test(float_t'(32'b0100_0000_0000_0000_0000_0000_0000_0000), float_t'(32'b0011_1111_0000_0000_0000_0000_0000_0000));
    run_single_test(float_t'(32'b0100_0000_0100_0000_0000_0000_0000_0001), float_t'(32'b0100_0000_0100_0000_0000_0000_0000_0000));
    run_single_test(float_t'(32'b0100_0001_0010_0000_0000_0000_0000_0010), float_t'(32'b0100_0001_0010_0000_0000_0000_0000_0000));
    run_single_test(float_t'(32'b0100_0000_0010_0000_0000_0000_0000_0000), float_t'(32'b0011_1111_1110_0000_0000_0000_0000_0000));

    run_single_test(float_t'(32'b1100_1011_1000_0000_0000_0000_0000_0000), float_t'(32'b0100_1011_1000_0000_0000_0000_0000_0001));

    run_single_test(float_t'(32'b0100_0000_0110_0000_0000_0000_0000_0000), float_t'(32'b0100_0000_0010_0000_0000_0000_0000_0000));

    run_single_test(float_t'(32'b0100_0000_1000_0000_0000_0000_0000_0000), float_t'(32'b0100_1101_0000_0000_0000_0000_0000_0000));
    run_single_test(float_t'(32'b0111_1111_0111_1111_1111_1111_1111_1111), float_t'(32'b0100_0000_0000_0000_0000_0000_0000_0000));
    run_single_test(float_t'(32'b0100_0000_1010_0000_0000_0000_0000_0000), float_t'(32'b1011_1001_0000_0000_0000_0000_0000_0000));
    run_single_test(float_t'(32'b0111_1111_0111_1111_1111_1111_1111_1110), float_t'(32'b0111_1111_0111_1111_1111_1111_1111_1110));

    run_single_test(float_t'(32'b0000_0000_0000_0000_0000_0000_0000_0001), float_t'(32'b0000_0000_0000_0000_0000_0000_0000_0001));
endtask



task execute_rounding_tests();
    $display("Executing rounding tests...");

    run_single_test(float_t'(32'b0100_0000_0000_0000_0000_0000_0000_0000), float_t'(32'b0011_0100_0000_0000_0000_0000_0000_0000));

    run_single_test(float_t'(32'b0100_0000_0100_0000_0000_0000_0000_0000), float_t'(32'b0011_0100_0100_0000_0000_0000_0000_0001));

    run_single_test(float_t'(32'b0100_0000_1000_0000_0000_0000_0000_0000), float_t'(32'b0011_0100_1000_0000_0000_0000_0000_0000));

    run_single_test(float_t'(32'b0100_0001_0000_0000_0000_0000_0000_0000), float_t'(32'b0011_0101_0000_0000_0000_0000_0000_0001));
endtask


task execute_exponent_difference_fuzzing();
    float_t operand1, operand2;
    int base_exp_value, exp_delta;

    $display("Executing exponent difference fuzzing...");

    repeat(10000) begin
        operand1 = rand_raw_float();
        operand2 = rand_raw_float();

        base_exp_value = $urandom_range(100, 127);
        exp_delta = $urandom_range(25, 40);

        operand1.biased_exponent = base_exp_value;
        operand2.biased_exponent = base_exp_value - exp_delta;

        run_single_test(operand1, operand2);
    end
endtask


task execute_additional_tests();
    $display("Executing additional test cases...");

    run_single_test(float_t'(32'b0000_0000_0000_0000_0000_0000_0000_0010), float_t'(32'b0000_0000_1000_0000_0000_0000_0000_0000));

    run_single_test(float_t'(32'b0100_0001_0000_0000_0000_0000_0000_0000), float_t'(32'b0011_0101_0000_0000_0000_0000_0000_0001));
endtask

initial begin
    $dumpfile("fp_adder_waveforms.fst");
    $dumpvars(0, tb_floating_point_adder);

    $timeformat(-6, 3, "us", 0);

    $urandom(100);

    $display("\n");
    $display("========================================");
    $display("  Floating Point Adder Verification");
    $display("  Start Time: %0t", $time);
    $display("========================================\n");

    initialize_dut();

    execute_random_vectors(100000);
    execute_edge_cases();
    execute_rounding_tests();
    execute_exponent_difference_fuzzing();
    execute_additional_tests();

    $display("\n========================================");
    $display("  Verification Complete");
    $display("  End Time: %0t", $time);
    $display("========================================\n");

    #1000ns;
    $finish;
end

endmodule
