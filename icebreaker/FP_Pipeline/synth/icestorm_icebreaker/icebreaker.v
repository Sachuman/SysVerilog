
module icebreaker (
    input  wire CLK,
    input  wire BTN_N,

    input  wire RX,
    output wire TX
);

wire clk_12 = CLK;

reg clk_6;
always @(posedge clk_12) begin
    clk_6 <= !clk_6;
end

// TODO: Drive other clock(s) with PLL
// You can generate PLL configs with icepll
// Example: `icepll -i 12 -o 50`

fp_add_uart #(
    .DesiredBaudRate(9_600),
    .ClockFrequency(6_000_000)
) fp_add_uart (
    .clk_i(clk_6),
    .rst_ni(BTN_N),
    .rx_i(RX),
    .tx_o(TX)
);

endmodule
