
// Copyright (c) 2024 Ethan Sifferman.

// All rights reserved. Distribution Prohibited.


module stop_it import stop_it_pkg::*; (

    input  logic        rst_ni,


    input  logic        clk_4_i,

    input  logic        go_i,

    input  logic        stop_i,

    input  logic        load_i,


    input  logic [15:0] switches_i,

    output logic [15:0] leds_o,


    output logic        digit0_en_o,

    output logic [3:0]  digit0_o,

    output logic        digit1_en_o,

    output logic [3:0]  digit1_o,

    output logic        digit2_en_o,

    output logic [3:0]  digit2_o,

    output logic        digit3_en_o,

    output logic [3:0]  digit3_o

);


// TODO

// Instantiate and drive all required nets and modules




lfsr lfsr(

    .clk_i(clk_4_i),

    .rst_ni(rst_ni),

    .next_i((state_d == WAITING_TO_START)),

    .rand_o(rand_num_o)

);



led_shifter led_shifter(

    .clk_i(clk_4_i),

    .rst_ni(rst_ni),

    .shift_i(shift_l),

    .load_i(start_load),

    .switches_i(switches_i),

    .off_i(off_o),

    .leds_o(leds_o)



);


game_counter game_counter(

    .clk_4_i(clk_4_i),

    .rst_ni(rst_ni & ~(state_d == WAITING_TO_START)),

    .en_i((state_q == DECREMENTING) & (~stop_i)),

    .count_o(count_numb_o)


);


time_counter time_counter(

    .clk_4_i(clk_4_i),

    .rst_ni((rst_ni & ~(state_d == WAITING_TO_START) & ~(state_d == DECREMENTING))),

    .en_i((state_d == CORRECT) || (state_d == WON) || (state_d == WRONG) || (state_d == STARTING)),

    .count_o(count_time_o)


);


logic shift_l, start_load;



logic[4:0] rand_num_o;

logic off_o;

logic[4:0] count_numb_o, count_time_o;



state_t state_d, state_q;

always_ff @(posedge clk_4_i)begin

    if (!rst_ni) begin

        state_q <= WAITING_TO_START;

    end else begin

        state_q <= state_d;

    end

end


always_comb begin


    state_d = state_q;


    digit0_en_o = 0;

    digit1_en_o = 0;

    digit2_en_o = 0;

    digit3_en_o = 0;

    shift_l = 0;

    digit0_o = 0;
    digit1_o = 0;

    digit2_o = 0;

    digit3_o = 0;




    start_load = 0;

    off_o = 0;






    // TODO


    unique case (state_q)


        WAITING_TO_START: begin


            shift_l = 0;


            digit0_en_o = 1;

            digit1_en_o = 1;


            digit0_o = count_numb_o[3:0];

            digit1_o = {1'b0, 1'b0, 1'b0, count_numb_o[4]};

            if(go_i) begin



                state_d = STARTING;

            end


            if(load_i) begin

                start_load = 1;

            end



        end


        STARTING: begin



            digit0_en_o = 1;

            digit1_en_o = 1;

            digit0_o = count_numb_o[3:0];

            digit1_o = {1'b0, 1'b0, 1'b0, count_numb_o[4]};



            if(count_time_o == 8)begin

                state_d = DECREMENTING;

            end



        end



        DECREMENTING: begin





            digit0_en_o = 1;

            digit1_en_o = 1;

            digit2_en_o = 1;

            digit3_en_o = 1;



            digit2_o = rand_num_o[3:0];

            digit3_o = rand_num_o[4];


            digit0_o = count_numb_o[3:0];

            digit1_o = {1'b0, 1'b0, 1'b0, count_numb_o[4]};


            if(stop_i) begin

                if(digit3_o == digit1_o && digit2_o == digit0_o) begin


                    state_d = CORRECT;





                end

                else begin

                    state_d = WRONG;


                end

            end



        end

        WRONG: begin




            // flash simultanousely

            digit0_en_o = ~count_time_o[0];

            digit1_en_o = ~count_time_o[0];

            digit2_en_o = count_time_o[0];

            digit3_en_o = count_time_o[0];

            digit2_o = rand_num_o[3:0];

            digit3_o = rand_num_o[4];

            digit0_o = count_numb_o[3:0];

            digit1_o = {1'b0, 1'b0, 1'b0, count_numb_o[4]};




            if(count_time_o == 16) begin

                state_d = WAITING_TO_START;

            end

             // after some seconds stop blinking digit 4 and 3 enable  is low

            // set digits 3 and 2 = 0




        end

        CORRECT: begin

            // flash together




            digit0_en_o = ~count_time_o[0];

            digit1_en_o = ~count_time_o[0];

            digit2_en_o = ~count_time_o[0];

            digit3_en_o = ~count_time_o[0];

            digit2_o = rand_num_o[3:0];

            digit3_o = rand_num_o[4];

            digit0_o = count_numb_o[3:0];

            digit1_o = {1'b0, 1'b0, 1'b0, count_numb_o[4]};



            // after some seconds stop blinking digit 4 and 3 enable is low

            // set digits 3 and 2 = 0



            if(count_time_o == 16) begin

                if(leds_o == 16'b1111111111111111) begin

                   state_d = WON;

                end

                else begin

                   shift_l = 1;

                   state_d = WAITING_TO_START;

                end

            end



        end


        WON: begin





            // after some seconds stop blinking digit 4 and 3 enable is low

            // set digits 3 and 2 = 0

            off_o = ~count_time_o[0];

            digit0_en_o = 1;

            digit1_en_o = 1;

            digit2_en_o = 1;

            digit3_en_o = 1;

            digit2_o = rand_num_o[3:0];

            digit3_o = rand_num_o[4];

            digit0_o = count_numb_o[3:0];

            digit1_o = {1'b0, 1'b0, 1'b0, count_numb_o[4]};




        end

        default: begin

            state_d = WAITING_TO_START;

        end

    endcase

end


endmodule
