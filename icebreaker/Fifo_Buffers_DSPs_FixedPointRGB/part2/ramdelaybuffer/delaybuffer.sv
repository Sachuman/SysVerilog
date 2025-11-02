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

    localparam int AddrWidth  = (CycleDelay == 1) ? 1 : $clog2(CycleDelay);

    logic [AddrWidth-1:0] write_count_q, write_count_d;


    assign ready_o = (state_q == START) ? 1'b1 : ready_i;
    assign valid_o = (state_q == FINISH);

    always_comb begin
        state_d = state_q;
        write_count_d = write_count_q;
        case (state_q)

            START: begin
                /* verilator lint_off WIDTHEXPAND */
                if(valid_i && ready_o) begin
                    if (write_count_q == (CycleDelay-1)) begin
                        write_count_d = '0;
                /* verilator lint_on WIDTHEXPAND */
                    end
                    else begin
                        write_count_d = write_count_q + 1;
                    end
                    state_d = FINISH;
                end
            end

            FINISH: begin
                if (ready_i) begin
                    state_d = START;
                    if (valid_i && ready_o) begin
                    /* verilator lint_off WIDTHEXPAND */
                        if (write_count_q == (CycleDelay-1)) begin
                            write_count_d = '0;
                        end
                    /* verilator lint_on WIDTHEXPAND */

                        else begin
                            write_count_d = write_count_q + 1;
                        end
                        state_d = FINISH;
                    end
                end

            end

            default: state_d = START;

        endcase

    end

    // Sequential logic
    always_ff @(posedge clk_i) begin

        if (reset_i) begin
            state_q <= START;
            write_count_q <= '0;
        end else begin
            state_q <= state_d;
            write_count_q <= write_count_d;
        end
    end


    ram_1r1w_sync #(
        .DataWidth(DataWidth),
        .NumEntries(CycleDelay)
    ) ram (
        .clk_i(clk_i),
        .reset_i(reset_i),
        .wr_valid_i((valid_i && ready_o)),
        .wr_data_i(data_i),
        .wr_addr_i(write_count_q),
        .rd_valid_i((valid_i && ready_o)),
        .rd_addr_i(write_count_q),
        .rd_data_o(data_o)
    );




endmodule
