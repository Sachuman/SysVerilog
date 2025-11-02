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
    typedef enum logic { START, FINISH } state_t;
    state_t state_q, state_d;

    logic shift;
    assign shift = valid_i && ready_o;

    assign ready_o = (state_q == START) ? 1'b1 : ready_i;
    assign valid_o = (state_q == FINISH);

    always_comb begin
        state_d = state_q;

        case (state_q)
            START: begin
                if (shift)
                    state_d = FINISH;
            end
            FINISH: begin
                if (valid_o && ready_i && !shift)
                    state_d = START;
            end
        endcase
    end

    always_ff @(posedge clk_i) begin
        if (reset_i)
            state_q <= START;
        else
            state_q <= state_d;
    end

    for (genvar i = 0; i < DataWidth; i++) begin
        logic q_bit;
        SRL16E #(.INIT(16'h0000)) srl (
            .Q    (q_bit),
            .A0   (CycleDelay[0]),
            .A1   (CycleDelay[1]),
            .A2   (CycleDelay[2]),
            .A3   (CycleDelay[3]),
            .CE   (shift),
            .CLK  (clk_i),
            .D    (data_i[i])
        );
        assign data_o[i] = q_bit;
    end

endmodule
