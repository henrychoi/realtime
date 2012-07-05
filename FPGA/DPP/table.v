`include "dpp.v"

module dining_table // table is a reserved word
#(parameter N_PHILO = 3)
(input clk, input reset
, output [N_PHILO-1:0] LEDs_Positions_TRI_O
);
  wire [`EVENT_SIZE-1:0] evt[N_PHILO-1:0];//wire [N_PHILO-1:0] evt;
  //wire [`PHILO_STATE_SIZE-1:0] philo_state[N_PHILO-1:0];
  //integer i;

  //Declaring an array of philosophers with the signals correctly assigned
  // would have been convenient, but it doesn't compile
  /*philo#(.EAT_TIME(2), .THINK_TIME(5))
    philo[N_PHILO-1:0](
    .clk(clk), .reset(reset)
    , .event_in(evt), .state(philo_state)); */

  philo#(.EAT_TIME(2), .THINK_TIME(5))
    philo0(.clk(clk), .reset(reset), .event_in(evt[0]));

  //assign LEDs_Positions_TRI_O = {philo_state[1][0], philo_state[1][1]};
endmodule