`timescale 1ns / 1ps

module tb_RV32I ();

    logic clk;
    logic reset;
    logic [7:0] GPO_A;

    MCU dut (.*);

    always #5 clk = ~clk;

    initial begin
        clk = 0; reset = 1;
        #10 reset = 0;
    end
endmodule
