
module delaybuffer #(
    parameter int DataWidth = 8,
    parameter int CycleDelay = 8
) (
    input  logic                 clk_i,
    input  logic                 reset_i,

    input  logic [DataWidth-1:0] data_i,
    input  logic                 valid_i,
    output logic                 ready_o,

    output logic                 valid_o,
    output logic [DataWidth-1:0] data_o,
    input  logic                 ready_i
);

endmodule
