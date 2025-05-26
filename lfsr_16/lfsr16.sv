module lfsr16 (
    input  logic        clk_i,
    input  logic        rst_ni,

    input  logic        next_i,
    output logic [15:0] rand_o
);

logic [15:0] rand_d, rand_q;
assign rand_d[15:1] = rand_q[14:0];
assign rand_d[0] = ^(rand_q & 16'hd008);

assign rand_o = rand_q;

always_ff @(posedge clk_i) begin
    if (!rst_ni) begin
        rand_q <= 1;
    end else if (next_i) begin
        rand_q <= rand_d;
    end
end

endmodule
