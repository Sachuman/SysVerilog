// Copyright (c) 2024 Ethan Sifferman.
// All rights reserved. Distribution Prohibited.

// https://vesa.org/vesa-standards/
// http://tinyvga.com/vga-timing
module vga_timer (
    // TODO
    // possible ports list:
    input  logic       clk_i,
    input  logic       rst_ni,
    output logic       hsync_o,
    output logic       vsync_o,

    output logic       visible_o,
    output logic [9:0] position_x_o,
    output logic [9:0] position_y_o
);


logic [9:0] h_counter_p, h_counter_n; // Horizontal counter (0-799)
logic [9:0] v_counter_p, v_counter_n; // Vertical counter (0-524)


always_comb begin
    h_counter_n = h_counter_p;
    v_counter_n = v_counter_p;
    if (h_counter_p == 10'd799) begin
        h_counter_n = 0;
        if (v_counter_p == 10'd524)
            v_counter_n = 0;
        else
            v_counter_n = v_counter_n + 1;
    end else begin
        h_counter_n = h_counter_n + 1;
    end
end

always_ff @(posedge clk_i) begin
    if(~rst_ni) begin
        h_counter_p <= 0;
        v_counter_p <= 0;
    end

    else begin
      h_counter_p <= h_counter_n;
      v_counter_p <= v_counter_n;
    end
end

assign position_x_o = h_counter_p;
assign position_y_o = v_counter_p;

assign hsync_o = (h_counter_p >= 10'd656 && h_counter_p < 10'd752) ? 0 : 1;
assign vsync_o = (v_counter_p == 10'd490 || v_counter_p == 10'd491) ? 0 : 1;

//active region

assign visible_o = (h_counter_p < 10'd640 && v_counter_p < 10'd480) ? 1 : 0;


endmodule
