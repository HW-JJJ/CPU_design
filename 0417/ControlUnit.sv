`timescale 1ns / 1ps

`include "defines.sv"

module ControlUnit (
    input  logic        clk,
    input  logic        reset,
    input  logic [31:0] instrCode,
    output logic        regFileWe,
    output logic [ 3:0] aluControl,
    output logic        aluSrcMuxSel,
    output logic        dataWe,
    output logic [ 2:0] RFWDSrcMuxSel,
    output logic        branch,
    output logic        jal,
    output logic        jalr,
    output logic        pcEn
);
    wire [6:0] opcode = instrCode[6:0];
    wire [3:0] operators = {
        instrCode[30], instrCode[14:12]
    };  // {func7[5], func3}

    logic [9:0] signals;
    assign {pcEn, regFileWe, aluSrcMuxSel, dataWe, RFWDSrcMuxSel, branch, jal, jalr} = signals;

    typedef enum  { FETCH,  // 0
                    DECODE, // 1
                    R_EXE , // 2
                    I_EXE,  // 3
                    B_EXE,  // 4
                    LU_EXE, // 5
                    AU_EXE, // 6
                    J_EXE,  // 7 
                    JL_EXE, // 8
                    S_EXE,  // 9
                    S_MEM,  // 10
                    L_EXE,  // 11
                    L_MEM,  // 12
                    L_WB   } state_e; // 13

    state_e state, next;

    always_ff @( posedge clk, posedge reset) begin
        if (reset)
            state <= FETCH;
        else
            state <= next;
    end

    always_comb begin 
        next = state;

        case(state)
            
            FETCH : next = DECODE;
            
            DECODE : begin // 타입을 판단해 어디로 넘어갈지만 정하는 부분분
                case (opcode)
                    `OP_TYPE_R  : next = R_EXE;
                    `OP_TYPE_S  : next = S_EXE;
                    `OP_TYPE_L  : next = L_EXE;
                    `OP_TYPE_I  : next = I_EXE;
                    `OP_TYPE_B  : next = B_EXE;
                    `OP_TYPE_LU : next = LU_EXE;
                    `OP_TYPE_AU : next = AU_EXE;
                    `OP_TYPE_J  : next = J_EXE;
                    `OP_TYPE_JL : next = JL_EXE;
                endcase
            end

            R_EXE  : next = FETCH;
            S_EXE  : next = S_MEM;
            S_MEM  : next = FETCH;
            L_EXE  : next = L_MEM;
            L_MEM  : next = L_WB;
            L_WB   : next = FETCH;
            I_EXE  : next = FETCH;
            B_EXE  : next = FETCH;
            LU_EXE : next = FETCH;
            AU_EXE : next = FETCH;
            J_EXE  : next = FETCH;
            JL_EXE : next = FETCH;
        endcase
    end

    always_comb begin 
        signals = 10'd0;
        aluControl = operators;

        case (state)
        // {pcEn, regFileWe, aluSrcMuxSel, dataWe, RFWDSrcMuxSel(3), branch, jal, jalr} = signals
            FETCH   : signals = 10'b1_0_0_0_000_0_0_0;
            DECODE  : signals = 10'b0_0_0_0_000_0_0_0;
            R_EXE   : signals = 10'b0_1_0_0_000_0_0_0;
            S_EXE   : begin
                signals     = 10'b0_0_1_0_000_0_0_0;
                aluControl  = `ADD;
            end
            S_MEM  : signals    = 10'b0_0_1_1_000_0_0_0;
            L_EXE  : begin
                signals     = 10'b0_0_1_0_001_0_0_0;
                aluControl  = `ADD;
            end
            L_MEM  : signals = 10'b0_0_1_0_001_0_0_0;
            L_WB   : signals = 10'b0_1_1_0_001_0_0_0;
            I_EXE  : begin
                signals = 10'b0_1_1_0_000_0_0_0;

                if (operators == 4'b1101)
                    aluControl = operators;  // {1'b1, func3}
                else aluControl = {1'b0, operators[2:0]};
            end
            B_EXE  : signals = 10'b0_0_0_0_000_1_0_0;
            LU_EXE : signals = 10'b0_1_0_0_010_0_0_0;
            AU_EXE : signals = 10'b0_1_0_0_011_0_0_0;
            J_EXE  : signals = 10'b0_1_0_0_100_0_1_0;
            JL_EXE : begin
                signals = 10'b0_1_0_0_100_0_1_1;
                aluControl = `ADD;
            end
        endcase
    end

/*
    always_comb begin
        signals = 10'b0;
        case (opcode)
            // {pcEn, regFileWe, aluSrcMuxSel, dataWe, RFWDSrcMuxSel(3), branch, jal, jalr} = signals
            `OP_TYPE_R:  signals = 10'b1_0_0_000_0_0_0;
            `OP_TYPE_S:  signals = 10'b0_1_1_000_0_0_0;
            `OP_TYPE_L:  signals = 10'b1_1_0_001_0_0_0;
            `OP_TYPE_I:  signals = 10'b1_1_0_000_0_0_0;
            `OP_TYPE_B:  signals = 10'b0_0_0_000_1_0_0;
            `OP_TYPE_LU: signals = 10'b1_0_0_010_0_0_0;
            `OP_TYPE_AU: signals = 10'b1_0_0_011_0_0_0;
            `OP_TYPE_J:  signals = 10'b1_0_0_100_0_1_0;
            `OP_TYPE_JL: signals = 10'b1_0_0_100_0_1_1;
        endcase
    end

    always_comb begin
        aluControl = 4'bx;
        case (opcode)
            `OP_TYPE_S:  aluControl = `ADD;
            `OP_TYPE_L:  aluControl = `ADD;
            `OP_TYPE_JL: aluControl = `ADD;  // {func7[5], func3}
            `OP_TYPE_I: begin
                if (operators == 4'b1101)
                    aluControl = operators;  // {1'b1, func3}
                else aluControl = {1'b0, operators[2:0]};  // {1'b0, func3}
            end
            default : aluControl = operators;  // {func7[5], func3}
            // `OP_TYPE_R:  aluControl = operators;  // {func7[5], func3}
            // `OP_TYPE_B:  aluControl = operators;  // {func7[5], func3}
            // `OP_TYPE_LU: aluControl = operators;  // {func7[5], func3}
            // `OP_TYPE_AU: aluControl = operators;  // {func7[5], func3}
            // `OP_TYPE_J:  aluControl = operators;  // {func7[5], func3}
        endcase
    end
*/
endmodule