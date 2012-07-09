`include "dpp.v" //"Header"

module philo#(parameter EAT_TIME=2, parameter THINK_TIME=5)
(input clk, input reset, input may_eat, input foutAck
, output thinking, output foutData, output foutEmpty);
`include "function.v"
  localparam THINKING = 0, EATING = 1, HUNGRY = 2, MAX_STATE = 3;
  reg[log2(MAX_STATE)-1:0] state;
  localparam TIMER_SIZE = log2(max(EAT_TIME, THINK_TIME));
  reg [TIMER_SIZE-1:0] timer;
  wire l_finEmpty;//, l_dout_dontcare;
  reg l_event, l_foutWren, l_finAck;

  philo_fifo fin(.clk(clk), .srst(reset)
    ,.din(may_eat), .wr_en(may_eat), .rd_en(l_finAck)
    , .dout(), .full(), .empty(l_finEmpty));

  philo_fifo fout(.clk(clk), .srst(reset)
    , .din(l_event), .wr_en(l_foutWren), .rd_en(foutAck)
    , .dout(foutData), .full(), .empty(foutEmpty));
  
  assign hungry = state[1]; //The hungry bit
  //assign evtIntr = ~l_finEmpty;
  
  always @(posedge clk, posedge reset
    //, posedge evtIntr //This caused weird infinite combinational loop
    ) begin
    if(reset) begin
      l_foutWren <= `FALSE;  //default value
      l_event <= `PHILO_DONE;//default value
      l_finAck <= `FALSE;    //default value
    
      timer <= THINK_TIME; //Initial transition
      state <= THINKING;
    end else begin //!reset, i.e. sequential logic
      l_foutWren <= `FALSE; //default value
      l_event <= `PHILO_DONE;//default value
      l_finAck <= `FALSE;    //default value

      if(!l_finEmpty && !l_finAck) begin // There is a message for me!
        // But I already know what the message is: EAT
        l_finAck <= `TRUE;//Read it; pop this event from FIFO
        timer <= EAT_TIME;
        state <= EATING;
      end else begin //no signal; just check ther timer
        if(timer) begin
          timer <= timer - 1'b1; //decrement the timer by default
        end else begin
          case(state)
            THINKING: begin
              l_event <= `PHILO_HUNGRY;
              l_foutWren <= `TRUE;//Shove the event into FIFO
              l_finAck <= `FALSE;    //default value
              state <= HUNGRY;//Transition
            end
            EATING: begin
              l_event <= `PHILO_DONE;
              l_foutWren <= `TRUE;//Shove the event into FIFO
              l_finAck <= `FALSE;    //default value
              timer <= THINK_TIME;
              state <= THINKING; //Transition
            end
            default: begin
              timer <= timer - 1'b1; //decrement the timer by default
            end
          endcase//state
        end//if(!timer)
      end//check timer
    end//!reset branch
  end//always
endmodule
