// Copyright (c) 2024 Ethan Sifferman.
// All rights reserved. Distribution Prohibited.

module lfsr (
    input  logic       clk_i,
    input  logic       rst_ni,

    input  logic       next_i,
    output logic [4:0] rand_o
);

// TODO
logic count_d, count_q;

logic [7:0] rand_i;



always_comb begin

    count_d = (rand_i[0]^rand_i[5]^rand_i[6]^rand_i[7]);

end

always_ff @(posedge clk_i)  begin
        if(~rst_ni) begin
            count_q <= 0;
            rand_i[7:0] <= 8'b00000001;
        end
        else begin
            if(next_i) begin
            count_q <= count_d;
            rand_i[0] <= count_q;
            rand_i[1] <= rand_i[0];
            rand_i[2] <= rand_i[1];
            rand_i[3] <= rand_i[2];
            rand_i[4] <= rand_i[3];
            rand_i[5] <= rand_i[4];
            rand_i[6] <= rand_i[5];
            rand_i[7] <= rand_i[6];
            end

        end
end

assign rand_o = rand_i[4:0];

endmodule
