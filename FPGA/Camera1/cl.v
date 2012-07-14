module cl(input reset
  , cl_fval, input cl_x_pclk, cl_x_lval, cl_y_pclk, cl_y_lval, cl_z_pclk, cl_z_lval
  , input[7:0] cl_port_a, cl_port_b, cl_port_c, cl_port_d, cl_port_e
             , cl_port_f, cl_port_g, cl_port_h, cl_port_i, cl_port_j
  , output[7:0] led8);
`define CLK_TIMER_SIZE 27
`define LVAL_TIMER_SIZE 18
`define FVAL_TIMER_SIZE 8
  reg[`FVAL_TIMER_SIZE-1:0] timer_fval;
  //reg[`LVAL_TIMER_SIZE-1:0] timer_x_lval, timer_y_lval, timer_z_lval;
  //reg[`CLK_TIMER_SIZE-1:0] timer_x_pclk, timer_y_pclk, timer_z_pclk;
  always @(posedge reset, posedge cl_fval) begin
    if(reset) timer_fval <= 0;
    else timer_fval <= timer_fval + 1'b1;
  end
/*
  always @(posedge reset, posedge cl_x_pclk) begin
    if(reset) timer_x_pclk <= 0;
    else timer_x_pclk <= timer_x_pclk + 1'b1;
  end
  always @(posedge reset, posedge cl_x_lval) begin
    if(reset) timer_x_lval <= 0;
    else timer_x_lval <= timer_x_lval + 1'b1;
  end
  always @(posedge reset, posedge cl_y_pclk) begin
    if(reset) timer_y_pclk <= 0;
    else timer_y_pclk <= timer_y_pclk + 1'b1;
  end
  always @(posedge reset, posedge cl_y_lval) begin
    if(reset) timer_y_lval <= 0;
    else timer_y_lval <= timer_y_lval + 1'b1;
  end
  always @(posedge reset, posedge cl_z_pclk) begin
    if(reset) timer_z_pclk <= 0;
    else timer_z_pclk <= timer_z_pclk + 1'b1;
  end
  always @(posedge reset, posedge cl_z_lval) begin
    if(reset) timer_z_lval <= 0;
    else timer_z_lval <= timer_z_lval + 1'b1;
  end
  */
  //If you have a clock signal coming in, if it is routed over a global clock
  //buffer then everything that uses that clock must be after the clock buffer
  assign led8 = {3'b001, timer_fval[`FVAL_TIMER_SIZE-1]
    , cl_x_pclk == cl_y_pclk, cl_y_pclk == cl_z_pclk
    , cl_x_lval == cl_y_lval, cl_y_lval == cl_z_lval};
endmodule
