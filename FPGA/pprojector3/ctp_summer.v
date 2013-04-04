module CameraTraceRowSummer//Sums the camera trace projection through 1 FSP row
#(parameter SIMULATION=1, DELAY=1, FP_SIZE=32, CAM_ROW_SIZE=12, CAM_COL_SIZE=12
          , N_CAM=2, FSP_WIDTH=6, FSP_HEIGHT=3, FSP_ROW=2'd1)
(input CLK, RESET, init, ctrace_valid, sum_ack, xof
, input[CAM_ROW_SIZE-1:0] config_row, ctrace_row
, input[CAM_COL_SIZE-1:0] config_col, ctrace_col
, input[FP_SIZE-1:0] config_initial, grn_ctrace, red_ctrace
     , grn_fsp0, grn_fsp1, grn_fsp2, grn_fsp3, grn_fsp4, grn_fsp5
     , red_fsp0, red_fsp1, red_fsp2, red_fsp3, red_fsp4, red_fsp5
, output available, done, output reg[FP_SIZE-1:0] grn_result, red_result);
`include "function.v"
  genvar geni, genj, genk;
  integer i, j, k;
  reg [CAM_ROW_SIZE-1:0] me_row;
  reg [CAM_COL_SIZE-1:0] me_col;
  reg [FP_SIZE-1:0] me_initial, ctrace_d[N_CAM-1:0]
                  , me_fsp[N_CAM-1:0][FSP_WIDTH-1:0]
                  , me_ctrace[N_CAM-1:0][FSP_WIDTH-1:0]                  
                  , fsp_d[N_CAM-1:0][FSP_WIDTH-1:0];
  wire[FP_SIZE-1:0] ctraceXfsp[N_CAM-1:0][FSP_WIDTH-1:0]
                  , partial_sum[N_CAM-1:0][FSP_WIDTH/2:0], sum[N_CAM-1:0];
  wire[FSP_WIDTH-2:0] ctraceXfsp_rdy[N_CAM-1:0];
  wire[FSP_WIDTH/2:0] first_stage_add_rdy[N_CAM-1:0];
  wire sum_rdy;
  reg[log2(FSP_WIDTH)-1:0] n_recv, fsp_row;

  //To delay, for better timing
  reg ctrace_valid_d, start_calc;
  reg [CAM_ROW_SIZE-1:0] me_ctrace_row;
  reg signed [CAM_COL_SIZE:0] fsp_col;//signed, so an extra bit

  localparam ERROR = 0, FREE = 1, COLLECTING = 2, FINISHING = 3, DONE = 4
           , N_STATE = 5;
  reg [log2(N_STATE)-1:0] state;
  assign done = state == DONE;
  assign availabe = state == FREE;
  
  generate
    for(geni=0; geni<N_CAM-1; geni=geni+1) begin
      for(genj=0; genj<FSP_WIDTH-1; genj=genj+1)
        fmult ctraceXfsp_module(.clk(CLK), .sclr(RESET), .operation_nd(start_calc)
          , .a(me_ctrace[geni][genj]), .b(me_fsp[geni][genj])
          , .result(ctraceXfsp[geni][genj]), .rdy(ctraceXfsp_rdy[geni][genj]));

      //This cascading of adders is specific to FSP_WIDTH=6
      //1st stage adders
      fadd partial_add_module0(.clk(CLK), .sclr(RESET)
          , .operation_nd(ctraceXfsp_rdy[0])
          , .a(me_initial), .b(ctraceXfsp[0])
          , .result(partial_sum[0]), .rdy(first_stage_add_rdy[0]));
      fadd partial_add_module1(.clk(CLK), .sclr(RESET)
          , .operation_nd(ctraceXfsp_rdy[1])
          , .a(ctraceXfsp[1]), .b(ctraceXfsp[2])
          , .result(partial_sum[1]), .rdy(first_stage_add_rdy[1]));
      fadd partial_add_module2(.clk(CLK), .sclr(RESET)
          , .operation_nd(ctraceXfsp_rdy[3])
          , .a(ctraceXfsp[3]), .b(ctraceXfsp[4])
          , .result(partial_sum[2]), .rdy(first_stage_add_rdy[2]));
      fadd partial_add_module3(.clk(CLK), .sclr(RESET)
          , .operation_nd(ctraceXfsp_rdy[5])
          , .a(ctraceXfsp[5]), .b(0)
          , .result(partial_sum[3]), .rdy(first_stage_add_rdy[3]));

      fadd partial_add_module1(.clk(CLK), .sclr(RESET)
          , .operation_nd(first_stage_add_rdy[0])
          , .a(partial_sum[0]), .b(partial_sum[1])
          , .result(sum), .rdy(sum_rdy));
    end//for(N_CAM)
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
            for(i=0; i<FSP_WIDTH; i=i+1) begin//if ctrace and FSP are inited to 0
              me_fsp[i] <= #DELAY 0;      //I can do full mult and sum
              me_ctrace[i] <= #DELAY 0;   //safely at any point after this
            end//for(FSP_WIDTH)
            state <= #DELAY COLLECTING;
          end
        COLLECTING:
          if(ctrace_valid_d) begin//3 cases: before, during, after overlap
            if(me_ctrace_row > me_row
               || (me_ctrace_row == me_row && 0 > fsp_col)) begin//before
              //noop
            end else if(me_ctrace_row == me_row
                        && fsp_col >= 0 && fsp_col < FSP_WIDTH) begin//overlap
              me_ctrace[n_recv] <= #DELAY ctrace_d;
              me_fsp[n_recv] <= #DELAY fsp_d[fsp_col];
              n_recv <= #DELAY n_recv + `TRUE;
              
              if(n_recv == FSP_WIDTH-1) begin//all I can save away; HAVE TO finish
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
            for(i=0; i<FSP_WIDTH; i=i+1) begin//reset the storage
              me_fsp[i] <= #DELAY 0;
              me_ctrace[i] <= #DELAY 0;
            end//for(FSP_WIDTH)            
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
