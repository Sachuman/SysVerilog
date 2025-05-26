module lfsr16_tb;

logic        clk_i;
logic        rst_ni;
logic        next_i;
logic [15:0] rand_o;

lfsr16 lfsr16 (.*);

initial begin
    clk_i = 0;
    forever begin
        clk_i = !clk_i;
        #0.5ns;
    end

end

real sum;
int NumSamples;
real average;

task automatic reset;
    rst_ni <= 0;
    NumSamples = 0;
    sum = 0;
    @(posedge clk_i); #1ps;
    rst_ni <= 1;

endtask

task automatic getNext;
    next_i =1;
    @(posedge clk_i); #1ps;
    sum += rand_o;
    NumSamples++;
    average = sum / NumSamples;
    next_i = 0;
endtask

initial begin
    $dumpfile("dump.fst");
    $dumpvars;
    $display("Begin simulation.");

    reset();
    repeat(10000) begin
        getNext();
    end

    assert (average < 0.6*(2**16) && average > 0.4*(2**16)) 
    else begin
        #1ns $fatal("Average=%0f", average);
    end

    $info("Passed! average=%0f", average);

    $display("End simulation.");
    $finish;
end

endmodule
