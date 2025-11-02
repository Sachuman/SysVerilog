
module counter #(
    parameter int MaxValue = 15,
    parameter int DataWidth = $clog2(MaxValue),
    parameter bit [DataWidth-1:0] ResetValue = '0
) (
    input  logic                 clk_i,
    input  logic                 reset_i,
    input  logic                 up_i,
    input  logic                 down_i,
    output logic [DataWidth-1:0] count_o
);

    // Your code here:

endmodule
