`timescale 1ns / 1ps

////////////////////////////
///////transaction//////////
////////////////////////////
class transaction;
    typedef enum bit {write=1'b0, read=1'b1} oper_type;
    randc oper_type oper;
    rand bit [7:0] dintx;
    
    bit rx;
    bit newd;
    bit tx;
    bit [7:0] doutrx;
    bit donetx;
    bit donerx;
    
    function transaction copy();
        copy = new();
        copy.rx = this.rx;
        copy.newd = this.newd;
        copy.tx = this.tx;
        copy.doutrx = this.doutrx;
        copy.donetx = this.donetx;
        copy.donerx = this.donerx;
        copy.oper = this.oper;
        copy.dintx = this.dintx;
    endfunction 
endclass





////////////////////////////
///////generator//////////
////////////////////////////
class generator;
    transaction tr;
    mailbox #(transaction) mbx;
    event done;
    event drvnext;      //marks completion of driver
    event sconext;      //marks completion of scoreboard
    int count = 0;      //number of stimulus
    
    function new(mailbox #(transaction) mbx);
        this.mbx = mbx;
        tr = new();
    endfunction
    
    task run();
        repeat(count) begin
            assert(tr.randomize) else $error("Randomization failed");
            mbx.put(tr.copy);
            $display("[GEN]: Oper=%0s | Din=%0d", tr.oper.name(), tr.dintx);
            @(drvnext);
            @(sconext);
        end
        ->done;
    endtask
endclass





////////////////////////////
///////driver//////////
////////////////////////////
class driver;
    transaction tr;
    mailbox #(transaction) mbx;     //receives data from generator
    mailbox #(bit [7:0]) mbxds;     //sends data to scoreboard
    virtual uart_if vif;
    event drvnext;
    
    bit [7:0] din;                 
    bit wr = 0;                    //random operation read/write
    bit [7:0] datarx;              //data received during read
    
    function new(mailbox #(bit [7:0]) mbxds, mailbox #(transaction) mbx);
        this.mbxds = mbxds;
        this.mbx = mbx;
    endfunction
    
    task reset();
        vif.rst <= 1'b1;
        vif.dintx <= 0;
        vif.newd <= 0;
        vif.rx <= 1'b1;
        repeat(5)@(posedge vif.uclktx);
        vif.rst <= 1'b0;
        @(posedge vif.uclktx);
        $display("[DRV]: Reset done");
        $display("------------------------done");
    endtask
    
    task run();
        forever begin
            mbx.get(tr);
            
            if(tr.oper == 1'b0)        //write operation
                begin
                    @(posedge vif.uclktx);
                    vif.rst <= 1'b0;
                    vif.newd <= 1'b1;        //new data is set
                    vif.rx <= 1'b1;
                    vif.dintx = tr.dintx;  //generated data is applied
                    @(posedge vif.uclktx);
                    vif.newd <= 1'b0;
                    mbxds.put(tr.dintx);    //send generated data to scoreboard
                    $display("[DRV]: Data Sent : %0d", tr.dintx);
                    wait(vif.donetx == 1'b1);       //wait for donetx to be high
                    ->drvnext;
                end
                
            else if(tr.oper == 1'b1)
                begin
                    @(posedge vif.uclkrx);
                    vif.rst <= 1'b0;
                    vif.rx <= 1'b0;
                    vif.newd <= 1'b0;
                    @(posedge vif.uclkrx);
                    
                    for(int i=0; i<8; i++)
                        begin
                            @(posedge vif.uclkrx);
                            vif.rx <= $urandom;
                            datarx[i] = vif.rx;
                        end
                    
                    mbxds.put(datarx);
                    $display("[DRV]: Data received=%0d", datarx);
                    wait(vif.donerx == 1'b1);
                    vif.rx <= 1'b1;
                    ->drvnext;
                end
        end
    endtask
endclass





////////////////////////////
///////monitor//////////
////////////////////////////
class monitor;
    transaction tr;
    virtual uart_if vif;
    mailbox #(bit [7:0]) mbx;
    bit [7:0] srx;
    bit [7:0] rrx;
    
    function new(mailbox #(bit [7:0]) mbx);
        this.mbx = mbx;
    endfunction
    
    task run();
        forever begin
            @(posedge vif.uclktx);
            if( (vif.newd == 1) && (vif.rx == 1'b1))
                begin
                    @(posedge vif.uclktx);
                    for(int i=0; i<8; i++)
                        begin
                            @(posedge vif.uclktx);
                            srx[i] = vif.tx;
                        end
                    $display("[MON]: Data sent on tx =%0d", srx);
                    @(posedge vif.uclktx);
                    mbx.put(srx);
                end
                
            else if((vif.newd == 1'b0) && (vif.rx == 1'b0))
                begin
                    wait(vif.donerx == 1'b1);
                    rrx = vif.doutrx;
                    $display("[MON]: Data received on rx =%0d", rrx);
                    @(posedge vif.uclktx);
                    mbx.put(rrx);
                end
        end
    endtask
endclass






////////////////////////////
///////scoreboard//////////
////////////////////////////
class scoreboard;
  mailbox #(bit [7:0]) mbxds, mbxms;
  
  bit [7:0] ds;
  bit [7:0] ms;
  
   event sconext;
  
  function new(mailbox #(bit [7:0]) mbxds, mailbox #(bit [7:0]) mbxms);
    this.mbxds = mbxds;
    this.mbxms = mbxms;
  endfunction
  
  task run();
    forever begin
      
      mbxds.get(ds);
      mbxms.get(ms);
      
      $display("[SCO] : DRV : %0d MON : %0d", ds, ms);
      if(ds == ms)
        $display("DATA MATCHED");
      else
        $display("DATA MISMATCHED");
      
      $display("----------------------------------------");
      
     ->sconext; 
    end
  endtask
  
  
endclass






////////////////////////////
///////environment////////
////////////////////////////
class environment;
    generator gen;
    driver drv;
    monitor mon;
    scoreboard sco; 

    event nextgd; ///gen -> drv
    event nextgs;  /// gen -> sco
  
    mailbox #(transaction) mbxgd; ///gen - drv
    mailbox #(bit [7:0]) mbxds; /// drv - sco 
    mailbox #(bit [7:0]) mbxms;  /// mon - sco
  
    virtual uart_if vif;
 
  
  function new(virtual uart_if vif);
       
    mbxgd = new();
    mbxms = new();
    mbxds = new();
    
    gen = new(mbxgd);
    drv = new(mbxds,mbxgd);
    
    
 
    mon = new(mbxms);
    sco = new(mbxds, mbxms);
    
    this.vif = vif;
    drv.vif = this.vif;
    mon.vif = this.vif;
    
    gen.sconext = nextgs;
    sco.sconext = nextgs;
    
    gen.drvnext = nextgd;
    drv.drvnext = nextgd;
 
  endfunction
  
  task pre_test();
    drv.reset();
  endtask
  
  task test();
  fork
    gen.run();
    drv.run();
    mon.run();
    sco.run();
  join_any
  endtask
  
  task post_test();
    wait(gen.done.triggered);  
    $finish();
  endtask
  
  task run();
    pre_test();
    test();
    post_test();
  endtask

endclass





////////////////////////////
///////tb top////////
////////////////////////////
module tb;
  uart_if vif();
  uart_design #(1000000, 9600) dut (vif.clk,vif.rst,vif.rx,vif.dintx,vif.newd,vif.tx,vif.doutrx,vif.donetx, vif.donerx);
  
  
  
    initial begin
      vif.clk <= 0;
    end
    
    always #10 vif.clk <= ~vif.clk;
    
    environment env;
    
    
    
    initial begin
      env = new(vif);
      env.gen.count = 10;
      env.run();
    end
      
    
    initial begin
      $dumpfile("dump.vcd");
      $dumpvars;
    end
   
  assign vif.uclktx = dut.utx.uclk;
  assign vif.uclkrx = dut.rtx.uclk;
    
  endmodule