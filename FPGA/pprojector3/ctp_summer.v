module CameraTraceRowSummer//Sums the camera trace projection through 1 FSP row
#(parameter SIMULATION=1, DELAY=1, FP_SIZE=32, CAM_ROW_SIZE=12, CAM_COL_SIZE=12
          , N_FSP=3, FSP_ROW=2'd1)
(input CLK, RESET, init, ctrace_valid, sum_ack, xof
, input[CAM_ROW_SIZE-1:0] config_row, ctrace_row
, input[CAM_COL_SIZE-1:0] config_col, ctrace_col
, input[FP_SIZE-1:0] config_bias//global sensor background
                   , ctrace, fsp0, fsp1, fsp2//will take one of these on overlap
, output available, done, output reg[FP_SIZE-1:0] result);
`include "function.v"
  genvar geni, genj, genk;
  integer i, j, k;
  reg [CAM_ROW_SIZE-1:0] me_row;
  reg [CAM_COL_SIZE-1:0] me_col;
  reg [FP_SIZE-1:0] me_bias, me_fsp[N_FSP-1:0], me_ctrace[N_FSP-2:0];
  wire[FP_SIZE-1:0] ctraceXfsp[N_FSP-1:0], partial_sum[N_FSP/2:0]
                  , sum;
  wire[N_FSP-2:0] ctraceXfsp_rdy;
  wire[N_FSP/2:0] first_stage_add_rdy;
  wire sum_rdy;
  reg[log2(N_FSP)-1:0] n_recv, fsp_row;

  localparam ERROR = 0, FREE = 1, COLLECTING = 2, FINISHING = 3, DONE = 4
           , N_STATE = 5;
  reg [log2(N_STATE)-1:0] state;
  assign done = state == DONE;
  assign availabe = state == FREE;
  
  generate
    for(geni=0; geni<N_FSP-1; geni=geni+1)
      fmult ctraceXfsp_module(.clk(CLK), .sclr(RESET), .operation_nd()
          , .a(me_ctrace[geni]), .b(me_fsp[geni])
          , .result(ctraceXfsp[geni]), .rdy(ctraceXfsp_rdy[geni]));

    //This cascading of adders is specific to N_FSP=3
    fadd partial_add_module0(.clk(CLK), .sclr(RESET)
        , .operation_nd(ctraceXfsp_rdy[0])
        , .a(me_bias), .b(ctraceXfsp[0])
        , .result(partial_sum[0]), .rdy(first_stage_add_rdy[0]));
    fadd partial_add_module1(.clk(CLK), .sclr(RESET)
        , .operation_nd(ctraceXfsp_rdy[1])
        , .a(ctraceXfsp[1]), .b(ctraceXfsp[2])
        , .result(partial_sum[1]), .rdy(first_stage_add_rdy[1]));
    fadd partial_add_module1(.clk(CLK), .sclr(RESET)
        , .operation_nd(first_stage_add_rdy[0])
        , .a(partial_sum[0]), .b(partial_sum[1])
        , .result(sum), .rdy(sum_rdy));
  endgenerate

  always @(posedge CLK) begin
  
    if(RESET) begin
      state <= #DELAY FREE;
    end else begin
    
      case(state)
        FREE:
          if(init) begin
            me_row <= #DELAY config_row;
            me_col <= #DELAY config_col;
            me_bias <= #DELAY config_bias;
            for(i=0; i<N_FSP; i=i+1) begin
              me_fsp[i] <= #DELAY 0;
              me_ctrace[i] <= #DELAY 0;
            end//for(N_FSP)
            n_recv <= #DELAY 0;
            state <= #DELAY COLLECTING;
          end
        COLLECTING:
          if(ctrace_valid) begin
            if(ctrace_row
            me_ctrace[n_recv] <= #DELAY ctrace;
            n_recv <= #DELAY n_recv + `TRUE;
          end
        FINISHING:
          if(sum_rdy) begin
            result <= #DELAY sum;
            state <= #DELAY DONE;
          end
        DONE:
          if(sum_ack)
            state <= #DELAY FREE;
        default: begin//What to do in case of an error?
        end
      endcase
    end
  end
endmodule
