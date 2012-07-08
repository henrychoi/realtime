`include "dpp.v"

module dining_table // table is a reserved word
(input clk, input reset);
  localparam N_PHILO = 4;
  reg fork_avail[N_PHILO-1:0];//i.e., bool fork_avail[N_PHILO]
  reg eat_sig[N_PHILO-1:0];
  wire [`PHILO_STATE_SIZE-1:0] state[N_PHILO-1:0];

`define EAT_TIME 2
`define THINK_TIME 5
  //Declaring an array of philosophers with the signals correctly assigned
  // would have been convenient, but it doesn't work for one reason or another
  // in practice; so we have to declare the philosophers one by one
  philo#(.ID(0), .EAT_TIME(`EAT_TIME), .THINK_TIME(`THINK_TIME))
    philo0(.clk(clk), .reset(reset), .eat_sig(eat_sig[0]), .state(state[0]));
  philo#(.ID(1), .EAT_TIME(`EAT_TIME), .THINK_TIME(`THINK_TIME))
    philo1(.clk(clk), .reset(reset), .eat_sig(eat_sig[1]), .state(state[1]));
  philo#(.ID(2), .EAT_TIME(`EAT_TIME), .THINK_TIME(`THINK_TIME))
    philo2(.clk(clk), .reset(reset), .eat_sig(eat_sig[2]), .state(state[2]));
  philo#(.ID(3), .EAT_TIME(`EAT_TIME), .THINK_TIME(`THINK_TIME))
    philo3(.clk(clk), .reset(reset), .eat_sig(eat_sig[3]), .state(state[3]));

  // The seating makes sense if you think in little endian.  That is,
  // Visualized in big endian -> Visualized in little endian
  //   1      2     3     4 ...  ...     4     3      2     1
  // ..., RIGHT,    n, LEFT,...  ..., LEFT,    n, RIGHT,...
`define RIGHT(n_) ((n_ + (N_PHILO - 1)) % N_PHILO)
`define LEFT(n_)  ((n_ + 1) % N_PHILO)
  always @(posedge reset
  , posedge state[3][`PHIL_HUNGRY_BIT] //^HUNGRY
  , negedge state[3][`PHIL_EATING_BIT] //^DONE
  ) begin
    if(reset) begin: initialize
      integer i;
      for(i = 0; i < N_PHILO; i = i + 1) begin
        fork_avail[i] <= 1;
        eat_sig[i] <= 0;
      end
    end else begin: event_process //respond to sig from each phil
      integer n, m;
      if(state[3][`PHIL_HUNGRY_BIT]) begin
        n = 3;
        m = `LEFT(n);
        if(fork_avail[n] && fork_avail[m]) begin
          fork_avail[n] <= 0;
          fork_avail[m] <= 0;
          eat_sig[n] <= 1; //^EAT; how to clear this?
        end else begin//This philosopher goes on hungry
          eat_sig[n] <= 0;
        end
      end else if(!state[0][`PHIL_EATING_BIT]) begin //^DONE
        n = 0;
        m = `LEFT(n);
        fork_avail[n] <= 1;
        fork_avail[m] <= 1;

        m = `RIGHT(0);//Check the right neighbor
        //if(state[i])
      end else begin
      end
    end//: event_process
  end//always
endmodule

/*
  always @(posedge reset
  , posedge event_s[0][`PHILO_EVENT_SIZE]
  , posedge clk) begin
    if(reset) begin
      for(i = 0; i < N_PHILO; i = i + 1) begin
        fork_avail[i] <= 0;
        phil_hungry[i] <= 0;
        event_p[i] <= 0;
      end
    end else if(event_s[0][`PHILO_EVENT_SIZE]) begin
      //event_p[0][`TABLE_EVENT_SIZE-1:0] = data for the EAT event (none)
      //Take the lock on the fork

      //I get a warning for this statement: event_p[0][`TABLE_EVENT_SIZE] was
      //automatically added to the sensitivity list
      //Raise event for this philosopher
      //event_p[0][`TABLE_EVENT_SIZE] <= ~event_p[0][`TABLE_EVENT_SIZE];
    end else begin // just clock
      for(i = 0; i < N_PHILO; i = i + 1) //Clear event to form a pulse
        if(event_p[i][`TABLE_EVENT_SIZE])
          event_p[i][`TABLE_EVENT_SIZE] <= 'b0; //clear the event
    end
  end//always @(posedge clk) begin
  
  //assign LEDs_Positions_TRI_O = {philo_state[1][0], philo_state[1][1]};
endmodule
*/