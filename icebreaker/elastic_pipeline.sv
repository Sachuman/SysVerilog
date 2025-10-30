module elastic #(
    // verilator lint_off WIDTH
    parameter int DataWidth = 8,
    parameter bit CaptureDataOnlyOnValid = 0,
    parameter bit ClearDataOnReset = 0
    // verilator lint_on WIDTH

) (
    input  logic clk_i,
    input  logic reset_i,

    input  logic [DataWidth-1:0] data_i,
    input  logic                 valid_i,
    output logic                 ready_o,

    output logic                 valid_o,
    output logic [DataWidth-1:0] data_o,
    input  logic                 ready_i
);

 typedef enum logic { START, FINISH } state_t;
  state_t state_q, state_d;

  // Next‐data and registered data
  logic [DataWidth-1:0] reg_data_d, reg_data_q;

  // Outputs
  assign data_o  = reg_data_q;
  assign valid_o = (state_q == FINISH);
  assign ready_o = (state_q == START) ? 1'b1 : ready_i;

  always_comb begin
    // defaults
    state_d    = state_q;
    reg_data_d = reg_data_q;

    case (state_q)
      START: begin
        if (valid_i && ready_o) begin
          state_d = FINISH;
        end

        if (CaptureDataOnlyOnValid) begin
          if (valid_i && ready_o)
            reg_data_d = data_i;
        end else begin
          if (ready_o)
            reg_data_d = data_i;
        end
      end

      FINISH: begin
        if (ready_i) begin
          if (valid_i && ready_o) begin
            state_d = FINISH;
          end else begin
            state_d = START;
          end
        end

        if (CaptureDataOnlyOnValid) begin
          if (valid_i && ready_i)
            reg_data_d = data_i;
        end else begin
          if (ready_i && ready_o)
            reg_data_d = data_i;
        end
      end
    endcase
  end

  always_ff @(posedge clk_i) begin
    if (reset_i) begin
      state_q    <= START;
      if (ClearDataOnReset)
        reg_data_q <= '0;
    end else begin
      state_q    <= state_d;
      reg_data_q <= reg_data_d;
    end
  end

endmodule
