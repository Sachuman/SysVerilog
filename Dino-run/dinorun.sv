// Copyright (c) 2024 Ethan Sifferman.
// All rights reserved. Distribution Prohibited.

module dinorun import dinorun_pkg::*; (
    input  logic       clk_25_175_i,
    input  logic       rst_ni,

    input  logic       start_i,
    input  logic       up_i,
    input  logic       down_i,

    output logic       digit0_en_o,
    output logic [3:0] digit0_o,
    output logic       digit1_en_o,
    output logic [3:0] digit1_o,
    output logic       digit2_en_o,
    output logic [3:0] digit2_o,
    output logic       digit3_en_o,
    output logic [3:0] digit3_o,

    output logic [3:0] vga_red_o,
    output logic [3:0] vga_green_o,
    output logic [3:0] vga_blue_o,
    output logic       vga_hsync_o,
    output logic       vga_vsync_o
);

// TODO

logic get_next_frame;
logic pixel_b, pixel_c, pixel_d, pixel_t;

logic[15:0] lfsr_rand_o;
logic[9:0] pos_x, pos_y;
logic visible_vga;
logic hsync_q, vsync_q, hsync_d, vsync_d;
logic[11:0] rgb_q, rgb;
logic im_hurt;

state_t state_q, state_d;
logic pixel_b2;

always_ff @(posedge clk_25_175_i)begin

    if (!rst_ni) begin
        state_q <= WAITING_TO_START;

    end else begin
        state_q <= state_d;
    end

end

vga_timer vga_timer(
    .clk_i(clk_25_175_i),
    .rst_ni(rst_ni),
    .hsync_o(hsync_d),
    .vsync_o(vsync_d),
    .visible_o(visible_vga),
    .position_x_o(pos_x),
    .position_y_o(pos_y)


);

edge_detector edge_detector(
    .clk_i(clk_25_175_i),
    .data_i(vga_vsync_o),
    .edge_o(get_next_frame)

);


bird bird(
    .clk_i(clk_25_175_i),
    .rst_ni(rst_ni && ~(state_q == WAITING_TO_START) && !start_i),
    .next_frame_i(get_next_frame && !im_hurt),
    .spawn_i(lfsr_rand_o[12:7] == 6'b101010 && ((state_q == RUNNING) || (state_q == LOSE))),
    .rand_i(lfsr_rand_o),
    .pixel_x_i(pos_x),
    .pixel_y_i(pos_y),
    .pixel_o(pixel_b)

);

bird bird2(
    .clk_i(clk_25_175_i),
    .rst_ni(rst_ni && ~(state_q == WAITING_TO_START) && !start_i),
    .next_frame_i(get_next_frame && !im_hurt),
    .spawn_i(lfsr_rand_o[12:7] == 6'b101110 && ((state_q == RUNNING) || (state_q == LOSE))),
    .rand_i(lfsr_rand_o),
    .pixel_x_i(pos_x),
    .pixel_y_i(pos_y),
    .pixel_o(pixel_b2)

);


dino dino(
    .clk_i(clk_25_175_i),
    .rst_ni(rst_ni),
    .next_frame_i(get_next_frame && !im_hurt),
    .up_i(up_i),
    .down_i(down_i),
    .hit_i(im_hurt),
    .pixel_x_i(pos_x),
    .pixel_y_i(pos_y),
    .pixel_o(pixel_d)


);

cactus cactus(
    .clk_i(clk_25_175_i),
    .rst_ni(rst_ni && ~(state_q == WAITING_TO_START) && !start_i),
    .next_frame_i(get_next_frame && !im_hurt),
    .spawn_i(lfsr_rand_o[12:8] == 5'b00000 && ((state_q == RUNNING) || (state_q == LOSE))),
    .rand_i(lfsr_rand_o),
    .pixel_x_i(pos_x),
    .pixel_y_i(pos_y),
    .pixel_o(pixel_c)

);

title title(
    .pixel_x_i(pos_x),
    .pixel_y_i(pos_y),
    .pixel_o(pixel_t)


);

lfsr16 lfsr16(
    .clk_i(clk_25_175_i),
    .rst_ni(rst_ni),
    .next_i(state_q == RUNNING),
    .rand_o(lfsr_rand_o)

);

score_counter score_counter(
    .clk_i(clk_25_175_i),
    .rst_ni(rst_ni && ~(state_q == WAITING_TO_START) && !start_i),
    .en_i((state_q == RUNNING) && !im_hurt && get_next_frame),
    .digit0_o(digit0_o),
    .digit1_o(digit1_o),
    .digit2_o(digit2_o),
    .digit3_o(digit3_o)

);


assign {vga_red_o, vga_green_o, vga_blue_o} = rgb_q;

assign vga_hsync_o = hsync_q;
assign vga_vsync_o = vsync_q;

assign im_hurt = (state_q == LOSE);


always_ff @(posedge clk_25_175_i)begin

    if(!rst_ni) begin
        hsync_q <= 0;
        vsync_q <= 0;
        rgb_q <= 0;


    end

    else begin
        hsync_q <= hsync_d;
        vsync_q <= vsync_d;
        rgb_q <= rgb;


    end

end





always_comb begin

    rgb = 12'b000000000000;

    if(visible_vga) begin

        if(pixel_d) begin
            rgb = 12'b000010110000;
        end

        if(pixel_b2)begin
            rgb = 12'b000011100000;
        end

        if(pixel_b)begin
            rgb = 12'b000011100000;
        end

        if(pixel_c) begin
            rgb = 12'b000011100000;
        end

        if (pixel_t && (state_q == WAITING_TO_START)) begin
            rgb = 12'b001001100101;
        end

        if(pos_y > 399) begin
            rgb = 12'b111111111111;

        end
    end
end







always_comb begin

    state_d = state_q;
    digit0_en_o = 1;
    digit1_en_o = 1;
    digit2_en_o = 1;
    digit3_en_o = 1;

    unique case (state_q)

        WAITING_TO_START: begin

            if(start_i) begin
                state_d = RUNNING;

            end

        end

        RUNNING: begin

            if((pixel_b && pixel_d) || (pixel_c && pixel_d) ||(pixel_b2 && pixel_d)) begin

                state_d = LOSE;

            end



        end


        LOSE: begin

            if(start_i) begin
                state_d = RUNNING;

            end


        end
        default: begin
            state_d = WAITING_TO_START;

        end


    endcase

end
endmodule
