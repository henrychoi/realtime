`include "dpp.v"

module dining_table // table is a reserved word
(input clk, input reset);
  integer i;
  localparam N_PHILO = 4;
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
  wire[N_PHILO-1:0] hungry, evtData, evtEmpty;
  //wire evtReady;

//`define EAT_TIME 2
//`define THINK_TIME 5
  philo#(.EAT_TIME(2), .THINK_TIME(5))
    philo[N_PHILO-1:0](.clk(clk), .reset(reset), .may_eat(may_eat)
      , .foutAck(eventAck), .hungry(hungry)
      , .foutData(evtData), .foutEmpty(evtEmpty));

  //assign evtReady = ~(& evtEmpty); //Are any FIFO ready?

  always @(posedge reset, posedge clk) begin
    // Cannot put code here, because XST is not smart enough to replicate
    // the same code to different stimulus
    
    if(reset) begin
      for(i = 0; i < N_PHILO; i = i + 1) begin
        fork_[i] <= FORK_AVAIL;
        may_eat[i] <= `FALSE;
        eventAck[i] <= `FALSE;
      end

    end else begin: event_process //respond to sig from each phil
      integer n, m;
      for(i = 0; i < N_PHILO; i = i + 1) begin
        may_eat[i] <= `FALSE;
        eventAck[i] <= `FALSE;//Do not read off the FIFO unless !EMPTY
      end
      
      if(!evtEmpty[3] && !eventAck[3]) begin
        n = 3;
        eventAck[n] <= `TRUE;
        
        m = LEFT(n);
        if(evtData[3] == `PHILO_HUNGRY) begin
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
      end else if(!evtEmpty[2]) begin
      end
    end//: event_process
  end//always
endmodule
