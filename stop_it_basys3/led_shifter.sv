// Copyright (c) 2024 Ethan Sifferman.
// All rights reserved. Distribution Prohibited.

module led_shifter (
    input  logic        clk_i,
    input  logic        rst_ni,

    input  logic        shift_i,

    input  logic [15:0] switches_i,
    input  logic        load_i,

    input  logic        off_i,
    output logic [15:0] leds_o
);

// TODO

logic[15:0] for_leds;




always_ff @(posedge clk_i) begin

    if(~rst_ni) begin

       for_leds <= 16'b0000000000000000;
    end

    else begin

        if(load_i)begin
                for_leds <= switches_i;

        end

        else if(shift_i) begin
                for_leds <= ({leds_o[14:0], 1'b1});

            end
    end

end




assign leds_o = (off_i == 1) ? 16'b0000000000000000 : for_leds;


endmodule
