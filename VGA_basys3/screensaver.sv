// Copyright (c) 2024 Ethan Sifferman.
// All rights reserved. Distribution Prohibited.

module screensaver (
    input  logic       clk_i,
    input  logic       rst_ni,

    input  logic [3:0] select_image_i,

    output logic [3:0] vga_red_o,
    output logic [3:0] vga_blue_o,
    output logic [3:0] vga_green_o,
    output logic       vga_hsync_o,
    output logic       vga_vsync_o
);

localparam int IMAGE_WIDTH = 160;
localparam int IMAGE_HEIGHT = 120;
localparam int IMAGE_ROM_SIZE = (IMAGE_WIDTH * IMAGE_HEIGHT);

logic [$clog2(IMAGE_ROM_SIZE)-1:0] rom_addr;

logic [11:0] image0_rdata;
logic [11:0] image1_rdata;
logic [11:0] image2_rdata;
logic [11:0] image3_rdata;

images #(
    .IMAGE_ROM_SIZE(IMAGE_ROM_SIZE)
) images (
    .clk_i,
    .rom_addr_i(rom_addr),
    .image0_rdata_o(image0_rdata),
    .image1_rdata_o(image1_rdata),
    .image2_rdata_o(image2_rdata),
    .image3_rdata_o(image3_rdata)
);

// TODO
logic[9:0] num_x, num_y;
logic  vga_h, vga_v;
logic visible_o, visisi;

vga_timer vga_timer(
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .hsync_o(vga_h),
    .vsync_o(vga_v),
    .position_x_o(num_x),
    .position_y_o(num_y),
    .visible_o(visisi)
);


logic[11:0] rgb;

assign {vga_red_o, vga_green_o, vga_blue_o} = rgb;
logic[3:0] temp_save;

assign rom_addr = num_x[9:2]+ num_y[9:2]*160;

always_ff @(posedge clk_i) begin
    if (rst_ni) begin
        visible_o <= visisi;

        vga_hsync_o <= vga_h;
        vga_vsync_o <= vga_v;

        if(select_image_i <= 4'b0000)
            temp_save <= temp_save;
        else
            temp_save <= select_image_i;

    end

end

always_comb begin
        rgb = 0;
        if(visible_o) begin
                case (temp_save)
                    4'b0001: rgb = image0_rdata;
                    4'b0010: rgb = image1_rdata;
                    4'b0100: rgb = image2_rdata;
                    4'b1000: rgb = image3_rdata;
                    default: rgb = 0;
                endcase
            end
end
            //asisgn rom_addr = num_x/4+ num_y/4; // Issue


endmodule
