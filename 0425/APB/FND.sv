`timescale 1ns / 1ps

module FND_COUNT_Periph (
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
    logic        fcr;
    logic [13:0] fdr;
    logic [ 3:0] fpr;

    APB_SlaveIntf_FND_COUNT U_APB_Intf_FND_CNT (.*);
    FND_COUNT U_FND_COUNT_IP (.*);
endmodule

module APB_SlaveIntf_FND_COUNT (
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
    output logic        fcr,    // control
    output logic [13:0] fdr,     // data
    output logic [ 3:0] fpr
);
    logic [31:0] slv_reg0, slv_reg1, slv_reg2; //, slv_reg2, slv_reg3;

    assign fcr = slv_reg0[0];
    assign fdr = slv_reg1[13:0];
    assign fpr = slv_reg2[3:0];

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

module FND_COUNT (
    input  logic        PCLK,
    input  logic        PRESET,
    // input 
    input  logic        fcr,
    input  logic [13:0] fdr,
    input  logic [ 3:0] fpr,
    // output 
    output logic [ 3:0] fnd_comm,
    output logic [ 7:0] fnd_font
);
 
    logic tick, fndDp;
    logic [1:0] digit_sel;
    logic [3:0] digit_1, digit_10, digit_100, digit_1000;
    logic [3:0] bcd;
    logic [7:0] fndSegData;
    logic [3:0] fndCom;

    assign fnd_font = {fndDp, fndSegData[6:0]};
    assign fnd_comm = fcr ? fndCom : 4'b1111;

    clk_div_1khz U_clk_div_1khz(
        .clk(PCLK),
        .reset(PRESET),
        .tick(tick)
    );

    counter_2bit U_counter_2bit(
        .clk(PCLK),
        .reset(PRESET),
        .tick(tick),
        .count(digit_sel)
    ); 

    decoder_2x4 U_decoder_2x4(
        .x(digit_sel),
        .y(fndCom)
    ); 

    digit_splitter U_digit_splitter(
        .data(fdr),
        .digit_1(digit_1),
        .digit_10(digit_10),
        .digit_100(digit_100),
        .digit_1000(digit_1000)
    ); 

    mux_4x1 U_mux_4x1(
        .sel(digit_sel),
        .x_0(digit_1),
        .x_1(digit_10),
        .x_2(digit_100),
        .x_3(digit_1000),
        .y(bcd)  
    );

    bcdtoseg U_bcdtoseg(
        .bcd(bcd), 
        .seg(fndSegData)
    );

    mux_4x1_1bit U_Mux_4x1_1bit (
        .sel(digit_sel),
        .x  (fpr),
        .y  (fndDp)
    );
endmodule
 
module clk_div_1khz (
    input  logic  clk,
    input  logic  reset,
    output logic  tick
);
    logic [$clog2(100_000)-1:0] cnt;

    always_ff @(posedge clk, posedge reset) begin
        if(reset) begin
                cnt     <= 0;
                tick    <= 1'b0;
        end
        else begin
            if(cnt == 100_000 - 1) begin
                cnt     <= 0;
                tick    <= 1'b1; 
            end
            else begin
                cnt     <= cnt + 1;
                tick    <= 1'b0;
            end
        end
    end    
endmodule

module counter_2bit (
    input  logic       clk,
    input  logic       reset,
    input  logic       tick,
    output logic [1:0] count
);
    always_ff @(posedge clk, posedge reset) begin
        if(reset) begin
            count <= 0;
        end
        else begin
            if(tick) begin
                count <= count + 1;
            end
        end       
    end    
endmodule
 
module decoder_2x4 (
    input  logic [1:0] x,
    output logic [3:0] y
);   
    always_comb begin
        case(x)
        2'b00   : y = 4'b1110;
        2'b01   : y = 4'b1101;
        2'b10   : y = 4'b1011;
        2'b11   : y = 4'b0111;
        default : y = 4'b1110; 
        endcase       
    end
endmodule

module digit_splitter (
    input  logic [$clog2(10_000)-1:0] data,
    output logic [3:0] digit_1,
    output logic [3:0] digit_10,
    output logic [3:0] digit_100,
    output logic [3:0] digit_1000
);
    assign digit_1      = data % 10;
    assign digit_10     = data / 10 % 10;
    assign digit_100    = data / 100 % 10;
    assign digit_1000   = data / 1000 % 10;
endmodule

module mux_4x1 (
    input   logic [1:0] sel,
    input   logic [3:0] x_0,
    input   logic [3:0] x_1,
    input   logic [3:0] x_2,
    input   logic [3:0] x_3,
    output  logic [3:0] y
);
    always_comb begin
        case(sel)
        2'b00 :   y = x_0;
        2'b01 :   y = x_1;
        2'b10 :   y = x_2;
        2'b11 :   y = x_3;
        default : y = 4'hf;
        endcase
    end    
endmodule

module bcdtoseg(
    input  logic [3:0] bcd, 
    output logic [7:0] seg
);
    always_comb begin
        case (bcd)
            4'h0:    seg = 8'hc0;
            4'h1:    seg = 8'hF9;
            4'h2:    seg = 8'hA4;
            4'h3:    seg = 8'hB0;
            4'h4:    seg = 8'h99;
            4'h5:    seg = 8'h92;
            4'h6:    seg = 8'h82;
            4'h7:    seg = 8'hf8;
            4'h8:    seg = 8'h80;
            4'h9:    seg = 8'h90;
            4'hA:    seg = 8'h88;
            4'hB:    seg = 8'h83;
            4'hC:    seg = 8'hc6;
            4'hD:    seg = 8'ha1;
            4'hE:    seg = 8'h7f;
            4'hF:    seg = 8'hff;
            default: seg = 8'hff;
        endcase
    end
endmodule

module mux_4x1_1bit (
    input  logic [1:0] sel,
    input  logic [3:0] x,
    output logic       y
);

    always_comb begin
        y = 1'b1;
        case (sel)
            2'b00: y = x[0];
            2'b01: y = x[1];
            2'b10: y = x[2];
            2'b11: y = x[3];
        endcase
    end
endmodule