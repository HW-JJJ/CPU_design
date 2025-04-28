module ULTRASONIC_Periph (
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
    input  logic        echo,
    output logic        trigger_tick
);
    logic       ucr;
    logic [8:0] distance;

    APB_SlaveIntf_ULTRASONIC U_APB_Intf_ULTRASONIC (.*);
    ULTRASONIC U_ULTRASONIC_IP (.*);
endmodule

module APB_SlaveIntf_ULTRASONIC (
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
    output logic        ucr,       // control
    input  logic [ 8:0] distance   // distance (cm)
);
    logic [31:0] slv_reg0, slv_reg1; 

    assign ucr = slv_reg0[0];
    assign slv_reg1[8:0] = distance;

    always_ff @(posedge PCLK, posedge PRESET) begin
        if (PRESET) begin
            slv_reg0 <= 0;
            //slv_reg1 <= 0;
            //slv_reg2 <= 0;
            //slv_reg3 <= 0;
        end else begin
            if (PSEL && PENABLE) begin
                PREADY <= 1'b1;
                if (PWRITE) begin
                    case (PADDR[3:2])
                        2'd0: slv_reg0 <= PWDATA;
                        // 2'd1: slv_reg1 <= PWDATA;
                        // 2'd2: slv_reg2 <= PWDATA;
                        // 2'd3: slv_reg3 <= PWDATA;
                    endcase
                end else begin
                    PRDATA <= 32'bx;
                    case (PADDR[3:2])
                        2'd0: PRDATA <= slv_reg0;
                        2'd1: PRDATA <= slv_reg1;
                        //2'd2: PRDATA <= slv_reg2;
                        // 2'd3: PRDATA <= slv_reg3;
                    endcase
                end
            end else begin
                PREADY <= 1'b0;
            end
        end
    end
endmodule

module ULTRASONIC (
    input  logic       PCLK,
    input  logic       PRESET,
    input  logic       ucr,
    input  logic       echo,
    output logic       trigger_tick,
    output logic [8:0] distance
);
    logic tick;
    logic [14:0] echo_count;

    tick_gen U_tick_gen(
        .clk(PCLK),
        .reset(PRESET),
        .tick(tick)
    );

    ultrasonic_cu U_ultrasonic_cu(
        .clk(PCLK),
        .reset(PRESET),
        .start_trigger(ucr),
        .tick(tick),
        .echo(echo),
        .trigger_tick(trigger_tick),
        .echo_count(echo_count)
    );

    distance_caculator U_distance_caculator(
        .clk(PCLK),
        .reset(PRESET),
        .echo(er),
        .echo_count(echo_count),
        .distance(distance)
    );
endmodule

module ultrasonic_cu(
    input  logic clk,
    input  logic reset,
    input  logic start_trigger,
    input  logic tick,
    input  logic echo,
    output logic trigger_tick,
    output logic [14:0] echo_count
);
    localparam  IDLE = 2'b00,
                START = 2'b01,
                WAIT = 2'b10,
                HIGH_LEVEL_COUNT = 2'b11;

    logic [1:0] state, next;
    logic [3:0] tick_count_reg, tick_count_next;
    logic [14:0] echo_count_reg, echo_count_next;
    logic tick_reg, tick_next;

    assign trigger_tick = tick_reg;
    assign echo_count =  echo_count_reg;

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            state <= IDLE;
            tick_count_reg <= 0;
            echo_count_reg <= 0;
            tick_reg <= 0;
        end
        else begin
            state <= next;
            tick_count_reg <= tick_count_next;
            echo_count_reg <= echo_count_next;
            tick_reg <= tick_next;
        end
    end

    always_comb begin
        next = state;
        tick_next = tick_reg;   // 10us trigger pulse를 위한
        tick_count_next = tick_count_reg;  // 10us trigger를 위해 1us 10개 세기 위해
        echo_count_next = echo_count_reg;  // echo pulse의 주기 계산산

        case(state)  // IDLE : START 버튼 누르면 TRIG 상태로로
            IDLE : begin

               if (start_trigger == 1'b1) begin
                    next = START;
                    echo_count_next = 0;
                end               
            end

            START : begin                           
                if(tick == 1'b1) begin
                    if(tick_count_reg == 10) begin
                        tick_next = 1'b0;
                        tick_count_next = 0;
                        next = WAIT;  // 10us 펄스 반복을 막기위해 바로 다음 상태로 넘겨주기
                    end          
                    else begin
                        tick_next = 1'b1;
                        tick_count_next = tick_count_reg + 1;           
                    end
                end  
            end

            WAIT : begin
                if(echo == 1'b1)
                    next = HIGH_LEVEL_COUNT;
            end

            HIGH_LEVEL_COUNT : begin // ECHO 펄스가 HIGH일때의 시간을 측정하고 거리 계산
                if(tick == 1'b1) begin
                    if (echo_count_reg == (400 * 58)  - 1) begin // max 4m (400cm), velocity 340 m/s
                        echo_count_next = 0;
                    end
                    else begin
                        echo_count_next = echo_count_reg + 1; 
                    end
                end             
                
                if (echo == 1'b0) begin
                    next = IDLE;
                end                
            end
        endcase
    end    
endmodule   

module distance_caculator (
    input  logic clk,
    input  logic reset,
    input  logic echo,
    input  logic [14:0] echo_count,
    output logic [8:0] distance
);

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            distance <= 0;
        end
        else begin
            if (echo == 1'b0) begin
                distance <= echo_count / 58;
            end
        end       
    end
endmodule

module tick_gen(
    input  logic clk,
    input  logic reset,
    output logic tick
    );

    localparam TICK_COUNT = 100; // 1us tick gen
    
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