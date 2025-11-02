module rgb2gray #(
    parameter int DataWidth = 8
) (
    input  logic                 clk_i,
    input  logic                 reset_i,

    input  logic                 valid_i,
    input  logic [DataWidth-1:0] red_i,
    input  logic [DataWidth-1:0] blue_i,
    input  logic [DataWidth-1:0] green_i,
    output logic                 ready_o,

    output logic                 valid_o,
    output logic [DataWidth-1:0] gray_o,
    input  logic                 ready_i
);





    localparam int CoeffPrecision = 8;
    localparam int CoeffExponent = -8;

    localparam logic [CoeffPrecision-1:0] RED_COEFF   = 8'h4C;
    localparam logic [CoeffPrecision-1:0] GREEN_COEFF = 8'h96;
    localparam logic [CoeffPrecision-1:0] BLUE_COEFF  = 8'h1D;

    logic [DataWidth+CoeffPrecision-1:0] red_product;
    logic [DataWidth+CoeffPrecision-1:0] green_product;
    logic [DataWidth+CoeffPrecision-1:0] blue_product;

    logic valid_stage1_o, ready_stage1_i;
    logic [3*(DataWidth+CoeffPrecision)-1:0] stage1_data_i, stage1_data_o;

    assign red_product = red_i * RED_COEFF;
    assign green_product = green_i * GREEN_COEFF;
    assign blue_product = blue_i * BLUE_COEFF;

    assign stage1_data_i = {red_product, green_product, blue_product};

    elastic #(
        .DataWidth(3*(DataWidth+CoeffPrecision)),
        .CaptureDataOnlyOnValid(1)
    ) stage1 (
        .clk_i(clk_i),
        .reset_i(reset_i),
        .data_i(stage1_data_i),
        .valid_i(valid_i),
        .ready_o(ready_o),
        .valid_o(valid_stage1_o),
        .data_o(stage1_data_o),
        .ready_i(ready_stage1_i)
    );

    // Unpack products from stage1
    logic [DataWidth+CoeffPrecision-1:0] red_product_stage1;
    logic [DataWidth+CoeffPrecision-1:0] green_product_stage1;
    logic [DataWidth+CoeffPrecision-1:0] blue_product_stage1;

    assign {red_product_stage1, green_product_stage1, blue_product_stage1} = stage1_data_o;

    logic [DataWidth+CoeffPrecision+1:0] sum_products;
    assign sum_products = red_product_stage1 + green_product_stage1 + blue_product_stage1;

    logic [DataWidth+CoeffPrecision+1:0] stage2_data_i, stage2_data_o;

    assign stage2_data_i = sum_products;

    elastic #(
        .DataWidth(DataWidth+CoeffPrecision+2),
        .CaptureDataOnlyOnValid(1)
    ) stage2 (
        .clk_i(clk_i),
        .reset_i(reset_i),
        .data_i(stage2_data_i),
        .valid_i(valid_stage1_o),
        .ready_o(ready_stage1_i),
        .valid_o(valid_o),
        .data_o(stage2_data_o),
        .ready_i(ready_i)
    );

    logic [DataWidth+1:0] scaled_result;

    logic round_bit;


    always_comb begin
        round_bit = stage2_data_o[7];

        scaled_result = (stage2_data_o >> 8) + round_bit;


        gray_o = scaled_result[DataWidth-1:0];
    end

endmodule
