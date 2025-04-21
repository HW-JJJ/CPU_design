`timescale 1ns / 1ps

module MCU (
    input  logic       clk,
    input  logic       reset,
    output logic [7:0] GPO_A,
    input  logic [7:0] GPI_B
);
    // APB_MASTER
    logic        PCLK;
    logic        PRESET;
    logic [31:0] PADDR;
    logic [31:0] PWDATA;
    logic        PWRITE;
    logic        PENABLE;
    logic        PSEL_RAM;
    logic        PSEL_GPO;
    logic        PSEL_GPI;
    logic        PSEL3;
    logic [31:0] PRDATA_RAM;
    logic [31:0] PRDATA_GPO;
    logic [31:0] PRDATA_GPI;
    logic [31:0] PRDATA3;
    logic        PREADY_RAM;
    logic        PREADY_GPO;
    logic        PREADY_GPI;
    logic        PREADY3;
    
    // common
    logic        transfer;  
    logic        ready;
    
    // RV32I CORE
    logic [31:0] instrCode;
    logic [31:0] instrMemAddr;
    logic        dataWe;
    logic [31:0] dataAddr;
    logic [31:0] dataWData;
    logic [31:0] dataRData;

    logic [31:0] addr;
    logic [31:0] wdata;
    logic [31:0] rdata;
    logic        write;     

    assign PCLK   = clk;
    assign PRESET = reset;
    assign addr  =  dataAddr;
    assign wdata = dataWData;
    assign dataRData = rdata;
    assign write = dataWe;

    RV32I_Core U_Core (.*);

    rom U_ROM (
        .addr(instrMemAddr),
        .data(instrCode)
    );

    APB_Master U_APB_Master(
        .*,
        .PSEL0(PSEL_RAM),
        .PSEL1(PSEL_GPO),
        .PSEL2(PSEL_GPI),
        .PSEL3(),
        .PRDATA0(PRDATA_RAM),
        .PRDATA1(PRDATA_GPO),
        .PRDATA2(PRDATA_GPI),
        .PRDATA3(),
        .PREADY0(PREADY_RAM),
        .PREADY1(PREADY_GPO),
        .PREADY2(PREADY_GPI),
        .PREADY3()
    );

    ram U_RAM (
        .*,
        .PSEL(PSEL_RAM),
        .PRDATA(PRDATA_RAM),
        .PREADY(PREADY_RAM)
    );

    GPO_Periph U_GPO_A(
        .*,
        .PSEL(PSEL_GPO),
        .PRDATA(PRDATA_GPO),
        .PREADY(PREADY_GPO),
        .outPort(GPO_A)
    );

    GPI_Periph U_GPI_B(
        .*,
        .PSEL(PSEL_GPI),
        .PRDATA(PRDATA_GPI),
        .PREADY(PREADY_GPI),
        .inPort(GPI_B)
);
endmodule