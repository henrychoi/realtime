// This file is part of the Xillybus project.

`timescale 1ns / 10ps

module xillybus(PCIE_TX_P, PCIE_TX_N, PCIE_RX_P, PCIE_RX_N, PCIE_REFCLK_P,
  PCIE_REFCLK_N, PCIE_PERST_B_LS, bus_clk, quiesce, GPIO_LED, user_r_rd_rden,
  user_r_rd_data, user_r_rd_empty, user_r_rd_eof, user_r_rd_open,
  user_w_wr_wren, user_w_wr_data, user_w_wr_full, user_w_wr_open,
  user_r_rd_loop_rden, user_r_rd_loop_data, user_r_rd_loop_empty,
  user_r_rd_loop_eof, user_r_rd_loop_open, user_w_wr_loop_wren,
  user_w_wr_loop_data, user_w_wr_loop_full, user_w_wr_loop_open);

  input [3:0] PCIE_RX_P;
  input [3:0] PCIE_RX_N;
  input  PCIE_REFCLK_P;
  input  PCIE_REFCLK_N;
  input  PCIE_PERST_B_LS;
  input [31:0] user_r_rd_data;
  input  user_r_rd_empty;
  input  user_r_rd_eof;
  input  user_w_wr_full;
  input [31:0] user_r_rd_loop_data;
  input  user_r_rd_loop_empty;
  input  user_r_rd_loop_eof;
  input  user_w_wr_loop_full;
  output [3:0] PCIE_TX_P;
  output [3:0] PCIE_TX_N;
  output  bus_clk;
  output  quiesce;
  output [3:0] GPIO_LED;
  output  user_r_rd_rden;
  output  user_r_rd_open;
  output  user_w_wr_wren;
  output [31:0] user_w_wr_data;
  output  user_w_wr_open;
  output  user_r_rd_loop_rden;
  output  user_r_rd_loop_open;
  output  user_w_wr_loop_wren;
  output [31:0] user_w_wr_loop_data;
  output  user_w_wr_loop_open;
  wire  trn_reset_n;
  wire  trn_lnk_up_n;
  wire [63:0] trn_td;
  wire  trn_tsof_n;
  wire  trn_teof_n;
  wire  trn_tsrc_rdy_n;
  wire  trn_tdst_rdy_n;
  wire  trn_trem_n;
  wire [63:0] trn_rd;
  wire  trn_rsof_n;
  wire  trn_reof_n;
  wire  trn_rsrc_rdy_n;
  wire  trn_rdst_rdy_n;
  wire  trn_rerrfwd_n;
  wire  trn_rnp_ok_n;
  wire  trn_rrem_n;
  wire  trn_terr_drop_n;
  wire [6:0] trn_rbar_hit_n;
  wire  cfg_interrupt_n;
  wire  cfg_interrupt_rdy_n;
  wire [7:0] cfg_bus_number;
  wire [4:0] cfg_device_number;
  wire [2:0] cfg_function_number;
  wire [15:0] cfg_dcommand;
  wire [15:0] cfg_lcommand;
  wire [15:0] cfg_dstatus;
  wire [7:0] trn_fc_cplh;
  wire [11:0] trn_fc_cpld;
  wire  pcie_ref_clk;

   // This perl snippet turns the input/output ports to wires, so only
   // those that really connect something become real ports (input/output
   // keywords are used to create global variables)

   IBUFDS_GTXE1 pcieclk_ibuf (.O(pcie_ref_clk), .ODIV2(),
			      .I(PCIE_REFCLK_P), .IB(PCIE_REFCLK_N));

   pcie_v6_4x pcie
     (
     .pci_exp_txp( PCIE_TX_P ),
     .pci_exp_txn( PCIE_TX_N ),
     .pci_exp_rxp( PCIE_RX_P ),
     .pci_exp_rxn( PCIE_RX_N ),

     .trn_clk(bus_clk),
     .trn_reset_n(trn_reset_n),
     .trn_lnk_up_n(trn_lnk_up_n),

     .trn_td( trn_td ),
     .trn_trem_n( trn_trem_n ),
     .trn_tsof_n( trn_tsof_n ),
     .trn_teof_n( trn_teof_n ),
     .trn_tsrc_rdy_n( trn_tsrc_rdy_n ),
     .trn_tsrc_dsc_n(1'b1),
     .trn_tdst_rdy_n( trn_tdst_rdy_n ),
     .trn_terrfwd_n( 1'b1 ), // Ignored anyhow
     .trn_tbuf_av(  ),       // Not used
     .trn_terr_drop_n(trn_terr_drop_n), // Not used.
     .trn_tstr_n( 1'b1 ), // No streaming
     .trn_tcfg_gnt_n( 1'b0 ), // Always grant configuration transmit

     .trn_rd( trn_rd ),
     .trn_rrem_n( trn_rrem_n ),
     .trn_rsof_n( trn_rsof_n ),
     .trn_reof_n( trn_reof_n ),
     .trn_rsrc_rdy_n( trn_rsrc_rdy_n ),
     .trn_rsrc_dsc_n( ), // Ignored. Used on link reset only anyhow.
     .trn_rdst_rdy_n( trn_rdst_rdy_n ),
     .trn_rerrfwd_n( trn_rerrfwd_n ),
     .trn_rnp_ok_n( trn_rnp_ok_n ),
     .trn_rbar_hit_n( trn_rbar_hit_n ),

     .trn_fc_cpld(trn_fc_cpld), // Completion Data credits
     .trn_fc_cplh(trn_fc_cplh), // Completion Header credits
     .trn_fc_npd(  ),
     .trn_fc_nph(  ),
     .trn_fc_pd(  ),
     .trn_fc_ph(  ),
     .trn_fc_sel(3'd0), // Receive credit available space

     .cfg_do(  ),
     .cfg_rd_wr_done_n( ),
     .cfg_di( 32'd0 ),
     .cfg_byte_en_n( 4'hf ),
     .cfg_dwaddr( 10'd0 ),
     .cfg_wr_en_n( 1'b1 ),
     .cfg_rd_en_n( 1'b1 ),

     .cfg_err_cor_n(1'b1),
     .cfg_err_ur_n(1'b1),
     .cfg_err_cpl_rdy_n(),
     .cfg_err_ecrc_n(1'b1),
     .cfg_err_cpl_timeout_n(1'b1),
     .cfg_err_cpl_abort_n(1'b1),
     .cfg_err_cpl_unexpect_n(1'b1),
     .cfg_err_posted_n(1'b1),
     .cfg_err_tlp_cpl_header(48'd0),
     .cfg_err_locked_n(1'b1),

     .cfg_interrupt_n( cfg_interrupt_n ),
     .cfg_interrupt_rdy_n( cfg_interrupt_rdy_n ),
     
     .cfg_interrupt_assert_n(1'b1),
     .cfg_interrupt_di(8'd0), // Single MSI anyhow
     .cfg_interrupt_do(),
     .cfg_interrupt_mmenable(),
     .cfg_interrupt_msienable(),          
     .cfg_interrupt_msixenable(  ),
     .cfg_interrupt_msixfm(  ),

     .cfg_to_turnoff_n( ),
     .cfg_pm_wake_n(1'b1),
     .cfg_pcie_link_state_n( ),
     .cfg_trn_pending_n(1'b1),

     .cfg_bus_number( cfg_bus_number ),
     .cfg_device_number( cfg_device_number ),
     .cfg_function_number( cfg_function_number ),
     .cfg_status(  ),
     .cfg_command( ),
     .cfg_dstatus( cfg_dstatus ),
     .cfg_dcommand( cfg_dcommand ),
     .cfg_lstatus(  ),
     .cfg_lcommand( cfg_lcommand ),
     .cfg_dsn(64'd0),
          
     .cfg_turnoff_ok_n( 1'b1 ),
     .cfg_dcommand2(  ),
     .cfg_pmcsr_pme_en(  ),
     .cfg_pmcsr_pme_status(  ),
     .cfg_pmcsr_powerstate(  ),

     .pl_initial_link_width(  ),
     .pl_lane_reversal_mode(  ),
     .pl_link_gen2_capable(  ),
     .pl_link_partner_gen2_supported(  ),
     .pl_link_upcfg_capable( ),
     .pl_ltssm_state( ),
     .pl_received_hot_rst( ),
     .pl_sel_link_rate(  ),
     .pl_sel_link_width( ),
     .pl_directed_link_auton( 1'b0 ),
     .pl_directed_link_change( 2'b00 ), // Don't change link parameters
     .pl_directed_link_speed( 1'b1 ), // Ignored by PCIe core
     .pl_directed_link_width( 2'b11 ),  // Ignored by PCIe core
     .pl_upstream_prefer_deemph( 1'b0 ), // Ignored by PCIe core

     .sys_clk(pcie_ref_clk),
     .sys_reset_n( PCIE_PERST_B_LS )
      );

  xillybus_core  xillybus_core_ins(.trn_reset_n_w(trn_reset_n),
    .trn_lnk_up_n_w(trn_lnk_up_n), .quiesce_w(quiesce), .GPIO_LED_w(GPIO_LED),
    .trn_td_w(trn_td), .trn_tsof_n_w(trn_tsof_n), .trn_teof_n_w(trn_teof_n),
    .trn_tsrc_rdy_n_w(trn_tsrc_rdy_n), .trn_tdst_rdy_n_w(trn_tdst_rdy_n),
    .trn_trem_n_w(trn_trem_n), .trn_rd_w(trn_rd), .trn_rsof_n_w(trn_rsof_n),
    .trn_reof_n_w(trn_reof_n), .trn_rsrc_rdy_n_w(trn_rsrc_rdy_n),
    .trn_rdst_rdy_n_w(trn_rdst_rdy_n), .trn_rerrfwd_n_w(trn_rerrfwd_n),
    .trn_rnp_ok_n_w(trn_rnp_ok_n), .trn_rrem_n_w(trn_rrem_n),
    .trn_terr_drop_n_w(trn_terr_drop_n), .trn_rbar_hit_n_w(trn_rbar_hit_n),
    .cfg_interrupt_n_w(cfg_interrupt_n), .cfg_interrupt_rdy_n_w(cfg_interrupt_rdy_n),
    .cfg_bus_number_w(cfg_bus_number), .cfg_device_number_w(cfg_device_number),
    .cfg_function_number_w(cfg_function_number), .cfg_dcommand_w(cfg_dcommand),
    .cfg_lcommand_w(cfg_lcommand), .cfg_dstatus_w(cfg_dstatus),
    .trn_fc_cplh_w(trn_fc_cplh), .trn_fc_cpld_w(trn_fc_cpld),
    .user_r_rd_rden_w(user_r_rd_rden), .user_r_rd_data_w(user_r_rd_data),
    .user_r_rd_empty_w(user_r_rd_empty), .user_r_rd_eof_w(user_r_rd_eof),
    .user_r_rd_open_w(user_r_rd_open), .user_w_wr_wren_w(user_w_wr_wren),
    .user_w_wr_data_w(user_w_wr_data), .user_w_wr_full_w(user_w_wr_full),
    .user_w_wr_open_w(user_w_wr_open), .user_r_rd_loop_rden_w(user_r_rd_loop_rden),
    .user_r_rd_loop_data_w(user_r_rd_loop_data), .user_r_rd_loop_empty_w(user_r_rd_loop_empty),
    .user_r_rd_loop_eof_w(user_r_rd_loop_eof), .user_r_rd_loop_open_w(user_r_rd_loop_open),
    .user_w_wr_loop_wren_w(user_w_wr_loop_wren), .user_w_wr_loop_data_w(user_w_wr_loop_data),
    .user_w_wr_loop_full_w(user_w_wr_loop_full), .user_w_wr_loop_open_w(user_w_wr_loop_open),
    .bus_clk_w(bus_clk));

endmodule
