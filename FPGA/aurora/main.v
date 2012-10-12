`timescale 1 ns / 1 ps
(* core_generation_info = "aurora8,aurora_8b10b_v5_3,{user_interface=Legacy_LL, backchannel_mode=Sidebands, c_aurora_lanes=3, c_column_used=left, c_gt_clock_1=GTXQ4, c_gt_clock_2=None, c_gt_loc_1=1, c_gt_loc_10=X, c_gt_loc_11=X, c_gt_loc_12=X, c_gt_loc_13=X, c_gt_loc_14=X, c_gt_loc_15=X, c_gt_loc_16=X, c_gt_loc_17=X, c_gt_loc_18=X, c_gt_loc_19=X, c_gt_loc_2=2, c_gt_loc_20=X, c_gt_loc_21=X, c_gt_loc_22=X, c_gt_loc_23=X, c_gt_loc_24=X, c_gt_loc_25=X, c_gt_loc_26=X, c_gt_loc_27=X, c_gt_loc_28=X, c_gt_loc_29=X, c_gt_loc_3=3, c_gt_loc_30=X, c_gt_loc_31=X, c_gt_loc_32=X, c_gt_loc_33=X, c_gt_loc_34=X, c_gt_loc_35=X, c_gt_loc_36=X, c_gt_loc_37=X, c_gt_loc_38=X, c_gt_loc_39=X, c_gt_loc_4=X, c_gt_loc_40=X, c_gt_loc_41=X, c_gt_loc_42=X, c_gt_loc_43=X, c_gt_loc_44=X, c_gt_loc_45=X, c_gt_loc_46=X, c_gt_loc_47=X, c_gt_loc_48=X, c_gt_loc_5=X, c_gt_loc_6=X, c_gt_loc_7=X, c_gt_loc_8=X, c_gt_loc_9=X, c_lane_width=2, c_line_rate=4.0, c_nfc=false, c_nfc_mode=IMM, c_refclk_frequency=125.0, c_simplex=false, c_simplex_mode=TX, c_stream=true, c_ufc=false, flow_mode=None, interface_mode=Streaming, dataflow_config=Duplex}" *)
module main#(parameter USE_CHIPSCOPE = 0, SIM_GTXRESET_SPEEDUP = 1
  , N_LANE = 1)
(input sys_rst, board_clk_p, board_clk_n, GTXQ4_P, GTXQ4_N//, GT_RESET_IN
  , input[0:N_LANE-1] RXP, RXN, output[0:N_LANE-1] TXP, TXN
  , output[7:0] GPIO_LED
);
`include "function.v"
    localparam LANE_WIDTH = 16, DATA_WIDTH = LANE_WIDTH * N_LANE;
    // Stream TX Interface
    wire    [0:DATA_WIDTH-1]     tx_d_i;
    wire               tx_src_rdy_n_i;
    wire               tx_dst_rdy_n_i;
    // Stream RX Interface
    wire    [0:DATA_WIDTH-1]     rx_d_i;
    wire               rx_src_rdy_n_i;
    // V5 Reference Clock Interface
    wire               GTXQ4_left_i;

    // Error Detection Interface
    wire               hard_err_i;
    wire               soft_err_i;
    // Status
    wire               channel_up_i;
    wire[0:N_LANE-1]   lane_up_i;
    // Clock Compensation Control Interface
    wire               warn_cc_i;
    wire               do_cc_i;
    // System Interface
    wire               pll_not_locked_i;
    wire               user_clk_i;
    wire               sync_clk_i;
    wire               reset_i;
    wire               power_down_i;
    wire    [2:0]      loopback_i;
    wire               tx_lock_i;
    wire    [2:0]     rxeqmix_in_i;
    wire    [2:0]     rxeqmix_in_lane1_i;
    wire    [2:0]     rxeqmix_in_lane2_i;
    wire    [7:0]     daddr_in_i;
    wire              dclk_in_i;
    wire              den_in_i;
    wire[LANE_WIDTH-1:0]    di_in_i;
    wire              drdy_out_unused_i;
    wire[LANE_WIDTH-1:0]    drpdo_out_unused_i;
    wire              dwe_in_i;
    wire[7:0]     daddr_in_LANE1_i;
    wire              dclk_in_LANE1_i;
    wire              den_in_LANE1_i;
    wire[LANE_WIDTH-1:0]    di_in_LANE1_i;
    wire              drdy_out_LANE1_unused_i;
    wire[LANE_WIDTH-1:0]    drpdo_out_LANE1_unused_i;
    wire              dwe_in_LANE1_i;
    wire    [7:0]     daddr_in_LANE2_i;
    wire              dclk_in_LANE2_i;
    wire              den_in_LANE2_i;
    wire[LANE_WIDTH-1:0]    di_in_LANE2_i;
    wire              drdy_out_LANE2_unused_i;
    wire[LANE_WIDTH-1:0]    drpdo_out_LANE2_unused_i;
    wire              dwe_in_LANE2_i;
    wire               tx_out_clk_i;
    wire               gt_reset_i; 
    wire               system_reset_i;
    //Frame check signals
    wire        lane_up_i_i;
    wire        tx_lock_i_i;
    wire        lane_up_reduce_i;
    wire        rst_cc_module_i;
    wire [0:DATA_WIDTH-1] tied_to_gnd_vec_i;
