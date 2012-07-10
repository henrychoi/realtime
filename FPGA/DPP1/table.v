`include "dpp.v"

module dining_table // table is a reserved word
#(parameter N_PHILO = 4, TIMER_SIZE = 27)
(input CLK_P, input CLK_N, input reset, output[4:0] led5
//, input[7:0] switch8, output[7:0] led8 // for additional debugging
);
`include "function.v"

  reg[TIMER_SIZE-1:0] timer;
  integer i;
  // The seating makes sense if you think in little endian.  That is,
  // Visualized in big endian -> Visualized in little endian
  //   1      2     3     4 ...  ...     4     3      2     1
  // ..., RIGHT,    n, LEFT,...  ..., LEFT,    n, RIGHT,...
  function integer RIGHT(input integer n_);
    RIGHT = (n_ + (N_PHILO - 1)) % N_PHILO;
  endfunction
  function integer LEFT(input integer n_);
    LEFT = (n_ + 1) % N_PHILO;
  endfunction

  localparam FORK_AVAIL = 1'b0, FORK_TAKEN = ~FORK_AVAIL;
  reg[N_PHILO-1:0] fork_, may_eat, eventAck;
  wire[N_PHILO-1:0] evtData, evtEmpty, hungry;
  wire clk, slowclk;
  reg[36-TIMER_SIZE:0] hungry_time[N_PHILO-1:0]; //For debugging

  IBUFGDS dsClkBuf(.O(clk), .I(CLK_P), .IB(CLK_N));
  always @(posedge reset, posedge clk) begin
    if(reset) timer <= 0;
    else timer <= timer + 1'b1;
  end//always
  assign slowclk = timer[TIMER_SIZE-1];
  assign led5 = {hungry, slowclk}; //Center LED (led5[0]) should blink
  
  philo#(.EAT_TIME(2), .THINK_TIME(5)) philo[N_PHILO-1:0]
    (.clk(slowclk), .reset(reset), .may_eat(may_eat), .hungry(hungry)
      , .foutAck(eventAck), .foutData(evtData), .foutEmpty(evtEmpty));
      
  task philo_isr(input integer n);
    integer m;
    begin
      eventAck[n] <= `TRUE;
      m = LEFT(n);
      if(evtData[n] == `PHILO_HUNGRY) begin
        if((fork_[n] == FORK_AVAIL) && (fork_[m] == FORK_AVAIL)) begin
          fork_[n] <= FORK_TAKEN;
          fork_[m] <= FORK_TAKEN;
          may_eat[n] <= `TRUE; //^EAT; how to clear this?
        end
      end else begin //`PHILO_DONE
        fork_[n] <= FORK_AVAIL;
        fork_[m] <= FORK_AVAIL;
        
        m = RIGHT(n); // check the right neighbor
        if(hungry[m] && (fork_[m] == FORK_AVAIL)) begin
          fork_[n] <= FORK_TAKEN;
          fork_[m] <= FORK_TAKEN;
          may_eat[m] <= `TRUE;
        end
        
        m = LEFT(n); // check the left neighbor
        n = LEFT(m); // left fork of the left neighbor
        if(hungry[m] && (fork_[n] == FORK_AVAIL)) begin
          fork_[n] <= FORK_TAKEN;
          fork_[m] <= FORK_TAKEN;
          may_eat[m] <= `TRUE;
        end
      end
    end
  endtask//philo_isr

  always @(posedge reset, posedge slowclk) begin
    if(reset) begin
      for(i = 0; i < N_PHILO; i = i + 1) hungry_time[i] <= 0;
    end else
      for(i = 0; i < N_PHILO; i = i + 1)
        if(hungry[i]) hungry_time[i] <= hungry_time[i] + 1'b1;
  end
    
  always @(posedge reset, posedge slowclk) begin
    // Cannot put code here, because XST is not smart enough to replicate
    // the same code to different stimulus
    
    if(reset) begin
      for(i = 0; i < N_PHILO; i = i + 1) begin
        fork_[i] <= FORK_AVAIL;
        may_eat[i] <= `FALSE;
        eventAck[i] <= `FALSE;
      end

    end else begin: event_process //respond to sig from each phil
      //integer n, m;
      for(i = 0; i < N_PHILO; i = i + 1) begin
        may_eat[i] <= `FALSE;
        eventAck[i] <= `FALSE;//Do not read off the FIFO unless !EMPTY
      end
      
      if(!evtEmpty[3] && !eventAck[3]) philo_isr(3);
      else if(!evtEmpty[2] && !eventAck[2]) philo_isr(2);
      else if(!evtEmpty[1] && !eventAck[1]) philo_isr(1);
      else if(!evtEmpty[0] && !eventAck[0]) philo_isr(0);
    end//: event_process
  end//always
endmodule
