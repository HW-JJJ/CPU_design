`timescale 1ns / 1ps

module GPI_Periph(
    // global signal
    input  logic        PCLK,
    input  logic        PRESET,
    // APB Interface Signals
    input  logic [ 3:0] PADDR,
    input  logic [31:0] PWDATA,
    input  logic        PWRITE,
    input  logic        PENABLE,
    input  logic        PSEL,
    output logic [31:0] PRDATA,
    output logic        PREADY,
    // export signals
    input  logic [ 7:0] inPort
);
    logic [ 7:0] modeR;
    logic [ 7:0] idR;    

    APB_Slave_Interface_GPI U_APB_Slave_Interface(.*);
    GPI                     U_GPI (.*);
endmodule 

module APB_Slave_Interface_GPI (
    // global signal
    input  logic        PCLK,
    input  logic        PRESET,
    // APB Interface Signals
    input  logic [ 3:0] PADDR,
    input  logic [31:0] PWDATA,
    input  logic        PWRITE,
    input  logic        PENABLE,
    input  logic        PSEL,
    output logic [31:0] PRDATA,
    output logic        PREADY,
    // internal signals
    output logic [ 7:0] modeR,
    input  logic [ 7:0] idR
);
    logic [31:0] slv_reg0, slv_reg1, slv_reg2, slv_reg3;

    assign modeR = slv_reg0[7:0];
    assign slv_reg1[7:0] = idR;

    always_ff @(posedge PCLK, posedge PRESET) begin
        if (PRESET) begin
            slv_reg0 <= 0;
            //slv_reg1 <= 0;  // idR에는 master가 데이터를 쓰면 안됨
            //slv_reg2 <= 0;
            //slv_reg3 <= 0;
        end else begin
            if (PSEL && PENABLE) begin
                PREADY <= 1'b1;
                if (PWRITE) begin
                    case (PADDR[3:2])
                        2'd0: slv_reg0 <= PWDATA;
                        //2'd1: slv_reg1 <= PWDATA;
                        //2'd2: slv_reg2 <= PWDATA;
                        //2'd3: slv_reg3 <= PWDATA;
                    endcase
                end else begin
                    PRDATA <= 32'bx;
                    case (PADDR[3:2])
                        2'd0: PRDATA <= slv_reg0;
                        2'd1: PRDATA <= slv_reg1;
                        2'd2: PRDATA <= slv_reg2;
                        2'd3: PRDATA <= slv_reg3;
                    endcase
                end
            end else begin
                PREADY <= 1'b0;
            end
        end
    end

endmodule

module GPI (
    input  logic [7:0] modeR,
    output logic [7:0] idR,
    input  logic [7:0] inPort
);
    genvar i;

    generate
        for (i = 0; i < 8; i++) begin
            assign idR[i] = ~modeR[i] ? inPort[i] : 1'bz;
        end
    endgenerate
/*
    always_comb begin 
        for (i = 0; i < 8; i++) begin
            assign outPort[i] = modeR[i] ? odR[i] : 1'bz;
        end
    end
*/
endmodule