`timescale 1ns / 1ps

// adder in systemverilog 

interface adder_intf; // ## interface
    logic [7:0] a; // systemverilog 의 새로운 datatype , reg와 wire가 합쳐진
    logic [7:0] b; 
    logic [7:0] sum;
    logic carry; 
endinterface //adder_intf

class transaction; // ## transaction 
    rand bit [7:0] a; // systemverilog new datatype => 2 state : 0 or 1 (no X,Z)
    rand bit [7:0] b; // rand -> make random    
endclass //transaction

// class : 변수와 함수를 모두 선언 가능
// 객체지향적 -> 함수 => 행동, transaction => 물체

class generator; // generator -> make transaction 값을 생성 그러므로 내부에 transaction을 가지고 있어야(실체화)
    transaction tr;  // class(transaction) variable(tr)
    mailbox #(transaction) gen2drv_mbox; // gen에서 mailbox로 나가는  // transation의 datatype의 변수다
    
    function new(mailbox#(transaction) gen2drv_mbox);
        this.gen2drv_mbox = gen2drv_mbox;
    endfunction //new()

    task run(int run_count); 
        repeat (run_count) begin
            tr = new();
            tr.randomize();
            gen2drv_mbox.put(tr); // randomize한 값을 mailbox에 넣는다
            #10;
        end
    endtask
endclass // 함수같은s //generator

class driver;
    transaction tr;                     // tr, adder_if => member value(멤버 변수) , method
    virtual adder_intf adder_if;
    mailbox #(transaction) gen2drv_mbox; // mailbox와 연결

    function new(mailbox #(transaction) gen2drv_mbox, virtual adder_intf adder_if);
        this.gen2drv_mbox = gen2drv_mbox;
        this.adder_if     = adder_if;
    endfunction //new()

    task reset();
        adder_if.a = 0;
        adder_if.b = 0;
    endtask

    task run();
        forever begin
            gen2drv_mbox.get(tr);
            adder_if.a = tr.a;
            adder_if.b = tr.b;
            #10;
        end
    endtask
endclass //driver

class environment;
    generator gen;
    driver    drv;
    mailbox #(transaction) gen2drv_mbox;

    function new(virtual adder_intf adder_if);
        gen2drv_mbox = new();
        gen          = new(gen2drv_mbox);
        drv          = new(gen2drv_mbox, adder_if);
    endfunction //new()

    task run();                 // run() => 'envrionment'라는 class의 멤버 함수 
        fork                    // fork ~ join // thread 동작 // 하나의 프로세스 내에서 여러 프로세스를 동시에 
            gen.run(10000);     //                               실행할 수 있게 해주는 병렬 처리 구조
            drv.run();          // gen.run과 drv.run이 동시에 실행
        join_any                // 동시에 gen에서 mailbox에 put, drv에서 mailbox에서 get  // _any : 안 내용이 끝나면 다음으로 
        #10 $finish;
    endtask
endclass //environment

module tb_adder;                // software 적인 측면
    environment env;            // classname valuename(handler) , stack영역 생성,  hanlder가 instance의 주소값을 가짐
    adder_intf  adder_if();

    adder dut(                  // instance 실체화
        .a(adder_if.a),
        .b(adder_if.b),
        .sum(adder_if.sum),
        .carry(adder_if.carry)  // instance
    );

    initial begin
        env = new(adder_if);    // new(); 생성자 => new의 의미 heap영역에 인스턴스를 생성하겠다 
        env.run();              // 객체지향 => 대부분 pointer 연결
    end                         // env에 new(~)의 주소값(reference) 전달
endmodule

// heap 영역 (큰 영역) -> stack 영역
// function vs task in systemverilog
// return값의 존재유무 function return 0 task return X (내부에 = 포함 x)
// 즉 return값을 줘야할 경우엔 return 그 제외 대부분 task 함수 사용
