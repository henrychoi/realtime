`timescale 1 ns / 1 ps
(* core_generation_info = "aurora8,aurora_8b10b_v5_3,{user_interface=Legacy_LL, backchannel_mode=Sidebands, c_aurora_lanes=3, c_column_used=left, c_gt_clock_1=GTXQ0, c_gt_clock_2=None, c_gt_loc_1=1, c_gt_loc_10=X, c_gt_loc_11=X, c_gt_loc_12=X, c_gt_loc_13=X, c_gt_loc_14=X, c_gt_loc_15=X, c_gt_loc_16=X, c_gt_loc_17=X, c_gt_loc_18=X, c_gt_loc_19=X, c_gt_loc_2=2, c_gt_loc_20=X, c_gt_loc_21=X, c_gt_loc_22=X, c_gt_loc_23=X, c_gt_loc_24=X, c_gt_loc_25=X, c_gt_loc_26=X, c_gt_loc_27=X, c_gt_loc_28=X, c_gt_loc_29=X, c_gt_loc_3=3, c_gt_loc_30=X, c_gt_loc_31=X, c_gt_loc_32=X, c_gt_loc_33=X, c_gt_loc_34=X, c_gt_loc_35=X, c_gt_loc_36=X, c_gt_loc_37=X, c_gt_loc_38=X, c_gt_loc_39=X, c_gt_loc_4=X, c_gt_loc_40=X, c_gt_loc_41=X, c_gt_loc_42=X, c_gt_loc_43=X, c_gt_loc_44=X, c_gt_loc_45=X, c_gt_loc_46=X, c_gt_loc_47=X, c_gt_loc_48=X, c_gt_loc_5=X, c_gt_loc_6=X, c_gt_loc_7=X, c_gt_loc_8=X, c_gt_loc_9=X, c_lane_width=2, c_line_rate=4.0, c_nfc=false, c_nfc_mode=IMM, c_refclk_frequency=125.0, c_simplex=false, c_simplex_mode=TX, c_stream=true, c_ufc=false, flow_mode=None, interface_mode=Streaming, dataflow_config=Duplex}" *)
module aurora8_RESET_LOGIC(
//***********************************Port Declarations*******************************
  // User I/O
  input RESET, USER_CLK, INIT_CLK_P, INIT_CLK_N//, GT_RESET_IN;
  , input TX_LOCK_IN, PLL_NOT_LOCKED,
  output SYSTEM_RESET, output reg GT_RESET_OUT);
`include "function.v"
`define DLY #1
//**************************Internal Register Declarations****************************
    reg     [0:3]      debounce_gt_rst_r;
    reg     [0:3]      reset_debounce_r;
    reg                reset_debounce_r2;
    reg                reset_debounce_r3;
    reg                reset_debounce_r4;
//********************************Wire Declarations**********************************

    wire               init_clk_i;
    wire               gt_rst_r; 

//*********************************Main Body of Code**********************************


//_________________Debounce the Reset and PMA init signal___________________________
// Simple Debouncer for Reset button. The debouncer has an
// asynchronous reset tied to GT_RESET_IN. This is primarily for simulation, to ensure
// that unknown values are not driven into the reset line

    always @(posedge USER_CLK or posedge gt_rst_r)
        if(gt_rst_r)
            reset_debounce_r    <=  4'b0000;    
        else
            reset_debounce_r    <=  {RESET,reset_debounce_r[0:2]}; 

    always @ (posedge USER_CLK)
    begin
      reset_debounce_r2 <= &reset_debounce_r;
      reset_debounce_r3 <= reset_debounce_r2 || !TX_LOCK_IN;
      reset_debounce_r4 <= reset_debounce_r3;
    end

    assign SYSTEM_RESET = reset_debounce_r4 || PLL_NOT_LOCKED;

  // Assign an IBUFDS to INIT_CLK
  IBUFDS init_clk_ibufg_i
  (
   .I(INIT_CLK_P),
   .IB(INIT_CLK_N),
   .O(init_clk_i)
  );

  // According to http://forums.xilinx.com/t5/Connectivity/Utilizing-aurora-core-in-ML605/m-p/143786#M2244
  // "the INIT_CLK needs to be half the REF_CLK frequency or less to permit
  // the Aurora logic to initialise properly."
`ifdef POOR_IMPLEMENTATION
  localparam RESET_DELAY = 20;
  reg[RESET_DELAY:0] reset_d;
  reg skip;
  // Debounce the GT_RESET_IN signal using the INIT_CLK
  always @(posedge init_clk_i) begin
    reset_d <= RESET;
    reset_d[RESET_DELAY:1] <= reset_d[RESET_DELAY-1:0];

    if(RESET) begin
      skip <= `TRUE;
      //reset_d <= 0;
      debounce_gt_rst_r <= 0;
    end else begin
      skip <= ~skip;
      if(!skip) debounce_gt_rst_r <= {reset_d[RESET_DELAY], debounce_gt_rst_r[0:2]};
    end  
  end
`endif//POOR_IMPLEMENTATION

  localparam NO = 0, YES = 1, WAIT = 2, N_STATE = 3
    , N_MIN_GTX_RESET = 8;
  reg[log2(N_STATE)-1:0] state;
  reg[log2(N_MIN_GTX_RESET)-1:0] ctr;

  assign gt_rst_r = &debounce_gt_rst_r;
  always @(posedge init_clk_i) begin
    debounce_gt_rst_r <= {RESET, debounce_gt_rst_r[0:2]};
    case(state)
      default: begin
        GT_RESET_OUT <= `FALSE;
        if(gt_rst_r) begin
          ctr <= 1;
          GT_RESET_OUT <= `TRUE;
          state <= YES;
        end
      end
      YES: begin
        GT_RESET_OUT <= `TRUE;
        ctr <= ctr + `TRUE;
        if(!ctr) state <= WAIT;
      end
      WAIT: begin
        GT_RESET_OUT <= `TRUE;
        if(!debounce_gt_rst_r) begin
          GT_RESET_OUT <= `FALSE;
          state <= NO;
        end
      end
    endcase
  end//always

endmodule
