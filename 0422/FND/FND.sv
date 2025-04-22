`timescale 1ns / 1ps

module FND_Periph (
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
    output logic [3:0] fnd_comm,
    output logic [7:0] fnd_font
);

    logic       fcr;
    logic [3:0] fmr;
    logic [3:0] fdr;

    APB_SlaveIntf_FND U_APB_Intf (.*);
    FND U_FND_IP (.*);
endmodule

module APB_SlaveIntf_FND (
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
    output logic [ 7:0] fcr,    // control
    output logic [ 7:0] fmr,    // common
    output logic [ 7:0] fdr     // data
);
    logic [31:0] slv_reg0, slv_reg1, slv_reg2; //, slv_reg2, slv_reg3;

    assign fcr = slv_reg0[0];
    assign fmr = slv_reg1[3:0];
    assign fdr = slv_reg2[3:0];

    always_ff @(posedge PCLK, posedge PRESET) begin
        if (PRESET) begin
            slv_reg0 <= 0;
            slv_reg1 <= 0;
            slv_reg2 <= 0;
            // slv_reg3 <= 0;
        end else begin
            if (PSEL && PENABLE) begin
                PREADY <= 1'b1;
                if (PWRITE) begin
                    case (PADDR[3:2])
                        2'd0: slv_reg0 <= PWDATA;
                        2'd1: slv_reg1 <= PWDATA;
                        2'd2: slv_reg2 <= PWDATA;
                        // 2'd3: slv_reg3 <= PWDATA;
                    endcase
                end else begin
                    PRDATA <= 32'bx;
                    case (PADDR[3:2])
                        2'd0: PRDATA <= slv_reg0;
                        2'd1: PRDATA <= slv_reg1;
                        2'd2: PRDATA <= slv_reg2;
                        // 2'd3: PRDATA <= slv_reg3;
                    endcase
                end
            end else begin
                PREADY <= 1'b0;
            end
        end
    end

endmodule

module FND (
    // input 
    input  logic       fcr,
    input  logic [3:0] fmr,
    input  logic [3:0] fdr,
    // output 
    output logic [3:0] fnd_comm,
    output logic [7:0] fnd_font
);
    assign fnd_comm = fcr ? ~fmr : 4'b1111;

    always_comb begin           
        case (fdr)
            4'h0: fnd_font = 8'hc0;
            4'h1: fnd_font = 8'hF9;
            4'h2: fnd_font = 8'hA4;
            4'h3: fnd_font = 8'hB0;
            4'h4: fnd_font = 8'h99;
            4'h5: fnd_font = 8'h92;
            4'h6: fnd_font = 8'h82;
            4'h7: fnd_font = 8'hf8;
            4'h8: fnd_font = 8'h80;
            4'h9: fnd_font = 8'h90;
            4'hA: fnd_font = 8'h88;
            4'hB: fnd_font = 8'h83;
            4'hC: fnd_font = 8'hc6;
            4'hD: fnd_font = 8'ha1;
            4'hE: fnd_font = 8'h86;
            4'hF: fnd_font = 8'h8E;
            default : fnd_font = 8'hff;
        endcase
    end
endmodule