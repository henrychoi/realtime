module CameraTraceRowSummer//Sums the camera trace projection through 1 FSP row
#(parameter SIMULATION=1, DELAY=1, FP_SIZE=32, CAM_ROW_SIZE=12, CAM_COL_SIZE=12
          , N_FSP=3, FSP_ROW=2'd1)
(input CLK, RESET, init, ctrace_valid, sum_ack, xof
, input[CAM_ROW_SIZE-1:0] config_row, ctrace_row
, input[CAM_COL_SIZE-1:0] config_col, ctrace_col
, input[FP_SIZE-1:0] config_initial
                   , ctrace, fsp0, fsp1, fsp2//will take one of these on overlap
, output available, done, output reg[FP_SIZE-1:0] result);
`include "function.v"
  genvar geni, genj, genk;
  integer i, j, k;
  reg [CAM_ROW_SIZE-1:0] me_row;
  reg [CAM_COL_SIZE-1:0] me_col;
  reg [FP_SIZE-1:0] me_initial, me_fsp[N_FSP-1:0], me_ctrace[N_FSP-1:0]
                  , ctrace_d
                  , fsp_d[N_FSP-1:0];//This has to match # of fsp input args
  wire[FP_SIZE-1:0] ctraceXfsp[N_FSP-1:0], partial_sum[N_FSP/2:0], sum;
  wire[N_FSP-2:0] ctraceXfsp_rdy;
  wire[N_FSP/2:0] first_stage_add_rdy;
  wire sum_rdy;
  reg[log2(N_FSP)-1:0] n_recv, fsp_row;

  //To delay, for better timing
  reg ctrace_valid_d, start_calc;
  reg       [CAM_ROW_SIZE-1:0] me_ctrace_row;
  reg signed[CAM_COL_SIZE:0] fsp_col;//signed, so an extra bit

  localparam ERROR = 0, FREE = 1, COLLECTING = 2, FINISHING = 3, DONE = 4
           , N_STATE = 5;
  reg [log2(N_STATE)-1:0] state;
  assign done = state == DONE;
  assign availabe = state == FREE;
  
  generate
    for(geni=0; geni<N_FSP-1; geni=geni+1)
      fmult ctraceXfsp_module(.clk(CLK), .sclr(RESET), .operation_nd(start_calc)
          , .a(me_ctrace[geni]), .b(me_fsp[geni])
          , .result(ctraceXfsp[geni]), .rdy(ctraceXfsp_rdy[geni]));

    //This cascading of adders is specific to N_FSP=3
    fadd partial_add_module0(.clk(CLK), .sclr(RESET)
        , .operation_nd(ctraceXfsp_rdy[0])
        , .a(me_initial), .b(ctraceXfsp[0])
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
    start_calc <= #DELAY `FALSE;
    //Delay the input for better timing
    ctrace_valid_d <= #DELAY ctrace_valid;
    ctrace_d <= #DELAY ctrace;
    fsp_d[0] <= #DELAY fsp0; fsp_d[1] <= #DELAY fsp1; fsp_d[2] <= #DELAY fsp2;
    me_ctrace_row <= #DELAY ctrace_row + FSP_ROW;//Note: instantiation param
    fsp_col <= #DELAY me_col - ctrace_col;//signed arithmetic
    
    if(RESET) begin
      n_recv <= #DELAY 0;
      state <= #DELAY FREE;
    end else begin
      
      case(state)
        FREE:
          if(init) begin
            me_row <= #DELAY config_row;
            me_col <= #DELAY config_col;
            me_initial <= #DELAY config_initial;
            for(i=0; i<N_FSP; i=i+1) begin//if ctrace and FSP are inited to 0
              me_fsp[i] <= #DELAY 0;      //I can do full mult and sum
              me_ctrace[i] <= #DELAY 0;   //safely at any point after this
            end//for(N_FSP)
            state <= #DELAY COLLECTING;
          end
        COLLECTING:
          if(ctrace_valid_d) begin//3 cases: before, during, after overlap
            if(me_ctrace_row > me_row
               || (me_ctrace_row == me_row && 0 > fsp_col)) begin//before
              //noop
            end else if(me_ctrace_row == me_row
                        && fsp_col >= 0 && fsp_col < N_FSP) begin//overlap
              me_ctrace[n_recv] <= #DELAY ctrace_d;
              me_fsp[n_recv] <= #DELAY fsp_d[fsp_col];
              n_recv <= #DELAY n_recv + `TRUE;
              
              if(n_recv == N_FSP-1) begin//all I can save away; HAVE TO finish
                n_recv <= #DELAY 0;
                start_calc <= #DELAY `TRUE;//Kick off the calculation
                state <= #DELAY FINISHING;
              end
            end else begin //after
              n_recv <= #DELAY 0;
              if(n_recv) begin//Received at least 1 projection
                start_calc <= #DELAY `TRUE;//Kick off the calculation
                state <= #DELAY FINISHING;
              end else begin//didn't receive any projection => result = initial
                result <= #DELAY me_initial;
                state <= #DELAY DONE;
              end
            end
          end
        FINISHING:
          if(sum_rdy) begin
            result <= #DELAY sum;//copy it out
            for(i=0; i<N_FSP; i=i+1) begin//reset the storage
              me_fsp[i] <= #DELAY 0;
              me_ctrace[i] <= #DELAY 0;
            end//for(N_FSP)            
            state <= #DELAY DONE;
          end
        DONE:
          if(sum_ack) state <= #DELAY FREE;

        default: begin//What to do in case of an error?
        end
      endcase
    end
  end
endmodule
