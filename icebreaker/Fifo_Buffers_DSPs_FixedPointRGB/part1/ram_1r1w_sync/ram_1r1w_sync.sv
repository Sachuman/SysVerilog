
module ram_1r1w_sync #(
    parameter int DataWidth = 8,
    parameter int NumEntries = 512,
    parameter string ReadmembFilename = "memory_init_file.memb"
) (
    input  logic clk_i,
    input  logic reset_i,

    input  logic                          wr_valid_i,
    input  logic [DataWidth-1:0]          wr_data_i,
    input  logic [$clog2(NumEntries)-1:0] wr_addr_i,

    input  logic                          rd_valid_i,
    input  logic [$clog2(NumEntries)-1:0] rd_addr_i,
    output logic [DataWidth-1:0]          rd_data_o
);

    initial begin
        // Display depth and width (You will need to match these in your init file)
        $display("%m: NumEntries is %d, DataWidth is %d", NumEntries, DataWidth);
        // logic [bar:0] foo [baz];
        // In order to get the memory contents in icarus you need to run this for loop during initialization:
        for (int i = 0; i < NumEntries; i++) begin
            // $dumpvars(0,/* Your verilog array name here */);
            ;
        end
   end

endmodule
