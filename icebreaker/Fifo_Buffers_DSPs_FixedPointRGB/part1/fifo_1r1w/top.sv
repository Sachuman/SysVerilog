
// Top-level design file for the icebreaker FPGA board
module top (
    input  logic       clk_12mhz_i,
    // async: Not synchronized to clock
    // unsafe: Not De-Bounced
    // n: Negative Polarity (0 when pressed, 1 otherwise)
    input  logic       reset_async_unsafe_ni,
    // async: Not synchronized to clock
    // unsafe: Not De-Bounced
    input  logic [3:1] button_async_unsafe_i,

    // Line Out (Green)
    // Main clock (for synchronization)
    output logic tx_main_clk_o,
    // Selects between L/R channels, but called a "clock"
    output logic tx_lr_clk_o,
    // Data clock
    output logic tx_data_clk_o,
    // Output Data
    output logic tx_data_o,

    // Line In (Blue)
    // Main clock (for synchronization)
    output logic rx_main_clk_o,
    // Selects between L/R channels, but called a "clock"
    output logic rx_lr_clk_o,
    // Data clock
    output logic rx_data_clk_o,
    // Input data
    input  logic rx_data_i,

    output logic [5:1] led_o
);

    logic clk_pll;

    // These two D Flip Flops form what is known as a Synchronizer. We
    // will learn about these in Week 5, but you can see more here:
    // https://inst.eecs.berkeley.edu/~cs150/sp12/agenda/lec/lec16-synch.pdf
    logic reset_sync_q1;
    logic reset_sync_q2; // Use this as your reset_signal

    dff #() sync_a (
        .clk_i(clk_12mhz_i),
        .reset_i(1'b0),
        .en_i(1'b1),
        .d_i(!reset_async_unsafe_ni),
        .q_o(reset_sync_q1)
    );

    dff #() sync_b (
        .clk_i(clk_12mhz_i),
        .reset_i(1'b0),
        .en_i(1'b1),
        .d_i(reset_sync_q1),
        .q_o(reset_sync_q2)
    );

    logic [31:0] axis_tx_data;
    logic        axis_tx_valid;
    logic        axis_tx_ready;
    logic        axis_tx_last;

    logic [31:0] axis_rx_data;
    logic        axis_rx_valid;
    logic        axis_rx_ready;
    logic        axis_rx_last;

    (* blackbox *)
    // This is a PLL! You'll learn about these later...
    SB_PLL40_PAD #(
        .FEEDBACK_PATH("SIMPLE"),
        .PLLOUT_SELECT("GENCLK"),
        .DIVR(4'b0000),
        .DIVF(7'b1000011),
        .DIVQ(3'b101),
        .FILTER_RANGE(3'b001)
    ) pll_inst (
        .PACKAGEPIN(clk_12mhz_i),
        .PLLOUTCORE(clk_pll),
        .RESETB(1'b1),
        .BYPASS(1'b0)
    );

    assign axis_clk = clk_pll;

    assign axis_tx_data[31:24] = 8'b0;
    axis_i2s2 #() i2s2_inst (
        .axis_clk(axis_clk),
        .axis_resetn(~reset_sync_q2),

        .tx_axis_c_data(axis_tx_data),
        .tx_axis_c_valid(axis_tx_valid),
        .tx_axis_c_ready(axis_tx_ready),
        .tx_axis_c_last(axis_tx_last),

        .rx_axis_p_data(axis_rx_data),
        .rx_axis_p_valid(axis_rx_valid),
        .rx_axis_p_ready(axis_rx_ready),
        .rx_axis_p_last(axis_rx_last),

        .tx_mclk(tx_main_clk_o),
        .tx_lrck(tx_lr_clk_o),
        .tx_sclk(tx_data_clk_o),
        .tx_sdout(tx_data_o),
        .rx_mclk(rx_main_clk_o),
        .rx_lrck(rx_lr_clk_o),
        .rx_sclk(rx_data_clk_o),
        .rx_sdin(rx_data_i)
    );


    // assign axis_tx_data = axis_rx_data;
    // assign axis_tx_last = axis_rx_last;
    // assign axis_tx_valid = axis_rx_valid;
    // assign axis_rx_ready = axis_tx_ready;
    // assign axis_tx_data = axis_rx_data;

    // Input Interface
    logic sipo_out_valid;
    logic sipo_out_ready;

    logic [23:0] sipo_out_rightdata;
    logic [23:0] sipo_out_leftdata;

    // Output Interface
    logic piso_in_valid;
    logic piso_in_ready;

    logic [23:0] piso_in_rightdata;
    logic [23:0] piso_in_leftdata;

    // Serial in, Parallel out
    sipo #() sipo_inst (
        .clk_i                            (clk_o),
        .reset_i                          (reset_sync_q2)
        // Outputs (Input Interface to your module)
        .\data_o[1]                       (sipo_out_rightdata),
        .\data_o[0]                       (sipo_out_leftdata),
        .v_o                              (sipo_out_valid),
        .ready_i                          (sipo_out_ready & sipo_out_valid)
        // Inputs (Don't worry about these)
        .ready_and_o                      (axis_rx_ready),
        .data_i                           (axis_rx_data[23:0]),
        .v_i                              (axis_rx_valid)
    );

    // Parallel in, Serial out
    piso #() piso_inst (
        .clk_i                            (clk_pll),
        .reset_i                          (reset_sync_q2)
        // Outputs (Don't worry about these)
        // Use the low-order bit to signal last
        .data_o                           ({axis_tx_data[23:0], axis_tx_last}),
        .valid_o                          (axis_tx_valid),
        .ready_i                          (axis_tx_ready)
        // Inputs (Output interface from your module)
        .\data_i[1]                       (piso_in_rightdata, 1'b1),
        .\data_i[0]                       (piso_in_leftdata, 1'b0),
        .valid_i                          (piso_in_valid),
        .ready_and_o                      (piso_in_ready)
    );

    // Your code goes here

    // For the FIFO, you must drive all of these signals to implement backpressure
    // For Lab 3, sinusoid you will need to drive piso_in_valid and check piso_in_ready to
    // produce audio. However, you should AlSO drive sipo_out_ready to
    // constant 1 so that the audio continues to stream in (even though
    // you ignore it.
    assign piso_in_valid = sipo_out_valid;
    assign sipo_out_ready = piso_in_ready;

    // You should drive piso_in_rightdata and piso_in_leftdata
    assign piso_in_rightdata = sipo_out_rightdata;
    assign piso_in_leftdata = sipo_out_leftdata;

endmodule
