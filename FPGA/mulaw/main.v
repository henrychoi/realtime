module main#(parameter SIMULATION=0, DELAY=1)
(input RESET, CLK_P, CLK_N);
`include "function.v"
  wire CLK;
  IBUFGDS sysclk_buf(.I(CLK_P), .IB(CLK_N), .O(CLK));
  localparam FP_SIZE = 32, N_PATCH = 600000;
  reg [11:0] random;

  application#(.DELAY(DELAY), .FP_SIZE(FP_SIZE), .N_PATCH(N_PATCH))
    app(.CLK(CLK), .RESET(RESET)
      , .patch_num({{(log2(N_PATCH)-12){`FALSE}}, random})
      , .x({random[11], 8'd126, random[10:0], {(FP_SIZE-20){`FALSE}}}));

  always @(posedge CLK) begin
    if(RESET) random <= #DELAY 0;
    else random <= #DELAY {random[10:0]
        , !(random[11] ^ random[10] ^ random[9] ^ random[3])};
  end//always
endmodule
