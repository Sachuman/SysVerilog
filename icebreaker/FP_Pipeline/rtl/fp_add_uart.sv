
module fp_add_uart #(
    // 4800, 9600, 19200, 38400, 57600, 115200, 230400, 460800, 921600
    parameter int DesiredBaudRate = 115_200,
    parameter int ClockFrequency = 12_000_000
) (
    input  logic clk_i,
    input  logic rst_ni,
    input  logic rx_i,
    output logic tx_o
);

wire [7:0] uart_rx_data;
wire       uart_rx_valid;
wire       uart_rx_ready;

// https://www.desmos.com/calculator/c9lqrtgpbk
localparam shortint Prescale = shortint'((1.0 * ClockFrequency) / (8.0 * DesiredBaudRate));
localparam real ActualBaudRate = (1.0 * ClockFrequency) / (8.0 * Prescale);
localparam real BaudRateError = 1.0 - (ActualBaudRate / (1.0 * DesiredBaudRate));
if (BaudRateError < -0.05 || BaudRateError > 0.05)
    $error("DesiredBaudRate not attainable given ClockFrequency: BaudRateError=%2.0f%%.", 100*BaudRateError);

uart_rx #(
    .DATA_WIDTH(8)
) uart_rx (
    .clk(clk_i),
    .rst(!rst_ni),

    .m_axis_tdata(uart_rx_data),
    .m_axis_tvalid(uart_rx_valid),
    .m_axis_tready(uart_rx_ready),

    .rxd(rx_i),

    .busy(),
    .overrun_error(),
    .frame_error(),

    .prescale(Prescale)
);

logic        fp_add_in_ready;
logic        fp_add_in_valid;
logic [31:0] fp_add_in_opA;
logic [31:0] fp_add_in_opB;

logic        fp_add_out_ready;
logic        fp_add_out_valid;
logic [31:0] fp_add_out_sum;

fp_add fp_add (
    .clk_i,
    .rst_ni,

    .op_ready_o(fp_add_in_ready),
    .op_valid_i(fp_add_in_valid),
    .op_a_i(fp_add_in_opA),
    .op_b_i(fp_add_in_opB),

    .sum_ready_i(fp_add_out_ready),
    .sum_valid_o(fp_add_out_valid),
    .sum_data_o(fp_add_out_sum)
);

logic [63:0] fp_add_in_opAB;
assign {fp_add_in_opA, fp_add_in_opB} = fp_add_in_opAB;

bsg_serial_in_parallel_out_full #(
    .width_p(8),
    .els_p(8),
    .hi_to_lo_p(1)
) fp_add_in_sipo (
    .clk_i,
    .reset_i(!rst_ni),

    .v_i(uart_rx_valid),
    .ready_and_o(uart_rx_ready),
    .data_i(uart_rx_data),

    .data_o(fp_add_in_opAB),
    .v_o(fp_add_in_valid),
    .yumi_i(fp_add_in_ready && fp_add_in_valid)
);

logic [7:0] uart_tx_data;
logic       uart_tx_ready;
logic       uart_tx_valid;

bsg_parallel_in_serial_out #(
    .width_p(8),
    .els_p(4),
    .hi_to_lo_p(1)
) fp_add_out_piso (
    .clk_i,
    .reset_i(!rst_ni),

    .valid_i(fp_add_out_valid),
    .data_i(fp_add_out_sum),
    .ready_and_o(fp_add_out_ready),

    .valid_o(uart_tx_valid),
    .data_o(uart_tx_data),
    .yumi_i(uart_tx_ready && uart_tx_valid)
);

uart_tx #(
    .DATA_WIDTH(8)
) uart_tx (
    .clk(clk_i),
    .rst(!rst_ni),

    .s_axis_tdata(uart_tx_data),
    .s_axis_tvalid(uart_tx_valid),
    .s_axis_tready(uart_tx_ready),

    .txd(tx_o),

    .busy(),

    .prescale(Prescale)
);

endmodule
