`timescale 1ns / 1ps

// encapsulation - 변수와 함수를 한 곳에 묶어 구현(캡슐화) 
class transaction;
    // APB Interface Siganls
    rand logic [ 3:0] PADDR;
    rand logic [31:0] PWDATA;
    rand logic        PWRITE;
    rand logic        PENABLE;
    rand logic        PSEL;
    // dut out data
    logic [31:0] PRDATA;
    logic        PREADY;
    // outport signals
    logic [3:0] fnd_comm;  // dut out data
    logic [7:0] fnd_font;  // dut out data

    constraint c_paddr {PADDR inside {4'h0, 4'h4, 4'h8};}  // {} 내로 데이터값 제약
    constraint c_wdata {PWDATA < 10;}

    task display(string name);
        $display("[%s] PADDR=%h , PWDATA=%h, PWRITE=%h, PENABLE=%h, PSEL=%h, PRDATA=%h, PREADY=%h, fnd_comm=%h, fnd_font=%h"
                 ,name, PADDR,     PWDATA,    PWRITE,    PENABLE,    PSEL,    PRDATA,    PREADY,    fnd_comm,    fnd_font);
    endtask
endclass 

// driver로부터 입력과 dut의 출력을 동시에 처리 
interface APB_Slave_Interface;
    logic       PCLK;
    logic       PRESET;
    // APB Interface Signals
    logic [ 3:0] PADDR;
    logic [31:0] PWDATA;
    logic        PWRITE;
    logic        PENABLE;
    logic        PSEL;
    // dut out data
    logic [31:0] PRDATA;
    logic        PREADY;
    // outport signals
    logic [3:0] fnd_comm;  // dut out data
    logic [7:0] fnd_font;  // dut out data
endinterface //APB_Slave_Interface

// transaction을 생성 후 mailbox에 저장하는 역할 
class generator; 
    mailbox #(transaction) Gen2Drv_mbox;  // refernce 값을 받는
    event gen_next_event;

    function new(mailbox #(transaction) Gen2Drv_mbox, event gen_next_event);
        this.Gen2Drv_mbox = Gen2Drv_mbox;  // 해당 인스턴스의 멤버인 GEN2DRV_MBOX에 매개변수로 들어오는 값을 넣어주겠다
        this.gen_next_event =  gen_next_event;        
    endfunction 

    task run (int repeat_counter);
        transaction fnd_tr;

        repeat(repeat_counter) begin
            fnd_tr = new(); // 실체화된 레퍼런스 값을 연결
            
            if ( !fnd_tr.randomize() ) 
                $error("Randmomization Fail!");
            fnd_tr.display("GEN");
            Gen2Drv_mbox.put(fnd_tr); 
            @(gen_next_event);      // wait a event for driver
        end
    endtask
endclass 

class driver;
    virtual APB_Slave_Interface fnd_intf;   // 외부 인터페이스와 연결 개념
    mailbox #(transaction) Gen2Drv_mbox;    // mailbox와 연결
    event gen_next_event;
    transaction fnd_tr;

    function new(mailbox #(transaction) Gen2Drv_mbox, event gen_next_event, virtual APB_Slave_Interface fnd_intf);
        this.Gen2Drv_mbox = Gen2Drv_mbox;
        this.gen_next_event = gen_next_event;;
        this.fnd_intf = fnd_intf;
    endfunction //new()

    task run();
        forever begin
            Gen2Drv_mbox.get(fnd_tr);
            fnd_tr.display("DRV");
            // setup
            @(posedge fnd_intf.PCLK);
            fnd_intf.PADDR   <= fnd_tr.PADDR;
            fnd_intf.PWDATA  <= fnd_tr.PWDATA;
            fnd_intf.PWRITE  <= 1'b1;
            fnd_intf.PENABLE <= 1'b0;
            fnd_intf.PSEL    <= 1'b1;
            // access
            @(posedge fnd_intf.PCLK);
            fnd_intf.PADDR   <= fnd_tr.PADDR;
            fnd_intf.PWDATA  <= fnd_tr.PWDATA;
            fnd_intf.PWRITE  <= 1'b1;
            fnd_intf.PENABLE <= 1'b1;
            fnd_intf.PSEL    <= 1'b1;
            // wait for ready
            wait(fnd_intf.PREADY == 1'b1);
            @(posedge fnd_intf.PCLK);
            @(posedge fnd_intf.PCLK);
            @(posedge fnd_intf.PCLK);
            ->gen_next_event; // event trigger
        end
    endtask
endclass 

class environment;
    mailbox #(transaction) Gen2Drv_mbox;
    generator fnd_gen;
    driver fnd_drv;
    event gen_next_event;

    function new(virtual APB_Slave_Interface fnd_intf);
      Gen2Drv_mbox = new();
      this.fnd_gen = new(Gen2Drv_mbox, gen_next_event);
      this.fnd_drv = new(fnd_intf, Gen2Drv_mbox, gen_next_event);  
    endfunction

    task run (int count);
        fork
            fnd_gen.run(count);
            fnd_drv.run();
        join_any
    endtask 
endclass 

module tb_FND_APB_PERIPH;

    environment fnd_env;
    APB_Slave_Interface fnd_intf();  // 소괄호 -> 인스턴스 

    FND_Periph DUT(
        .PCLK(fnd_intf.PCLK),
        .PRESET(fnd_intf.PRESET),
        .PADDR(fnd_intf.PADDR),
        .PWDATA(fnd_intf.PWDATA),
        .PWRITE(fnd_intf.PWRITE),
        .PENABLE(fnd_intf.PENABLE),
        .PSEL(fnd_intf.PSEL),
        .PRDATA(fnd_intf.PRDATA),
        .PREADY(fnd_intf.PREADY),
        .fnd_comm(fnd_intf.fnd_comm),
        .fnd_font(fnd_intf.fnd_font)
    );  
    
    always #5 fnd_intf.PCLK = ~fnd_intf.PCLK;

    initial begin
        fnd_intf.PCLK = 0; fnd_intf.PRESET = 1;
        #10 fnd_intf.PRESET = 0;
        fnd_env = new(fnd_intf);
        fnd_env.run(10);
        #30 $finish;
    end
endmodule