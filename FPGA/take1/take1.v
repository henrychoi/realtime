module take1#(parameter N_PHILO = 2)
(input clk, input reset, output[N_PHILO-1:0] LEDs_Positions_TRI_O);
  localparam TIMER_SIZE = 3;
  reg [TIMER_SIZE-1:0] timer, t;
  reg [2-1:0] state, next_state;

  always @(posedge clk or posedge reset) begin
    if(reset) begin
      state <= 'b10;
      timer <= 0;
      t <= 0;
    end else begin
      timer <= timer + 1;
      state <= next_state;
      t <= t + 1;
    end
  end//always

endmodule
