`ifndef dpp_h
`define dpp_h

// Enumerate signals
`define SIG_SIZE 1
`define EAT_SIG `SIG_SIZE'b0
`define MAX_SIG `SIG_SIZE'b1

// Define philosopher states
`define PHILO_STATE_SIZE 2
`define hungry   `PHILO_STATE_SIZE'b00
`define eating   `PHILO_STATE_SIZE'b01
`define thinking `PHILO_STATE_SIZE'b10 //Connect bit[1] to LED pin

`endif//dpp_h