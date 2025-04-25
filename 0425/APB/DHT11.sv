`timescale 1ns / 1ps

module DHT11_Periph (
    // global signal
    input  logic        clk,
    input  logic        reset,
    // APB Interface Signals
    input  logic [ 3:0] PADDR,
    input  logic [31:0] PWDATA,
    input  logic        PWRITE,
    input  logic        PENABLE,
    input  logic        PSEL,
    output logic [31:0] PRDATA,
    output logic        PREADY,
    // export signals
    output logic [7:0] humidity,
    output logic [7:0] temperature
);
    logic trigr;
    logic odr;
    logic ipr;

    APB_SlaveIntf_DHT11 U_APB_Intf_DHT11 (.*);
    DHT11 U_DHT11_IP (.*);
endmodule

module APB_SlaveIntf_DHT11 (
    // global signal
    input  logic        clk,
    input  logic        reset,
    // APB Interface Signals
    input  logic [ 3:0] PADDR,
    input  logic [31:0] PWDATA,
    input  logic        PWRITE,
    input  logic        PENABLE,
    input  logic        PSEL,
    output logic [31:0] PRDATA,
    output logic        PREADY,
    // internal signals
    output logic        trigr,    // control
    output logic        odr,    
    input  logic        idr    
);
    logic [31:0] slv_reg0, slv_reg1, slv_reg2; //, slv_reg2, slv_reg3;

    assign trigr = slv_reg0[0];
    assign odr = slv_reg1[0];
    assign slv_reg2[0] = idr;

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            slv_reg0 <= 0;
            slv_reg1 <= 0;
            //slv_reg2 <= 0;
            // slv_reg3 <= 0;
        end else begin
            if (PSEL && PENABLE) begin
                PREADY <= 1'b1;
                if (PWRITE) begin
                    case (PADDR[3:2])
                        2'd0: slv_reg0 <= PWDATA;
                        2'd1: slv_reg1 <= PWDATA;
                        //2'd2: slv_reg2 <= PWDATA;
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

module DHT11 (
    input  logic        PCLK,
    input  logic        PRESET,
    // input 
    input  logic        trigr,
    input  logic        odr,
    output logic        idr,
    // output 
    output logic [ 7:0] humidity,
    output logic [ 7:0] temperature
);
    logic tick;
    
    tick_gen_DHT11 U_tick_gen(
        .clk(PCLK),
        .reset(PRESET),
        .tick(tick)
    );

    DHT11_CU U_DHT11_CU(
        .clk(PCLK),         
        .reset(PRESET),       
        .btn_start(trigr),   
        .tick(tick),        
        .dht_io(),      
        .humidity(humidity), 
        .temperature(temperature)
    );
    
endmodule

module DHT11_CU (
    input  logic       clk,          // 100mhz on fpga oscillator
    input  logic       reset,        // reset btn
    input  logic       btn_start,         // start trigger       
    input  logic       tick,
    inout  logic       dht_io,       
    output logic [7:0] humidity, 
    output logic [7:0] temperature
);
    parameter   SEND            = 1800, // FPGA to DHT11 trigger send
                WAIT_RESPONSE   = 3 ,   // wait for responce from dht11
                SYNC            = 8,    // wait for transieve
                DATA_COMMON     = 5,  // common low with s  
                DATA_STANDARD   = 4,  // 40us 기준  -> 짧으면 0, 길면 1
                STOP            = 5,  // 데이터 다 받고 다시 high 상태 가기전 대기시간
                BIT_DHT11       = 40, // 40비트 데이터비트
                TIME_OUT        = 2000;

    // 1. state definition
    localparam  IDLE            = 0, // 초기상태
                START           = 1, // 입력 trigger
                WAIT            = 2, // 응답 대기
                SYNC_LOW        = 3, // dht11로 부터 응답 받음
                SYNC_HIGH       = 4, // 데이터 송수신전 대기
                DATA_SYNC       = 5, // 온습도 데이터(40bit) 송수신
                DATA_DECISION   = 6, // 통신 종료후 다시 high로로
                DONE            = 7; // 데이터 송수신 종료 후 다시 PULL UP HIGH 상태로로

    // register for CU
    logic [2:0] state, next;
    logic [$clog2(TIME_OUT)-1:0] count_reg, count_next;

    logic io_out_reg, io_out_next;    // 
    logic io_oe_reg, io_oe_next;      // for 3-state buffer enable 

    logic [5:0] bit_count_reg, bit_count_next;  // for count 40 bit 
    logic [39:0] data_reg, data_next; // store data register

    // out 3 state on/off
    assign dht_io = (io_oe_reg) ? io_out_reg :1'bz;

    // assign humidity , temperature
    assign humidity = data_reg [39:32]; // data 중 습도 정수부분
    assign temperature = data_reg [23:16]; // data 중 온도 정수 부분

    // 2. for continue next state
    always_ff @(posedge clk, posedge reset) begin
        if(reset) begin
            state               <= IDLE;
            count_reg           <= 0;
            bit_count_reg       <= 0;  
            data_reg            <= 0;  
            io_out_reg          <= 1'b1;
            io_oe_reg           <= 0;
        end
        else begin
            state               <= next;
            count_reg           <= count_next;
            bit_count_reg       <= bit_count_next;  
            data_reg            <= data_next; 
            io_out_reg          <= io_out_next;
            io_oe_reg           <= io_oe_next;
        end
    end
    
    // 3. output combinational logic
    always_comb begin
        next                 = state;
        count_next           = count_reg;
        io_out_next          = io_out_reg;
        io_oe_next           = io_oe_reg;
        bit_count_next       = bit_count_reg;
        data_next            = data_reg;

        case (state)
            IDLE : begin // 0
                io_out_next = 1'b1;
                io_oe_next  = 1'b1;

                if (btn_start == 1'b1) begin
                    next       = START;
                    count_next = 0;
                end
            end

            START : begin // 1
                io_out_next = 1'b0;

                if(tick == 1'b1)begin
                    if(count_reg == SEND -1) begin                        
                        next       = WAIT;
                        count_next = 0;
                    end
                    else begin                     
                        count_next = count_reg + 1;
                    end
                end
            end

            WAIT : begin // 2
                io_out_next = 1'b1;

                if(tick == 1'b1) begin
                    if(count_reg == WAIT_RESPONSE - 1) begin
                        next       = SYNC_LOW;
                        io_oe_next = 1'b0;
                        count_next = 0;
                    end
                    else begin
                        count_next = count_reg + 1;
                    end
                end
            end

            SYNC_LOW : begin // 3
                if(tick == 1'b1) begin
                    if(count_reg == 1) begin
                        if(dht_io == 1'b1) begin
                            next = SYNC_HIGH;
                        end
                    count_next = 0;
                    end
                    else begin
                        count_next = count_reg + 1;
                    end
                end
            end

            SYNC_HIGH : begin // 4
                if(tick == 1'b1) begin
                    if(count_reg == 1) begin
                        if(dht_io == 1'b0) begin
                            next = DATA_SYNC;
                        end
                    count_next = 0;
                    end
                    else begin
                        count_next = count_reg + 1;
                    end
                end
            end
            
            DATA_SYNC : begin // 5
                if(tick == 1'b1) begin
                    if(count_reg == 1) begin
                        if(dht_io == 1'b1) begin
                            next = DATA_DECISION;
                        end
                    count_next = 0;
                    end
                    else begin
                        count_next = count_reg + 1;
                    end
                end
            end

           DATA_DECISION: begin // 6
                if (tick == 1'b1) begin 
                    if (dht_io == 1'b1) begin
                        count_next = count_reg + 1;  // HIGH 지속 시간 측정\
                    end
                    else begin
                        if (count_reg <= DATA_STANDARD - 1) begin
                            data_next = {data_reg[38:0], 1'b0};  // 40µs보다 짧으면 0
                        end
                        else begin
                            data_next = {data_reg[38:0], 1'b1};  // 40µs보다 길면 1
                        end

                        bit_count_next = bit_count_reg + 1;
                        count_next = 0;  // 다음 비트를 위해 카운터 초기화

                        if (bit_count_reg == BIT_DHT11 - 1) begin
                            next = DONE;  // 40비트 수집 완료 후 DONE 상태로 이동
                            bit_count_next = 0;
                        end
                        else begin
                            next = DATA_SYNC;  // 다음 비트 수집을 위해 DATA_SYNC로 다시 이동
                        end
                    end
                end
            end

            DONE : begin // 7
                if (tick == 1'b1) begin
                    if(count_reg == STOP - 1) begin
                        next = IDLE;
                        io_out_next = 1'b1;
                        io_oe_next = 1'b1;  // pull-up 유지
                        count_next = 0;
                    end
                    else begin
                        count_next = count_reg + 1;
                    end
                end
            end
        endcase        
    end
endmodule

module tick_gen_DHT11(
    input  logic clk,
    input  logic reset,
    output logic tick
    );

    localparam TICK_COUNT = 1_000; // 10us tick gen
    
    logic [$clog2(TICK_COUNT)-1:0] cnt_reg, cnt_next;
    logic tick_reg, tick_next;

    assign tick = tick_reg;

    always_ff @(posedge clk, posedge reset) begin
        if(reset) begin
            tick_reg <= 1'b0;
            cnt_reg <= 0;
        end
        else begin
            cnt_reg <= cnt_next;
            tick_reg <= tick_next;
        end 
    end

    always_comb begin
        
        cnt_next = cnt_reg;
        tick_next = tick_reg;
                
        if(cnt_reg == TICK_COUNT-1) begin
            cnt_next = 0;
            tick_next = 1'b1; 
        end
        else begin
            cnt_next = cnt_reg + 1;
            tick_next = 1'b0;
        end
    end
endmodule