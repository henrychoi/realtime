`timescale 10ns / 1ns
`include "dpp.v"

module test;
  localparam N_PHILO = 4;
  reg CLK_P, CLK_N, reset;
  reg may_eat, l_event, l_eventHot, table_rden;
  wire l_finEmpty, table_eventData, table_fifoEmpty, table_notEmpty;
  reg [3:0] n;
  
  philo_fifo fin(.clk(clk), .srst(reset)
    , .din(may_eat), .wr_en(may_eat), .rd_en(1'b1) //Always read
    , .dout(), .full(), .empty(l_finEmpty));
  philo_fifo fout(.clk(clk), .srst(reset)
    , .din(l_event), .wr_en(l_eventHot), .rd_en(table_rden)
    , .dout(table_eventData), .full(), .empty(table_fifoEmpty));

	dining_table#(.N_PHILO(N_PHILO), .TIMER_SIZE(1))
    uut(.CLK_P(CLK_P), .CLK_N(CLK_N), .reset(reset)
      , .switch8(), .led5(), .led8());

  always begin
    #1 CLK_P = ~CLK_P;
    #0 CLK_N = ~CLK_N;
  end
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
		CLK_P = 0; CLK_N = 1;
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