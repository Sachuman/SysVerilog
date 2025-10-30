// Copyright (c) 2024 Ethan Sifferman.
// All rights reserved. Distribution Prohibited.

module time_counter (
    input  logic       clk_4_i,
    input  logic       rst_ni,
    input  logic       en_i,
    output logic [4:0] count_o
);

// TODO
logic [4:0] first_q, first_d;


always_comb begin
    first_d = first_q;
    first_d = first_q + 1;

end

always_ff @(posedge clk_4_i) begin

    if(~rst_ni) begin
        first_q <= 0;

    end

    else begin
        if(en_i) begin
            first_q <= first_d;
        end

    end

end

assign count_o = first_q;

endmodule
