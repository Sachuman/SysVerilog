
module fp_add import float_pkg::*; (
    input  logic   clk_i,
    input  logic   rst_ni,

    output logic   op_ready_o,
    input  logic   op_valid_i,
    input  float_t op_a_i,
    input  float_t op_b_i,

    input  logic   sum_ready_i,
    output logic   sum_valid_o,
    output float_t sum_data_o
);

function automatic int count_leading_zeros(logic [MantissaWidth+4:0] in);
    for (int i = 0; i < $bits(in); i++) begin
        if (in[$bits(in)-1-i]) begin
            return i;
        end
    end
    return $bits(in);
endfunction

logic [BiasedExponentWidth-1:0] exponent_difference;
logic [MantissaWidth-1:0] op_sticky_mask;

always_comb begin
    op_sticky_mask = 0;
    if (op_a_q.biased_exponent < op_b_q.biased_exponent) begin
        exponent_difference = (op_b_q.biased_exponent - op_a_q.biased_exponent);
        if (exponent_difference>MantissaWidth+2) op_sticky_mask = '1;
        else if (exponent_difference>2) op_sticky_mask = (1 << (exponent_difference-2))-1;
    end else begin
        exponent_difference = (op_a_q.biased_exponent - op_b_q.biased_exponent);
        if (exponent_difference>MantissaWidth+2) op_sticky_mask = '1;
        else if (exponent_difference>2) op_sticky_mask = (1 << (exponent_difference-2))-1;
    end
end

wire [MantissaWidth:0] a_significand = float_significand(op_a_q);
wire [MantissaWidth:0] b_significand = float_significand(op_b_q);

logic [MantissaWidth+4:0] normalized_a_significand_w_grs;
logic [MantissaWidth+4:0] normalized_b_significand_w_grs;

always_comb begin
    normalized_a_significand_w_grs = {1'b0, a_significand, 3'b000};
    normalized_b_significand_w_grs = {1'b0, b_significand, 3'b000};
    if (op_a_q.biased_exponent < op_b_q.biased_exponent) begin
        normalized_a_significand_w_grs >>= exponent_difference; // TODO: break apart
        normalized_a_significand_w_grs[0] = |(op_a_q.mantissa&op_sticky_mask); // sticky bit
    end else begin
        normalized_b_significand_w_grs >>= exponent_difference; // TODO: break apart
        normalized_b_significand_w_grs[0] = |(op_b_q.mantissa&op_sticky_mask); // sticky bit
    end
end

logic signed [MantissaWidth+5:0] signed_normalized_a_significand_w_grs;
logic signed [MantissaWidth+5:0] signed_normalized_b_significand_w_grs;

always_comb begin
    signed_normalized_a_significand_w_grs = {1'b0, normalized_a_significand_w_grs};
    signed_normalized_b_significand_w_grs = {1'b0, normalized_b_significand_w_grs};
    if (op_a_q.sign) signed_normalized_a_significand_w_grs *= -1;
    if (op_b_q.sign) signed_normalized_b_significand_w_grs *= -1;
end

logic signed [MantissaWidth+5:0] signed_unnormalized_sum_w_grs;
logic [MantissaWidth+4:0] unnormalized_sum_w_grs;

always_comb begin
    signed_unnormalized_sum_w_grs = signed_normalized_a_significand_w_grs + signed_normalized_b_significand_w_grs;
    if (signed_unnormalized_sum_w_grs[MantissaWidth+5]) // negative
        unnormalized_sum_w_grs = -signed_unnormalized_sum_w_grs[MantissaWidth+4:0];
    else
        unnormalized_sum_w_grs = signed_unnormalized_sum_w_grs[MantissaWidth+4:0];
end

wire int ffs_unnormalized_sum = count_leading_zeros(unnormalized_sum_w_grs);

wire [MantissaWidth+4:0] normalized_sum_grss = unnormalized_sum_w_grs << ffs_unnormalized_sum; // TODO: break apart
wire [MantissaWidth+3:0] normalized_sum_grs = (normalized_sum_grss >> 1) | normalized_sum_grss[0];

// 1 extra bit in case of overflow
logic [MantissaWidth+1:0] big_normalized_sum;

always_comb begin
    big_normalized_sum = normalized_sum_grs >> 3;
    if (normalized_sum_grs[2] == 1'b1) begin
        if (normalized_sum_grs[1:0] != 2'b00) begin // always round up if over b100
            big_normalized_sum++;
        end else if (big_normalized_sum[0]) begin // round ties towards even
            big_normalized_sum++;
        end
    end
end

logic [MantissaWidth:0] normalized_sum;
logic exponent_change_on_round;

always_comb begin
    if (big_normalized_sum[MantissaWidth+1]) begin // overflow occurred
        exponent_change_on_round = 1;
        normalized_sum = big_normalized_sum >> 1;
    end else begin
        exponent_change_on_round = 0;
        normalized_sum = big_normalized_sum;
    end
end

logic signed [BiasedExponentWidth-1:0] sum_biased_exponent;

always_comb begin
    if (op_a_q.biased_exponent > op_b_q.biased_exponent) begin
        sum_biased_exponent = op_a_q.biased_exponent;
    end else begin
        sum_biased_exponent = op_b_q.biased_exponent;
    end
    sum_biased_exponent -= ffs_unnormalized_sum - 1;

    if (exponent_change_on_round)
        sum_biased_exponent++;
    if (normalized_sum == 0)
        sum_biased_exponent = 0;
end

float_t sum_data_working;
float_t sum_data_d, sum_data_q;

assign sum_data_working.sign = signed_unnormalized_sum_w_grs[$bits(signed_unnormalized_sum_w_grs)-1];
assign sum_data_working.mantissa = normalized_sum[MantissaWidth-1:0]; // cut off implicit 1
assign sum_data_working.biased_exponent = sum_biased_exponent;

typedef enum logic [1:0] {
    IDLE,
    WORKING,
    DONE
} state_t;

state_t state_d, state_q;
float_t op_a_d, op_a_q;
float_t op_b_d, op_b_q;
always_ff @(posedge clk_i) begin
    if (!rst_ni) begin
        state_q <= IDLE;
        op_a_q <= 'x;
        op_b_q <= 'x;
        sum_data_q <= 'x;
    end else begin
        state_q <= state_d;
        op_a_q <= op_a_d;
        op_b_q <= op_b_d;
        sum_data_q <= sum_data_d;
    end
end

always_comb begin
    state_d = state_q;
    op_ready_o = 0;
    sum_valid_o = 0;
    sum_data_d = sum_data_q;
    op_a_d = op_a_q;
    op_b_d = op_b_q;
    sum_data_o = 'x;

    if (state_q == IDLE) begin
        op_ready_o = 1;
        if (op_ready_o && op_valid_i) begin
            state_d = WORKING;
            op_a_d = op_a_i;
            op_b_d = op_b_i;
        end
    end else if (state_q == WORKING) begin
        state_d = DONE;
        sum_data_d = sum_data_working;
    end else if (state_q == DONE) begin
        sum_valid_o = 1;
        sum_data_o = sum_data_q;
        if (sum_ready_i && sum_valid_o) begin
            state_d = IDLE;
            sum_data_d = 'x;
            op_a_d = 'x;
            op_b_d = 'x;
        end
    end
end

endmodule
