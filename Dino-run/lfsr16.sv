// Copyright (c) 2024 Ethan Sifferman.
// All rights reserved. Distribution Prohibited.

module lfsr16 (
    input  logic       clk_i,
    input  logic       rst_ni,

    input  logic       next_i,
    output logic [15:0] rand_o
);

logic count_d, count_q;


logic [15:0] rand_i;




always_comb begin


    count_d = (rand_i[3]^rand_i[12]^rand_i[14]^rand_i[15]);


end


always_ff @(posedge clk_i)  begin

        if(~rst_ni) begin

            count_q <= 0;

            rand_i[15:0] <= 16'b0000000000000001;

        end

        else begin

            if(next_i) begin

            count_q <= count_d;

            rand_i[0] <= count_d;

            rand_i[1] <= rand_i[0];

            rand_i[2] <= rand_i[1];

            rand_i[3] <= rand_i[2];

            rand_i[4] <= rand_i[3];

            rand_i[5] <= rand_i[4];

            rand_i[6] <= rand_i[5];

            rand_i[7] <= rand_i[6];
            rand_i[8] <= rand_i[7];
            rand_i[9] <= rand_i[8];
            rand_i[10] <= rand_i[9];
            rand_i[11] <= rand_i[10];
            rand_i[12] <= rand_i[11];

            rand_i[13] <= rand_i[12];
            rand_i[14] <= rand_i[13];

            rand_i[15] <= rand_i[14];




            end


        end

end


assign rand_o = rand_i[15:0];


endmodule
