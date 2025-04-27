`timescale 1ns / 1ps

module FIFO_Periph(
    // global signals
    input  logic        PCLK,
    input  logic        PRESET,
    // APB interface signals
    input  logic [3:0]  PADDR,
    input  logic [31:0] PWDATA,
    input  logic        PWRITE,
    input  logic        PENABLE,
    input  logic        PSEL,
    output logic [31:0] PRDATA,
    output logic        PREADY
);
    logic [1:0]  fsr;  
    logic [7:0]  fwd;  
    logic [7:0]  frd;
    
    logic        wr_en;
    logic        rd_en;

    APB_SlaveIntf_FIFO U_APB_SlaveIntf_FIFO(.*);
    FIFO               U_FIFO(.*);
endmodule

module APB_SlaveIntf_FIFO (
    // global
    input  logic        PCLK,
    input  logic        PRESET,
    // APB
    input  logic [3:0]  PADDR,
    input  logic [31:0] PWDATA,
    input  logic        PWRITE,
    input  logic        PENABLE,
    input  logic        PSEL,
    output logic [31:0] PRDATA,
    output logic        PREADY,
    // FIFO
    input  logic [1:0]  fsr,      // {empty, full}
    output logic [7:0]  fwd,      // write data
    input  logic [7:0]  frd,      // read data

    output logic        wr_en,
    output logic        rd_en
);
    logic [31:0] slv_reg0, slv_reg1, slv_reg2;

    assign slv_reg0[1:0] = fsr;
    assign fwd = slv_reg1[7:0];
    assign slv_reg2[7:0] = frd;

    typedef enum logic [1:0] {
        IDLE   = 2'd0,
        SETUP  = 2'd1,
        ACCESS = 2'd2
    } state_t;

    state_t state;

    always_ff @(posedge PCLK or posedge PRESET) begin
        if (PRESET) begin
            state <= IDLE;
            wr_en <= 1'b0;
            rd_en <= 1'b0;
            //slv_reg0 <= 0;
            slv_reg1 <= 0;
            //slv_reg2 <= 0;
            //slv_reg3 <= 0;
            wr_en <= 1'b0;
            rd_en <= 1'b0;
            PREADY <= 1'b0;
        end 
        else begin
            case (state)
                IDLE: begin
                    wr_en <= 1'b0;
                    rd_en <= 1'b0;

                    if (PSEL && !PENABLE) begin
                        state <= SETUP;
                    end
                end

                SETUP: begin
                    if (PSEL && PENABLE) begin
                        state <= ACCESS;
                    end
                end

                ACCESS: begin
                    PREADY <= 1'b1;

                    if (PWRITE) begin
                        wr_en <= 1'b1;

                        case (PADDR[3:2])
                            //2'd0: slv_reg0 <= PWDATA;
                            2'd1: slv_reg1 <= PWDATA;
                            //2'd2: slv_reg2 <= PWDATA;
                            // 2'd3: slv_reg3 <= PWDATA;
                        endcase
                    end 
                    else begin
                        PRDATA <= 32'b0;
                        rd_en <= 1'b1;

                        case (PADDR[3:2])
                            2'd0: PRDATA <= slv_reg0;
                            2'd1: PRDATA <= slv_reg1;
                            2'd2: PRDATA <= slv_reg2;
                            // 2'd3: PRDATA <= slv_reg3;
                        endcase
                    end
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule

module FIFO (
    input  logic       PCLK,
    input  logic       PRESET,
    // full empty
    output logic       fsr,
    // wdata
    input  logic [7:0] fwd,
    input  logic       wr_en,
    // rdata
    input  logic       rd_en,
    output logic [7:0] frd
);
    logic [1:0] wr_ptr, rd_ptr; 
    logic empty, full;

    assign fsr = {empty,full};

    ram_FIFO U_ram_FIFO(
        .clk(PCLK),
        .wAddr(wr_ptr),
        .wdata(fwd),
        .wr_en(~full & wr_en),
        .rAddr(rd_ptr),
        .rdata(frd)
    );

    FIFO_CU U_FIFO_CU(
        .clk(PCLK),
        .reset(PRESET),
        .wr_ptr(wr_ptr),
        .wr_en(wr_en),
        .full(full),        
        .rd_ptr(rd_ptr),
        .rd_en(rd_en),
        .empty(empty)
    );
endmodule

module ram_FIFO (
    input  logic       clk,
    input  logic [1:0] wAddr,
    input  logic [7:0] wdata,
    input  logic       wr_en,
    input  logic [1:0] rAddr,
    output logic [7:0] rdata
);
    logic [7:0] mem[0:2**2-1]; // 8bit mem x 4

    always_ff @( posedge clk ) begin
        if (wr_en) 
            mem[wAddr] <= wdata;
    end

    assign rdata =  mem[rAddr];
endmodule

module FIFO_CU (
    input  logic clk,
    input  logic reset,
    // write side
    output logic [1:0] wr_ptr,
    input  logic       wr_en,
    output logic       full,
    // read side
    output logic [1:0] rd_ptr,
    input  logic       rd_en,
    output logic       empty
);
    localparam  READ  = 2'b01, 
                WRITE = 2'b10, 
                READ_WRITE = 2'b11; 

    logic [1:0] fifo_state;

    logic empty_reg, empty_next;
    logic full_reg, full_next;
    logic [1:0] wr_ptr_reg, wr_ptr_next;
    logic [1:0] rd_ptr_reg, rd_ptr_next;

    assign fifo_state = {wr_en, rd_en};
    assign full   = full_reg;
    assign empty  = empty_reg;
    assign wr_ptr = wr_ptr_reg;
    assign rd_ptr = rd_ptr_reg;

    always_ff @( posedge clk, posedge reset ) begin 
        if ( reset ) begin
            wr_ptr_reg    <= 0;
            rd_ptr_reg    <= 0;
            full_reg  <= 1'b0;
            empty_reg <= 1'b1; 
        end
        else begin
            full_reg   <= full_next;
            empty_reg  <= empty_next;
            wr_ptr_reg <= wr_ptr_next;
            rd_ptr_reg <= rd_ptr_next;
        end
    end

    always_comb begin
        full_next   = full_reg;
        empty_next  = empty_reg;
        wr_ptr_next = wr_ptr_reg;
        rd_ptr_next = rd_ptr_reg;

        case (fifo_state)
            READ : begin
                if (empty_reg == 1'b0) begin
                    full_next = 1'b0;
                    rd_ptr_next = rd_ptr_reg + 1;

                    if (rd_ptr_next ==  wr_ptr_reg) begin
                        empty_next = 1'b1;
                    end
                end
            end 

            WRITE : begin
                if ( full_reg == 1'b0 ) begin
                    empty_next  = 1'b0;
                    wr_ptr_next = wr_ptr_reg + 1;

                    if (wr_ptr_next == rd_ptr_reg) begin
                        full_next = 1'b1;
                    end
                end
            end

            READ_WRITE : begin
                if (empty_reg == 1'b1) begin
                    wr_ptr_next = wr_ptr_reg + 1;
                    empty_next = 1'b0;
                end
                else if (full_reg == 1'b1) begin
                    rd_ptr_next = rd_ptr_reg + 1;
                    full_next = 1'b0;
                end
                else begin
                    wr_ptr_next = wr_ptr_reg + 1;
                    rd_ptr_next = rd_ptr_reg + 1;
                end
            end
        endcase        
    end
endmodule