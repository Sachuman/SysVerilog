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

    logic [2*DataWidth-1:0] combined_inputs;
    logic [2*DataWidth-1:0] pipeline_out;

    assign combined_inputs = {a_i, b_i};

    elastic #(
        .DataWidth(2*DataWidth),
        .CaptureDataOnlyOnValid(1),  // Only capture when valid
        .ClearDataOnReset(1)         // Clear data on reset
    ) pipeline_stage (
        .clk_i(clk_i),
        .reset_i(reset_i),

        // Input
        .data_i(combined_inputs),
        .valid_i(valid_i),
        .ready_o(ready_o),

        // Output
        .valid_o(valid_o),
        .data_o(pipeline_out),
        .ready_i(ready_i)
    );

    logic [DataWidth-1:0] a_pipeline;
    logic [DataWidth-1:0] b_pipeline;

    assign a_pipeline = pipeline_out[2*DataWidth-1:DataWidth];
    assign b_pipeline = pipeline_out[DataWidth-1:0];

    logic [17:0] dsp_a, dsp_b;
    logic [47:0] dsp_p;

    assign dsp_a = {{(18-DataWidth){1'b0}}, a_pipeline};
    assign dsp_b = {{(18-DataWidth){1'b0}}, b_pipeline};

    DSP48A1 #(
        .A0REG(0),
        .A1REG(0),
        .B0REG(0),
        .B1REG(0),
        .CREG(0),
        .DREG(0),
        .MREG(0),
        .PREG(0),
        .CARRYINREG(0),
        .CARRYOUTREG(0),
        .OPMODEREG(0),
        .CARRYINSEL("OPMODE5"),
        .B_INPUT("DIRECT"),
        .RSTTYPE("SYNC")
    ) u_dsp (
        .CLK(clk_i),
        .A(dsp_a),
        .B(dsp_b),
        .OPMODE(8'b0000_0001),
        .CEA(1'b0),
        .CEB(1'b0),
        .CEC(1'b0),
        .CED(1'b0),
        .CEM(1'b0),
        .CEP(1'b0),
        .CECARRYIN(1'b0),
        .CEOPMODE(1'b0),
        .RSTA(reset_i),
        .RSTB(reset_i),
        .RSTC(reset_i),
        .RSTD(reset_i),
        .RSTM(reset_i),
        .RSTP(reset_i),
        .RSTCARRYIN(reset_i),
        .RSTOPMODE(reset_i),
        .P(dsp_p),
        .BCOUT(),
        .PCOUT(),
        .M(),
        .CARRYOUT(),
        .CARRYOUTF(),
        .C(48'h0),
        .D(18'h0),
        .CARRYIN(1'b0),
        .PCIN(48'h0)
    );

    assign c_o = dsp_p[(2*DataWidth)-1:0];
endmodule
