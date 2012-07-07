`timescale 10ns / 1ns
`include "dpp.v"

module test;
  reg clk, reset;
  reg may_eat, l_event, l_eventHot, table_rden;
  wire l_finEmpty, table_eventData, table_fifoEmpty, table_notEmpty;
  reg [3:0] n;

  philo_fifo fin(.clk(clk), .srst(reset)
    , .din(may_eat), .wr_en(may_eat), .rd_en(1'b1) //Always read
    , .dout(), .full(), .empty(l_finEmpty));
  philo_fifo fout(.clk(clk), .srst(reset)
    , .din(l_event), .wr_en(l_eventHot), .rd_en(table_rden)
    , .dout(table_eventData), .full(), .empty(table_fifoEmpty));
	dining_table uut(.clk(clk), .reset(reset));

  always #1 clk = ~clk; //Drive the clock
  assign table_notEmpty = ~table_fifoEmpty;

  always @(posedge clk
    , posedge table_notEmpty //This helps me get the event 1 clk sooner
  ) begin
    table_rden <= `FALSE;
    if(table_notEmpty && !table_rden) begin
      //At this instant, this is BECOMING false!
      //So there is ambiguity
      table_rden <= `TRUE;
      n <= n + 1;
    end
  end

	initial begin
		clk = 1'b1;
		reset = 1'b0;
    n = 0;
    may_eat = `FALSE;
    l_event = `FALSE;
    l_eventHot = `FALSE;
    table_rden = `FALSE;
    
    //$monitor($time, " clk=%b", clk);
    #2 reset = 1'b1;//The rising of reset line should trigger the reset logic
		#2 reset = 1'b0;

    #2
    may_eat = `TRUE;
    l_event = `TRUE;
    l_eventHot = `TRUE;
    
    #2 may_eat = `FALSE;
    l_eventHot = `FALSE;
    
    
    #0 //Can increase this to a larger value; the data will still be there
    l_event = `FALSE;
    l_eventHot = `TRUE;

    #2 l_eventHot = `FALSE;

    #2 l_event = `TRUE;
    l_eventHot = `TRUE;

    #2 l_eventHot = `FALSE;    
	end
endmodule