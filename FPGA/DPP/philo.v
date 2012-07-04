`timescale 1ns / 1ps
`include "dpp.v" //"Header"

module philo
#(parameter TIMER_SIZE = 3, parameter EAT_TIME = 2, parameter THINK_TIME = 5)
(input clk, input reset
, input[`SIG_SIZE-1:0] event_in
, output reg [`PHILO_STATE_SIZE-1:0] state
);
  //localparam TIME_ZERO = 'b000;
  /*
  localparam //These are like the enums in SW HSM..............................
    thinking = 'b01 //Connect bit[0] to LED pin
    , hungry = 'b00
    , eating = 'b10;
  */
  reg [TIMER_SIZE-1:0] timer, t;
  reg [`PHILO_STATE_SIZE-1:0] next_state;

  always @(posedge clk or posedge reset) begin
    if(reset) begin
      state <= `thinking; //This should really be in the initial action
      timer <= 0;
      t <= 0;
    end else begin
      timer <= timer + 1;
      state <= next_state;
      t <= t + 1;
    end
  end//always
  
  //State transition logics
  always @(posedge event_in[`EAT_SIG]) begin
    case(state)
      `hungry: //begin
        next_state <= `eating;
        //timer <= 0;
      //end
    endcase
  end//always

  always @(*) begin
    //state <= next_state;//original C1 statement
    case(state)
      `thinking: //begin
        //if(timer == THINK_TIME) begin
          next_state <= `hungry;
        //end
      //end
            
      `eating: //begin
        //if(timer == EAT_TIME) begin
          next_state <= `thinking;
          //timer <= 0;
        //end
      //end
    endcase
  end//always
  //assign thinking_out = (state == thinking);
endmodule
