`timescale 1ns / 1ps

module rom (
    input  logic [31:0] addr,
    output logic [31:0] data
);
    logic [31:0] rom[0:2**15-1];

    initial begin
        $readmemh("code.mem", rom);
    end
    
    assign data = rom[addr[31:2]];
endmodule
