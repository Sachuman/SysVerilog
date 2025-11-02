
module rgb2gray #(
    parameter int DataWidth = 8
) (
    input  logic                 clk_i,
    input  logic                 reset_i,

    input  logic                 valid_i,
    input  logic [DataWidth-1:0] red_i,
    input  logic [DataWidth-1:0] blue_i,
    input  logic [DataWidth-1:0] green_i,
    output logic                 ready_o,

    output logic                 valid_o,
    output logic [DataWidth-1:0] gray_o,
    input  logic                 ready_i
);

    // The testbench uses this function to test your code. How many
    // fractional bits are needed to enode these values?

    // gray = 0.2989 * r + 0.5870 * g + 0.1140 * b

endmodule
