`include "dpp.v" //"Header"

module philo
#(parameter EAT_TIME = 2, parameter THINK_TIME = 5)
(input clk, input reset, input[`EVENT_SIZE-1:0] event_in
);
`include "function.v"
  //localparam MAX_TIME = max(EAT_TIME, THINK_TIME);//ZERO_TIME = 'b000;
  localparam TIMER_SIZE = log2(max(EAT_TIME, THINK_TIME));
  localparam //These are like the enums in SW HSM..............................
    thinking = 0//'b01 //Connect bit[0] to LED pin
    , hungry = 1//'b00
    , eating = 2//'b10,
    , NUM_STATES = 3;
  reg signed [TIMER_SIZE:0] timer;//sized for sign bit to detect underflow
  reg [log2(NUM_STATES)-1:0] state;//,next_state;

  //function integer timer_size();
  //  begin
  //    timer_size = MAX(EAT_TIME, THINK_TIME);
  //    timer_size = log2(timer_size);
  //  end
  //endfunction
  
  //function reg[`PHILO_STATE_SIZE-1:0] trans(input reg[`PHILO_STATE_SIZE-1:0] target)
  //  case(target)//Things I have to do when transitioning to different state
  //    `thinking: timer <= THINK_TIME;
  //    `eating: timer <= EAT_TIME;
  //  endcase
  //  trans = target;
  //endfunction
  
  always @(posedge clk or posedge reset) begin
    if(reset) begin
      timer <= THINK_TIME;
      state <= thinking;//trans(`thinking)
    end else begin
      //state <= next_state;
      timer <= timer - 1;
    end
  end//always

  always @(posedge timer[TIMER_SIZE])//when timer underflows (i.e. expires)
  begin
    case(state)
      thinking: begin
        // Turn off LED
        state <= hungry ;//Transition
      end
      
      eating: begin
        // ^DONE
        timer <= THINK_TIME;
        state <= thinking; //Transition
      end
    endcase
  end//always
  
  //assign state = reset ? `thinking : next_state;

  /*
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
      `thinking: begin
        if(timer == THINK_TIME) begin
          next_state <= `hungry;
        end
      end
            
      `eating: begin
        //if(timer == EAT_TIME) begin
          next_state <= `thinking;
          timer <= 0;
        end
      end
    endcase
  end//always
  //assign thinking_out = (state == thinking);
  */
endmodule
