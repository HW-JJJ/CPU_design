`timescale 1ns / 1ps

class transaction;

    // APB Interface Signals
    rand logic [ 3:0] PADDR;
    rand logic [31:0] PWDATA;
    rand logic        PWRITE;
    rand logic        PENABLE;
    rand logic        PSEL;
    logic      [31:0] PRDATA;  // dut out data
    logic             PREADY;  // dut out data
    // outport signals
    logic      [ 3:0] fnd_comm;  // dut out data
    logic      [ 7:0] fnd_font;  // dut out data

    //definition name  condition           
    constraint c_paddr 
    {
        PADDR dist {4'h0:=10, 4'h4:=50, 4'h8:=50}; // inside {} : use element in {}
    }  
    //constraint c_wdata {PWDATA < 10;}   // follow {}   
    constraint c_paddr_0 
    {
        if (PADDR == 0)
            PWDATA inside {1'b0, 1'b1};
        else if (PADDR == 4)
            PWDATA < 4'b1111;
        else if (PADDR == 8)
            PWDATA < 10;
    }

    task display(string name);
        $display(
            "[%s] PADDR=%h, PWDATA=%h, PWRITE=%h, PENABLE=%h, PSEL=%h, PRDATA=%h, PREADY=%h, fnd_comm=%h, fnd_font=%h",
            name, PADDR,    PWDATA,    PWRITE,    PENABLE,    PSEL,    PRDATA,    PREADY,    fnd_comm,    fnd_font);
    endtask 
endclass  

interface APB_Slave_Intferface;
    logic        PCLK;
    logic        PRESET;
    // APB Interface Signals
    logic [ 3:0] PADDR;
    logic [31:0] PWDATA;
    logic        PWRITE;
    logic        PENABLE;
    logic        PSEL;
    logic [31:0] PRDATA;  // dut out data
    logic        PREADY;  // dut out data
    // outport signals
    logic [ 3:0] fnd_comm;  // dut out data
    logic [ 7:0] fnd_font;  // dut out data
endinterface 

class generator;
    mailbox #(transaction) Gen2Drv_mbox;
    event gen_next_event;

    function new(mailbox#(transaction) Gen2Drv_mbox, event gen_next_event);
        this.Gen2Drv_mbox   = Gen2Drv_mbox;
        this.gen_next_event = gen_next_event;
    endfunction  

    task run(int repeat_counter);
        transaction fnd_tr;
        repeat (repeat_counter) begin
            fnd_tr = new();  // make instrance
            if (!fnd_tr.randomize()) 
                $error("Randomization fail!");
            fnd_tr.display("GEN");
            Gen2Drv_mbox.put(fnd_tr);
            @(gen_next_event);  // wait a event from driver
        end
    endtask  
endclass  

class driver;
    virtual APB_Slave_Intferface fnd_intf;
    mailbox #(transaction) Gen2Drv_mbox;
    event gen_next_event;
    transaction fnd_tr;

    function new(virtual APB_Slave_Intferface fnd_intf,
                 mailbox #(transaction) Gen2Drv_mbox, event gen_next_event);
        this.fnd_intf = fnd_intf;
        this.Gen2Drv_mbox = Gen2Drv_mbox;
        this.gen_next_event = gen_next_event;
    endfunction 

    task run();
        forever begin
            Gen2Drv_mbox.get(fnd_tr);
            fnd_tr.display("DRV");
            @(posedge fnd_intf.PCLK);
            fnd_intf.PADDR   <= fnd_tr.PADDR;
            fnd_intf.PWDATA  <= fnd_tr.PWDATA;
            fnd_intf.PWRITE  <= 1'b1;
            fnd_intf.PENABLE <= 1'b0;
            fnd_intf.PSEL    <= 1'b1;
            @(posedge fnd_intf.PCLK);
            fnd_intf.PADDR   <= fnd_tr.PADDR;
            fnd_intf.PWDATA  <= fnd_tr.PWDATA;
            fnd_intf.PWRITE  <= 1'b1;
            fnd_intf.PENABLE <= 1'b1;
            fnd_intf.PSEL    <= 1'b1;
            wait (fnd_intf.PREADY == 1'b1);
            repeat (3) @(posedge fnd_intf.PCLK);
            ->gen_next_event;  // event trigger
        end
    endtask  
endclass 

class monitor;

    virtual APB_Slave_Intferface fnd_intf;
    mailbox #(transaction) Mon2Scb_mbox;
    transaction fnd_tr;

    function new(virtual APB_Slave_Intferface fnd_intf,
                mailbox #(transaction) Mon2Scb_mbox);
        this.fnd_intf = fnd_intf;
        this.Mon2Scb_mbox = Mon2Scb_mbox;        
    endfunction 

    task run();
        forever begin
            fnd_tr          = new();
            wait( fnd_intf.PREADY == 1'b1 );
            #1;
            fnd_tr.PADDR    = fnd_intf.PADDR;
            fnd_tr.PWDATA   = fnd_intf.PWDATA;
            fnd_tr.PWRITE   = fnd_intf.PWRITE;
            fnd_tr.PENABLE  = fnd_intf.PENABLE;
            fnd_tr.PSEL     = fnd_intf.PSEL;
            fnd_tr.PRDATA   = fnd_intf.PRDATA;
            fnd_tr.PREADY   = fnd_intf.PREADY;
            fnd_tr.fnd_comm = fnd_intf.fnd_comm;
            fnd_tr.fnd_font = fnd_intf.fnd_font;
            fnd_tr.display("MON");
            Mon2Scb_mbox.put(fnd_tr);
            repeat (3) @(posedge fnd_intf.PCLK);
        end
    endtask
endclass 

class scoreboard;

    mailbox #(transaction) Mon2Scb_mbox;
    transaction fnd_tr;
    event gen_next_event;

    // reference model
    // virtual register

    logic [31:0] ref_fnd_Reg[0:2];
    logic [ 7:0] ref_fnd_font[0:15] = 
    '{
        8'hc0,
        8'hF9,
        8'hA4,
        8'hB0,
        8'h99,
        8'h92,
        8'h82,
        8'hf8,
        8'h80,
        8'h90,
        8'h88,
        8'h83,
        8'hc6,
        8'ha1,
        8'h86,
        8'h8E
    };
    
    function new( mailbox #(transaction) Mon2Scb_mbox , event gen_next_event);
        this.Mon2Scb_mbox = Mon2Scb_mbox;
        this.gen_next_event = gen_next_event;

        for(int i=0 ; i<3 ; i++) begin
            ref_fnd_Reg[i] = 0;
        end
    endfunction 

    task run();
        forever begin
            Mon2Scb_mbox.get(fnd_tr);
            fnd_tr.display("SCB");

            // write mode
            if ( fnd_tr.PWRITE == 1'b1 ) begin 
                ref_fnd_Reg[fnd_tr.PADDR [3:2]] = fnd_tr.PWDATA;

                // fnd_font
                if ( ref_fnd_font[ref_fnd_Reg[2]] == fnd_tr.fnd_font ) // PASS
                    $display("FND FONT PASS, %h, %h", ref_fnd_font[ref_fnd_Reg[2]], fnd_tr.fnd_font);
                else // FAIL
                    $display("FND FONT FAIL, %h, %h", ref_fnd_font[ref_fnd_Reg[2]], fnd_tr.fnd_font);
                
                // fnd_comm
                if ( ref_fnd_Reg [0] == 0 ) begin // en == 0 : fnd_comm == 4'b1111;
                    if ( 4'hf == fnd_tr.fnd_comm ) 
                        $display("FND en COMM PASS");
                    else // FAIL
                        $display("FND en COMM FAIL");
                end
                else begin                          // en == 1 
                    if ( ref_fnd_Reg[1][3:0] == ~fnd_tr.fnd_comm)
                        $display("FND COMM PASS : %h , %h", ref_fnd_Reg[1][3:0], ~fnd_tr.fnd_comm);
                    else // FAIL
                        $display("FND COMM FAIL : %h , %h", ref_fnd_Reg[1][3:0], ~fnd_tr.fnd_comm);
                end
            end

            // read mode
            else begin 
            end
            -> gen_next_event; // trigger
        end
    endtask
endclass 

class environment;
    mailbox #(transaction) Gen2Drv_mbox;
    mailbox #(transaction) Mon2Scb_mbox;
    
    generator fnd_gen;
    driver fnd_drv;
    monitor fnd_mon;
    scoreboard fnd_scb;

    event gen_next_event;

    function new(virtual APB_Slave_Intferface fnd_intf);
        this.Gen2Drv_mbox = new();
        this.Mon2Scb_mbox = new();
        this.fnd_gen = new(Gen2Drv_mbox, gen_next_event);
        this.fnd_drv = new(fnd_intf, Gen2Drv_mbox, gen_next_event);
        this.fnd_mon = new(fnd_intf, Mon2Scb_mbox);
        this.fnd_scb = new(Mon2Scb_mbox, gen_next_event);
    endfunction 

    task run(int count);
        fork
            fnd_gen.run(count);
            fnd_drv.run();
            fnd_mon.run();
            fnd_scb.run();
        join_any;
    endtask  
endclass 

module tb_FND_APB_Periph;

    environment fnd_env;
    APB_Slave_Intferface fnd_intf();

    always #5 fnd_intf.PCLK = ~fnd_intf.PCLK;

    FND_Periph DUT (
        // global signal
        .PCLK(fnd_intf.PCLK),
        .PRESET(fnd_intf.PRESET),
        // APB Interface Signals
        .PADDR(fnd_intf.PADDR),
        .PWDATA(fnd_intf.PWDATA),
        .PWRITE(fnd_intf.PWRITE),
        .PENABLE(fnd_intf.PENABLE),
        .PSEL(fnd_intf.PSEL),
        .PRDATA(fnd_intf.PRDATA),
        .PREADY(fnd_intf.PREADY),
        // outport signals
        .fnd_comm(fnd_intf.fnd_comm),
        .fnd_font(fnd_intf.fnd_font)
    );

    initial begin
        fnd_intf.PCLK   = 0;
        fnd_intf.PRESET = 1;
        #10 fnd_intf.PRESET = 0;
        fnd_env = new(fnd_intf);
        fnd_env.run(100);
        #30;
        $display("done");
        $finish;
    end
endmodule