`include "dpp.v"
`define EAT_TIME 2
`define THINK_TIME 5

module dining_table // table is a reserved word
(input clk, input reset
//, output [N_PHILO-1:0] LEDs_Positions_TRI_O
);
  localparam N_PHILO = 2;
  integer i;
  //localparam FORK_FREE = 0, FORK_USED = 1;
  reg fork_avail[N_PHILO-1:0];//i.e., bool fork_avail[N_PHILO]
  reg phil_hungry[N_PHILO-1:0];

  reg[`TABLE_EVENT_SIZE:0] event_p[N_PHILO-1:0];
  wire [`PHILO_EVENT_SIZE:0] event_s[N_PHILO-1:0];
  //Declaring an array of philosophers with the signals correctly assigned
  // would have been convenient, but it doesn't compile
  /*philo#(.EAT_TIME(2), .THINK_TIME(5))
    philo[N_PHILO-1:0](.clk(clk), .reset(reset)
    , .event_in(event), .state(philo_state)); */

  philo#(.ID(0), .EAT_TIME(`EAT_TIME), .THINK_TIME(`THINK_TIME))
    philo0(.clk(clk), .reset(reset)
      , .event_p(event_s[0]), .event_s(event_p[0]));
      
  philo#(.ID(1), .EAT_TIME(`EAT_TIME), .THINK_TIME(`THINK_TIME))
    philo1(.clk(clk), .reset(reset)
      , .event_p(event_s[1]), .event_s(event_p[1]));

  initial begin
    for(i = 0; i < N_PHILO; i = i + 1) begin
      event_p[i] = 0;
    end
  end
  
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