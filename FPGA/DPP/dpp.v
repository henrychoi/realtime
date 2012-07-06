`ifndef dpp_h
`define dpp_h

// Enumerate signals that are published/subscribed by modules
`define PHILO_EVENT_SIZE 1
`define PHILO_HUNGRY `PHILO_EVENT_SIZE'b0
`define PHILO_DONE   `PHILO_EVENT_SIZE'b1

`define TABLE_EVENT_SIZE 0
`define TABLE_EAT `TABLE_EVENT_SIZE'b0

// Define philosopher states
`define thinking 'b00
`define PHIL_EATING_BIT 0
`define eating   'b01
`define PHIL_HUNGRY_BIT 1
`define hungry   'b10
`define PHILO_STATE_SIZE 2

`endif//dpp_h