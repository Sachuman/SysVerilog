module delaybuffer #(
    // verilator lint_off WIDTH
    parameter int DataWidth = 8,
    parameter int CycleDelay = 8

    // verilator lint_on WIDTH

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

    logic [DataWidth-1:0] buffer_q [CycleDelay:0];
    logic [DataWidth-1:0] buffer_d [CycleDelay:0];

    assign data_o  = buffer_q[CycleDelay];
    assign valid_o = (state_q == FINISH);
    assign ready_o = (state_q == START) ? 1'b1 : ready_i;

    always_comb begin
        state_d   = state_q;

        for (int i = 0; i <= CycleDelay; i++) begin
            buffer_d[i] = buffer_q[i];
        end

        case (state_q)
            START: begin
                if (valid_i && ready_o) begin
                    // shift in new data
                    for (int i = CycleDelay; i > 0; i--) begin
                        buffer_d[i] = buffer_q[i-1];
                    end
                    buffer_d[0] = data_i;
                    state_d = FINISH;
                end

                // else  if(ready_o) begin
                //     for (int i = CycleDelay; i > 0; i--) begin
                //         buffer_d[i] = buffer_q[i-1];
                //     end
                //     buffer_d[0] = data_i;
                // end
            end

            FINISH: begin
                if (ready_i) begin
                    if (valid_i && ready_o) begin
                        for (int i = CycleDelay; i > 0; i--) begin
                            buffer_d[i] = buffer_q[i-1];
                        end
                        buffer_d[0] = data_i;
                        state_d = FINISH;
                    end else begin
                        state_d = START;
                    end
                end else if (valid_i && ready_o) begin
                    for (int i = CycleDelay; i > 0; i--) begin
                        buffer_d[i] = buffer_q[i-1];
                    end
                    buffer_d[0] = data_i;
                end
            end
        endcase
    end

    always_ff @(posedge clk_i) begin
        if (reset_i) begin
            state_q <= START;
            for (int i = 0; i <= CycleDelay; i++) begin
                buffer_q[i] <= '0;
            end
        end else begin
            state_q <= state_d;
            for (int i = 0; i <= CycleDelay; i++) begin
                buffer_q[i] <= buffer_d[i];
            end
        end
    end

endmodule
