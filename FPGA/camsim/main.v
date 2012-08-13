module main(input CLK_P, CLK_N, reset
  , output[7:0] GPIO_LED);
  assign GPIO_LED[3:0] = {4{1'b0}};
  application#(.SIMULATION(0))
    app(CLK_P, CLK_N, reset, pc_msg_ack, pc_msg_pending, pc_msg, GPIO_LED[7:4]);
endmodule
