
module multiplier #(
   parameter int DataWidth = 16
) (
    input  logic                            clk_i,
    input  logic                            reset_i,

    input  logic                            valid_i,
    input  logic signed [DataWidth-1:0]     a_i,
    input  logic signed [DataWidth-1:0]     b_i,
    output logic                            ready_o,

    output logic                            valid_o,
    output logic signed [(2*DataWidth)-1:0] c_o,
    input  logic                            ready_i
);

endmodule