//*********************************Main Body of Code**********************************

  assign lane_up_reduce_i  = &lane_up_i;
  assign rst_cc_module_i   = !lane_up_reduce_i;

  IBUFDS_GTXE1 IBUFDS_GTXE1_CLK1(.I(GTXQ4_P), .IB(GTXQ4_N), .CEB(1'b0),
    .O(GTXQ4_left_i), .ODIV2());

  // Instantiate a clock module for clock division.
  aurora8_CLOCK_MODULE clock_module_i(
      .GT_CLK(tx_out_clk_i),
      .GT_CLK_LOCKED(tx_lock_i),
      .USER_CLK(user_clk_i),
      .SYNC_CLK(sync_clk_i),
      .PLL_NOT_LOCKED(pll_not_locked_i)
  );

  //____________________________Tie off unused signals_______________________________
  // System Interface
  assign  tied_to_gnd_vec_i   =   {DATA_WIDTH{`FALSE}};
  assign  power_down_i        =   1'b0;
  assign  loopback_i          =   3'b000;

  //____________________________GT Ports_______________________________
  assign  rxeqmix_in_i  =  3'b111;
  assign  daddr_in_i  =  8'h0;
  assign  dclk_in_i   =  1'b0;
  assign  den_in_i    =  1'b0;
  assign  di_in_i     =  16'h0;
  assign  dwe_in_i    =  1'b0;
  //___________________________Module Instantiations______________________________
  aurora8 #(.SIM_GTXRESET_SPEEDUP(SIM_GTXRESET_SPEEDUP))
    aurora_module_i(
        // Stream TX Interface
        .TX_D(tx_d_i),
        .TX_SRC_RDY_N(tx_src_rdy_n_i),
        .TX_DST_RDY_N(tx_dst_rdy_n_i),
        // Stream RX Interface
        .RX_D(rx_d_i),
        .RX_SRC_RDY_N(rx_src_rdy_n_i),
        // V5 Serial I/O
        .RXP(RXP),
        .RXN(RXN),
        .TXP(TXP),
        .TXN(TXN),
        // V5 Reference Clock Interface
        .GTXQ4(GTXQ4_left_i),
        // Error Detection Interface
        .HARD_ERR(hard_err_i),
        .SOFT_ERR(soft_err_i),
        // Status
        .CHANNEL_UP(channel_up_i),
        .LANE_UP(lane_up_i),
        // Clock Compensation Control Interface
        .WARN_CC(warn_cc_i),
        .DO_CC(do_cc_i),
        // System Interface
        .USER_CLK(user_clk_i),
        .SYNC_CLK(sync_clk_i),
        .RESET(reset_i),
        .POWER_DOWN(power_down_i),
        .LOOPBACK(loopback_i),
        .GT_RESET(gt_reset_i),
        .TX_LOCK(tx_lock_i),
        .RXEQMIX_IN(rxeqmix_in_i),
        .DADDR_IN  (daddr_in_i),
        .DCLK_IN   (dclk_in_i),
        .DEN_IN    (den_in_i),
        .DI_IN     (di_in_i),
        .DRDY_OUT  (drdy_out_unused_i),
        .DRPDO_OUT (drpdo_out_unused_i),
        .DWE_IN    (dwe_in_i),
        .TX_OUT_CLK(tx_out_clk_i)
    );

    aurora8_STANDARD_CC_MODULE standard_cc_module_i
    (
        .RESET(rst_cc_module_i),
        // Clock Compensation Control Interface
        .WARN_CC(warn_cc_i),
        .DO_CC(do_cc_i),
        // System Interface
        .PLL_NOT_LOCKED(pll_not_locked_i),
        .USER_CLK(user_clk_i)
    );
    aurora8_RESET_LOGIC reset_logic_i
    (
        .RESET(sys_rst),
        .USER_CLK(user_clk_i),
        .INIT_CLK_P(board_clk_p),
        .INIT_CLK_N(board_clk_n),
        //.GT_RESET_IN(GT_RESET_IN),
        .TX_LOCK_IN(tx_lock_i),
        .PLL_NOT_LOCKED(pll_not_locked_i),
        .SYSTEM_RESET(system_reset_i),
        .GT_RESET_OUT(gt_reset_i)
    );
    
    assign reset_i = system_reset_i;
    //assign GPIO_LED[3:0] = 4'd0; // To be used by Xillybus

    application#(.DATA_WIDTH(DATA_WIDTH), .N_LANE(N_LANE))
      app(.TX_D(tx_d_i), .TX_SRC_RDY_N(tx_src_rdy_n_i)
      , .TX_DST_RDY_N(tx_dst_rdy_n_i)
      , .RX_D(rx_d_i), .RX_SRC_RDY_N(rx_src_rdy_n_i)
      , .USER_CLK(user_clk_i), .RESET(reset_i)
      , .CHANNEL_UP(channel_up_i), .LANE_UP(lane_up_i)
      , .HARD_ERR(hard_err_i), .SOFT_ERR(soft_err_i)
      , .GPIO_LED(GPIO_LED)
    );
endmodule
