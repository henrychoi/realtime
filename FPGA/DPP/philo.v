`include "dpp.v" //"Header"

module philo
#(parameter ID=0, parameter EAT_TIME=2, parameter THINK_TIME=5)
(input clk, input reset
, input [`TABLE_EVENT_SIZE:0] event_s
, output reg[`PHILO_EVENT_SIZE:0] event_p
);
`include "function.v"
  //localparam MAX_TIME = max(EAT_TIME, THINK_TIME);//ZERO_TIME = 'b000;
  localparam TIMER_SIZE = log2(max(EAT_TIME, THINK_TIME));
  localparam //These are like the enums in SW HSM..............................
    thinking = 1//'b01 //Connect bit[0] to LED pin
    , hungry = 0//'b00
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

  initial begin
    event_p = 0;
  end
  
  always @(posedge clk, posedge reset) begin
    if(reset) begin
      event_p <= 0;//{1'b0, `PHILO_EVENT_SIZE'b0};
      timer <= THINK_TIME;
      state <= thinking;//trans(`thinking)
    end else begin // just clk
      if(event_p[`PHILO_EVENT_SIZE]) begin
        event_p[`PHILO_EVENT_SIZE] <= 1'b1;
        //event_p <= {1'b0, event_p[`PHILO_EVENT_SIZE-1:0]};
      end
    end
  end//always

  always @(posedge timer[TIMER_SIZE]//when timer underflows (i.e. expires)
    , posedge event_s[`TABLE_EVENT_SIZE]) begin //An event for me!
    case(state)
      thinking:
        if(event_s[`TABLE_EVENT_SIZE]) begin
        end else begin
          event_p <= {1'b1,`PHILO_HUNGRY};//^HUNGRY
          state <= hungry;//Transition
        end
      eating:
        if(event_s[`TABLE_EVENT_SIZE]) begin
        end else begin
          event_p <= {1'b1,`PHILO_DONE};//^DONE
          timer <= THINK_TIME;
          state <= thinking; //Transition
        end
      hungry:
        if(event_s[`TABLE_EVENT_SIZE]) begin
          timer <= EAT_TIME;
          state <= eating;//Transition
        end else begin
        end
      default: begin
      end
    endcase
  end//always
/*
  always @(event_s[`TABLE_EVENT_SIZE]) begin //An event for me!
    //In this case, there can only be 1 event: EAT
    case(state)
      hungry: begin
        timer <= EAT_TIME;
        state <= eating;//Transition
      end
      default: begin
      end
    endcase
  end//always @(posedge reset)
*/  
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
