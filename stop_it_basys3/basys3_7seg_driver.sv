// Copyright (c) 2024 Ethan Sifferman.
// All rights reserved. Distribution Prohibited.

module basys3_7seg_driver (
    input              clk_1k_i,
    input              rst_ni,

    input  logic       digit0_en_i,
    input  logic [3:0] digit0_i,
    input  logic       digit1_en_i,
    input  logic [3:0] digit1_i,
    input  logic       digit2_en_i,
    input  logic [3:0] digit2_i,
    input  logic       digit3_en_i,
    input  logic [3:0] digit3_i,

    output logic [3:0] anode_o,
    output logic [6:0] segments_o
);

// TODO

logic[1:0] two_q, two_d;
logic[3:0] digit_o;
logic[6:0] segs_in;

hex7seg hex7seg(
    .d3(digit_o[3]),
    .d2(digit_o[2]),
    .d1(digit_o[1]),
    .d0(digit_o[0]),

    .A(segs_in[0]),
    .B(segs_in[1]),
    .C(segs_in[2]),
    .D(segs_in[3]),
    .E(segs_in[4]),
    .F(segs_in[5]),
    .G(segs_in[6])

);



//seg_enable? ~segs_in: '1 // handle later for board

// logic seg_enable;

always_comb begin
    //seg_enable = 0;

    case (two_q)

        2'b00: begin
            digit_o = digit0_i;
            // seg_enable = digit0_en_i;
            anode_o[0] = ~digit0_en_i;
            anode_o[3:1] = 3'b111;
        end
        2'b01: begin
            digit_o = digit1_i;
            // seg_enable = digit1_en_i;
            anode_o[1] = ~digit1_en_i;
            anode_o[3:2] = 2'b11;
            anode_o[0] = 1;
        end
        2'b10: begin
            digit_o = digit2_i;
            // seg_enable = digit2_en_i;
            anode_o[2] = ~digit2_en_i;
            anode_o[1:0] = 2'b11;
            anode_o[3] = 1;
        end
        2'b11: begin
            digit_o = digit3_i;
            // seg_enable = ;
            anode_o[3] = ~digit3_en_i;
            anode_o[2:0] = 3'b111;
        end

        default: digit_o = 0;
    endcase

end


always_comb begin
    two_d = two_q;
    two_d = two_q + 1;
end

always_comb begin
    if(anode_o == 4'b1111) begin
        segments_o = 7'b1111111;

    end
    else begin
        segments_o = ~segs_in;
    end
end

//2 bit counter
always_ff @(posedge clk_1k_i) begin

    if (~rst_ni) begin
        two_q <= 0;

    end
    else begin
        two_q <= two_d;

    end

end

endmodule
