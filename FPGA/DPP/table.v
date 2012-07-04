`timescale 1ns / 1ps
`include "dpp.v"

module dining_table // table is a reserved word
#(parameter N_PHILO = 2)
(input clk, input reset
, output[N_PHILO-1:0] LEDs_Positions_TRI_O );
  wire[`SIG_SIZE-1:0] evt[N_PHILO-1:0];
  wire[`PHILO_STATE_SIZE-1:0] philo_state[N_PHILO-1:0];
  
  /* This would have been convenient, if it had compiled
  philo#(.TIMER_SIZE(3), .EAT_TIME(2), .THINK_TIME(5))
  philo[N_PHILO-1:0](
    .clk(clk), .reset(reset)
    , .event_in(evt), .state(philo_state));
  */
  philo#(.TIMER_SIZE(3), .EAT_TIME(2), .THINK_TIME(5))
  philo0(
    .clk(clk), .reset(reset)
    , .event_in(evt[0]), .state(philo_state[0]));
    
    assign LEDs_Positions_TRI_O = {philo_state[1][0], philo_state[1][1]};
  
endmodule
