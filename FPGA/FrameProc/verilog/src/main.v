`timescale 1ps/1ps

module main #(parameter SIMULATION = 0,
   parameter REFCLK_FREQ             = 200,
                                       // # = 200 when design frequency <= 533 MHz,
                                       //   = 300 when design frequency > 533 MHz.
   parameter IODELAY_GRP             = "IODELAY_MIG",
                                       // It is associated to a set of IODELAYs with
                                       // an IDELAYCTRL that have same IODELAY CONTROLLER
                                       // clock frequency.
   parameter MMCM_ADV_BANDWIDTH      = "OPTIMIZED",
                                       // MMCM programming algorithm
   parameter CLKFBOUT_MULT_F         = 6,
                                       // write PLL VCO multiplier.
   parameter DIVCLK_DIVIDE           = 1,  // ML605 200MHz input clock (VCO = 1200MHz)use "2" for 400MHz SMA,
                                       // write PLL VCO divisor.
   parameter CLKOUT_DIVIDE           = 3,  //400MHz clock
                                       // VCO output divisor for fast (memory) clocks.
   parameter nCK_PER_CLK             = 2,
                                       // # of memory CKs per fabric clock.
                                       // # = 2, 1.
   parameter tCK                     = 2500,
                                       // memory tCK paramter.
                                       // # = Clock Period.
   parameter DEBUG_PORT              = "OFF",//"ON",
                                       // # = "ON" Enable debug signals/controls.
                                       //   = "OFF" Disable debug signals/controls.
   parameter SIM_BYPASS_INIT_CAL     = "OFF",
                                       // # = "OFF" -  Complete memory init &
                                       //              calibration sequence
                                       // # = "SKIP" - Skip memory init &
                                       //              calibration sequence
                                       // # = "FAST" - Skip memory init & use
                                       //              abbreviated calib sequence
   parameter nCS_PER_RANK            = 1,
                                       // # of unique CS outputs per Rank for
                                       // phy.
   parameter DQS_CNT_WIDTH           = 3,
                                       // # = ceil(log2(DQS_WIDTH)).
   parameter RANK_WIDTH              = 1,
                                       // # = ceil(log2(RANKS)).
   parameter BANK_WIDTH              = 3,
                                       // # of memory Bank Address bits.
   parameter CK_WIDTH                = 1,
                                       // # of CK/CK# outputs to memory.
   parameter CKE_WIDTH               = 1,
                                       // # of CKE outputs to memory.
   parameter COL_WIDTH               = 10,
                                       // # of memory Column Address bits.
   parameter CS_WIDTH                = 1,
                                       // # of unique CS outputs to memory.
   parameter DM_WIDTH                = 8,
                                       // # of Data Mask bits.
   parameter DQ_WIDTH                = 64,
                                       // # of Data (DQ) bits.
   parameter DQS_WIDTH               = 8,
                                       // # of DQS/DQS# bits.
   parameter ROW_WIDTH               = 13,
                                       // # of memory Row Address bits.
   parameter BURST_MODE              = "8",
                                       // Burst Length (Mode Register 0).
                                       // # = "8", "4", "OTF".
   parameter BM_CNT_WIDTH            = 2,
                                       // # = ceil(log2(nBANK_MACHS)).
   parameter ADDR_CMD_MODE           = "1T" ,
                                       // # = "2T", "1T".
   parameter ORDERING                = "STRICT",
                                       // # = "NORM", "STRICT".
   parameter WRLVL                   = "ON",
                                       // # = "ON" - DDR3 SDRAM
                                       //   = "OFF" - DDR2 SDRAM.
   parameter PHASE_DETECT            = "ON",
                                       // # = "ON", "OFF".
   parameter RTT_NOM                 = "60",
                                       // RTT_NOM (ODT) (Mode Register 1).
                                       // # = "DISABLED" - RTT_NOM disabled,
                                       //   = "120" - RZQ/2,
                                       //   = "60"  - RZQ/4,
                                       //   = "40"  - RZQ/6.
   parameter RTT_WR                  = "OFF",
                                       // RTT_WR (ODT) (Mode Register 2).
                                       // # = "OFF" - Dynamic ODT off,
                                       //   = "120" - RZQ/2,
                                       //   = "60"  - RZQ/4,
   parameter OUTPUT_DRV              = "HIGH",
                                       // Output Driver Impedance Control (Mode Register 1).
                                       // # = "HIGH" - RZQ/7,
                                       //   = "LOW" - RZQ/6.
   parameter REG_CTRL                = "OFF",
                                       // # = "ON" - RDIMMs,
                                       //   = "OFF" - Components, SODIMMs, UDIMMs.
   parameter nDQS_COL0               = 3,
                                       // Number of DQS groups in I/O column #1.
   parameter nDQS_COL1               = 5,
                                       // Number of DQS groups in I/O column #2.
   parameter nDQS_COL2               = 0,
                                       // Number of DQS groups in I/O column #3.
   parameter nDQS_COL3               = 0,
                                       // Number of DQS groups in I/O column #4.
   parameter DQS_LOC_COL0            = 24'h020100,
                                       // DQS groups in column #1.
   parameter DQS_LOC_COL1            = 40'h0706050403,
                                       // DQS groups in column #2.
   parameter DQS_LOC_COL2            = 0,
                                       // DQS groups in column #3.
   parameter DQS_LOC_COL3            = 0,
                                       // DQS groups in column #4.
   parameter tPRDI                   = 1_000_000,
                                       // memory tPRDI paramter.
   parameter tREFI                   = 7800000,
                                       // memory tREFI paramter.
   parameter tZQI                    = 128_000_000,
                                       // memory tZQI paramter.
   parameter ADDR_WIDTH              = 27,
                                       // # = RANK_WIDTH + BANK_WIDTH
                                       //     + ROW_WIDTH + COL_WIDTH;
   parameter ECC                     = "OFF",
   parameter ECC_TEST                = "OFF",
   parameter TCQ                     = 100,
   parameter RST_ACT_LOW             = 0, // ML605 reset is active high
   parameter INPUT_CLK_TYPE          = "DIFFERENTIAL")
  (input clk_ref_p, clk_ref_n,
   inout  [DQ_WIDTH-1:0]                ddr3_dq,
   output [ROW_WIDTH-1:0]               ddr3_addr,
   output [BANK_WIDTH-1:0]              ddr3_ba,
   output                               ddr3_ras_n,
   output                               ddr3_cas_n,
   output                               ddr3_we_n,
   output                               ddr3_reset_n,
   output [(CS_WIDTH*nCS_PER_RANK)-1:0] ddr3_cs_n,
   output [(CS_WIDTH*nCS_PER_RANK)-1:0] ddr3_odt,
   output [CKE_WIDTH-1:0]               ddr3_cke,
   output [DM_WIDTH-1:0]                 ddr3_dm,
   inout  [DQS_WIDTH-1:0]               ddr3_dqs_p,
   inout  [DQS_WIDTH-1:0]               ddr3_dqs_n,
   output [CK_WIDTH-1:0]                ddr3_ck_p,
   output [CK_WIDTH-1:0]                ddr3_ck_n,
 //  inout                                sda,      // ML605
 //  output                               scl,      // ML605 
  output[7:0] GPIO_LED,
   input                                sys_rst   // System reset
  , input PCIE_PERST_B_LS //The host's master bus reset
  , input PCIE_REFCLK_N, PCIE_REFCLK_P
  , input[3:0] PCIE_RX_N, PCIE_RX_P
  , output[3:0] PCIE_TX_N, PCIE_TX_P
   );
`include "function.v"

  localparam SYSCLK_PERIOD          = tCK * nCK_PER_CLK;

  localparam DATA_WIDTH          = 64;
  localparam PAYLOAD_WIDTH       = (ECC_TEST == "OFF") ? DATA_WIDTH : DQ_WIDTH;
  localparam BURST_LENGTH        = STR_TO_INT(BURST_MODE);
  localparam APP_DATA_WIDTH      = PAYLOAD_WIDTH * 4;
  localparam APP_MASK_WIDTH      = APP_DATA_WIDTH / 8;

  wire error, phy_init_done, pll_lock, heartbeat;
  //wire clk_ref, sys_clk;
  wire                                mmcm_clk;
  wire                                iodelay_ctrl_rdy;
//  (* KEEP = "TRUE" *) wire            sda_i;
//  (* KEEP = "TRUE" *) wire            scl_i;
  wire                                rst;
  wire                                clk;
  wire                                clk_mem;
  wire                                clk_rd_base;
  wire                                pd_PSDONE;
  wire                                pd_PSEN;
  wire                                pd_PSINCDEC;
  wire  [(BM_CNT_WIDTH)-1:0]          bank_mach_next;
  wire                                ddr3_parity;
  wire                                app_hi_pri;
  wire [APP_MASK_WIDTH-1:0]           app_wdf_mask;
  wire [3:0]                          app_ecc_multiple_err_i;
  wire [ADDR_WIDTH-1:0]               app_addr;
  wire [2:0]                          app_cmd;
  wire [APP_DATA_WIDTH-1:0]           app_rd_data;
  wire [APP_DATA_WIDTH-1:0]           app_wdf_data;
  wire app_rd_data_valid, app_en, app_sz, app_rdy
     , app_wdf_rdy, app_wdf_wren, app_wdf_end;

  wire [5*DQS_WIDTH-1:0]              dbg_cpt_first_edge_cnt;
  wire [5*DQS_WIDTH-1:0]              dbg_cpt_second_edge_cnt;
  wire [5*DQS_WIDTH-1:0]              dbg_cpt_tap_cnt;
  wire                                dbg_dec_cpt;
  wire                                dbg_dec_rd_dqs;
  wire                                dbg_dec_rd_fps;
  wire [5*DQS_WIDTH-1:0]              dbg_dq_tap_cnt;
  wire [5*DQS_WIDTH-1:0]              dbg_dqs_tap_cnt;
  wire                                dbg_inc_cpt;
  wire [DQS_CNT_WIDTH-1:0]            dbg_inc_dec_sel;
  wire                                dbg_inc_rd_dqs;
  wire                                dbg_inc_rd_fps;
  wire                                dbg_ocb_mon_off;
  wire                                dbg_pd_off;
  wire                                dbg_pd_maintain_off;
  wire                                dbg_pd_maintain_0_only;
  wire [4:0]                          dbg_rd_active_dly;
  wire [3*DQS_WIDTH-1:0]              dbg_rd_bitslip_cnt;
  wire [2*DQS_WIDTH-1:0]              dbg_rd_clkdly_cnt;
  wire [4*DQ_WIDTH-1:0]               dbg_rddata;
  wire [1:0]                          dbg_rdlvl_done;
  wire [1:0]                          dbg_rdlvl_err;
  wire [1:0]                          dbg_rdlvl_start;
  wire [DQS_WIDTH-1:0]                dbg_wl_dqs_inverted;
  wire [5*DQS_WIDTH-1:0]              dbg_wl_odelay_dq_tap_cnt;
  wire [5*DQS_WIDTH-1:0]              dbg_wl_odelay_dqs_tap_cnt;
  wire [2*DQS_WIDTH-1:0]              dbg_wr_calib_clk_delay;
  wire [5*DQS_WIDTH-1:0]              dbg_wr_dq_tap_set;
  wire [5*DQS_WIDTH-1:0]              dbg_wr_dqs_tap_set;
  wire                                dbg_wr_tap_set_en;
  wire                                dbg_idel_up_all;
  wire                                dbg_idel_down_all;
  wire                                dbg_idel_up_cpt;
  wire                                dbg_idel_down_cpt;
  wire                                dbg_idel_up_rsync;
  wire                                dbg_idel_down_rsync;
  wire                                dbg_sel_all_idel_cpt;
  wire                                dbg_sel_all_idel_rsync;
  wire                                dbg_pd_inc_cpt;
  wire                                dbg_pd_dec_cpt;
  wire                                dbg_pd_inc_dqs;
  wire                                dbg_pd_dec_dqs;
  wire                                dbg_pd_disab_hyst;
  wire                                dbg_pd_disab_hyst_0;
  wire                                dbg_wrlvl_done;
  wire                                dbg_wrlvl_err;
  wire                                dbg_wrlvl_start;
  wire [4:0]                          dbg_tap_cnt_during_wrlvl;
  wire [19:0]                         dbg_rsync_tap_cnt;
  wire [255:0]                        dbg_phy_pd;
  wire [255:0]                        dbg_phy_read;
  wire [255:0]                        dbg_phy_rdlvl;
  wire [255:0]                        dbg_phy_top;
  wire [3:0]                          dbg_pd_msb_sel;
  wire [DQS_WIDTH-1:0]                dbg_rd_data_edge_detect;
  wire [DQS_CNT_WIDTH-1:0]            dbg_sel_idel_cpt;
  wire [DQS_CNT_WIDTH-1:0]            dbg_sel_idel_rsync;
  wire [DQS_CNT_WIDTH-1:0]            dbg_pd_byte_sel;

  wire                                ddr3_cs0_clk;
  wire [35:0]                         ddr3_cs0_control;
  wire [383:0]                        ddr3_cs0_data;
  wire [7:0]                          ddr3_cs0_trig;
  wire [255:0]                        ddr3_cs1_async_in;
  wire [35:0]                         ddr3_cs1_control;
  wire [255:0]                        ddr3_cs2_async_in;
  wire [35:0]                         ddr3_cs2_control;
  wire [255:0]                        ddr3_cs3_async_in;
  wire [35:0]                         ddr3_cs3_control;
  wire                                ddr3_cs4_clk;
  wire [35:0]                         ddr3_cs4_control;
  wire [31:0]                         ddr3_cs4_sync_out;

  //***************************************************************************
  assign GPIO_LED[7:4] = {error, phy_init_done, app_rdy, heartbeat};
  assign app_hi_pri = 1'b0;
  assign app_wdf_mask = {APP_MASK_WIDTH{1'b0}};

  //assign clk_ref = 1'b0;
  //assign sys_clk = 1'b0; 
  //ML605 200MHz clock sourced from BUFG within "idelay_ctrl" module.
  wire clk_200;
  //wire clk_85;

  iodelay_ctrl #
    (
     .TCQ            (TCQ),
     .IODELAY_GRP    (IODELAY_GRP),
     .INPUT_CLK_TYPE (INPUT_CLK_TYPE),
     .RST_ACT_LOW    (RST_ACT_LOW)
     )
    u_iodelay_ctrl
      (
       .clk_ref_p        (clk_ref_p),  // ML605 200MHz EPSON oscillator
       .clk_ref_n        (clk_ref_n),
       .clk_ref          (1'b0),
       .sys_rst          (sys_rst),
       .clk_200          (clk_200),    // ML605 200MHz clock from BUFG to MMCM CLKIN1
       .iodelay_ctrl_rdy (iodelay_ctrl_rdy)
       );
/* ML605 comment out "clk_ibuf" module. MIG default requires 2 inputs clocks.
  clk_ibuf #
    (
     .INPUT_CLK_TYPE (INPUT_CLK_TYPE)
     )
    u_clk_ibuf
      (
       .sys_clk_p         (sys_clk_p),
       .sys_clk_n         (sys_clk_n),
       .sys_clk           (sys_clk),
       .mmcm_clk          (mmcm_clk)
       );
*/
 
  infrastructure #
    (
     .TCQ                (TCQ),
     .CLK_PERIOD         (SYSCLK_PERIOD),
     .nCK_PER_CLK        (nCK_PER_CLK),
     .MMCM_ADV_BANDWIDTH (MMCM_ADV_BANDWIDTH),
     .CLKFBOUT_MULT_F    (CLKFBOUT_MULT_F),
     .DIVCLK_DIVIDE      (DIVCLK_DIVIDE),
     .CLKOUT_DIVIDE      (CLKOUT_DIVIDE),
     .RST_ACT_LOW        (RST_ACT_LOW)
     )
    u_infrastructure
      (
       .clk_mem          (clk_mem),
       .clk              (clk),
       .clk_rd_base      (clk_rd_base),
       //.clk_85(clk_85),
       .pll_lock         (pll_lock), // ML605 GPIO LED output port
       .rstdiv0          (rst),
       .mmcm_clk(clk_200),//ML605 single input clock 200MHz from "iodelay_ctrl"
       .sys_rst          (sys_rst),
       .iodelay_ctrl_rdy (iodelay_ctrl_rdy),
       .PSDONE           (pd_PSDONE),
       .PSEN             (pd_PSEN),
       .PSINCDEC         (pd_PSINCDEC)
       );


  memc_ui_top #
  (
   .ADDR_CMD_MODE        (ADDR_CMD_MODE),
   .BANK_WIDTH           (BANK_WIDTH),
   .CK_WIDTH             (CK_WIDTH),
   .CKE_WIDTH            (CKE_WIDTH),
   .nCK_PER_CLK          (nCK_PER_CLK),
   .COL_WIDTH            (COL_WIDTH),
   .CS_WIDTH             (CS_WIDTH),
   .DM_WIDTH             (DM_WIDTH),
   .nCS_PER_RANK         (nCS_PER_RANK),
   .DEBUG_PORT           (DEBUG_PORT),
   .IODELAY_GRP          (IODELAY_GRP),
   .DQ_WIDTH             (DQ_WIDTH),
   .DQS_WIDTH            (DQS_WIDTH),
   .DQS_CNT_WIDTH        (DQS_CNT_WIDTH),
   .ORDERING             (ORDERING),
   .OUTPUT_DRV           (OUTPUT_DRV),
   .PHASE_DETECT         (PHASE_DETECT),
   .RANK_WIDTH           (RANK_WIDTH),
   .REFCLK_FREQ          (REFCLK_FREQ),
   .REG_CTRL             (REG_CTRL),
   .ROW_WIDTH            (ROW_WIDTH),
   .RTT_NOM              (RTT_NOM),
   .RTT_WR               (RTT_WR),
   .SIM_BYPASS_INIT_CAL  (SIM_BYPASS_INIT_CAL),
   .WRLVL                (WRLVL),
   .nDQS_COL0            (nDQS_COL0),
   .nDQS_COL1            (nDQS_COL1),
   .nDQS_COL2            (nDQS_COL2),
   .nDQS_COL3            (nDQS_COL3),
   .DQS_LOC_COL0         (DQS_LOC_COL0),
   .DQS_LOC_COL1         (DQS_LOC_COL1),
   .DQS_LOC_COL2         (DQS_LOC_COL2),
   .DQS_LOC_COL3         (DQS_LOC_COL3),
   .tPRDI                (tPRDI),
   .tREFI                (tREFI),
   .tZQI                 (tZQI),
   .BURST_MODE           (BURST_MODE),
   .BM_CNT_WIDTH         (BM_CNT_WIDTH),
   .tCK                  (tCK),
   .ADDR_WIDTH           (ADDR_WIDTH),
   .TCQ                  (TCQ),
   .ECC                  (ECC),
   .ECC_TEST             (ECC_TEST),
   .PAYLOAD_WIDTH        (PAYLOAD_WIDTH),
   .APP_DATA_WIDTH       (APP_DATA_WIDTH),
   .APP_MASK_WIDTH       (APP_MASK_WIDTH)
   )
  u_memc_ui_top
  (
   .clk                              (clk),
   .clk_mem                          (clk_mem),
   .clk_rd_base                      (clk_rd_base),
   .rst                              (rst),
   .ddr_addr                         (ddr3_addr),
   .ddr_ba                           (ddr3_ba),
   .ddr_cas_n                        (ddr3_cas_n),
   .ddr_ck_n                         (ddr3_ck_n),
   .ddr_ck                           (ddr3_ck_p),
   .ddr_cke                          (ddr3_cke),
   .ddr_cs_n                         (ddr3_cs_n),
   .ddr_dm                           (ddr3_dm),
   .ddr_odt                          (ddr3_odt),
   .ddr_ras_n                        (ddr3_ras_n),
   .ddr_reset_n                      (ddr3_reset_n),
   .ddr_parity                       (ddr3_parity),
   .ddr_we_n                         (ddr3_we_n),
   .ddr_dq                           (ddr3_dq),
   .ddr_dqs_n                        (ddr3_dqs_n),
   .ddr_dqs                          (ddr3_dqs_p),
   .pd_PSEN                          (pd_PSEN),
   .pd_PSINCDEC                      (pd_PSINCDEC),
   .pd_PSDONE                        (pd_PSDONE),
   .phy_init_done                    (phy_init_done),
   .bank_mach_next                   (bank_mach_next),
   .app_ecc_multiple_err             (app_ecc_multiple_err_i),
   .app_rd_data                      (app_rd_data),
   .app_rd_data_end                  (app_rd_data_end),
   .app_rd_data_valid                (app_rd_data_valid),
   .app_rdy                          (app_rdy),
   .app_wdf_rdy                      (app_wdf_rdy),
   .app_addr                         (app_addr),
   .app_cmd                          (app_cmd),
   .app_en                           (app_en),
   .app_hi_pri                       (app_hi_pri),
   .app_sz                           (1'b1),
   .app_wdf_data                     (app_wdf_data),
   .app_wdf_end                      (app_wdf_end),
   .app_wdf_mask                     (app_wdf_mask),
   .app_wdf_wren                     (app_wdf_wren),
   .app_correct_en                   (1'b1),
   .dbg_wr_dqs_tap_set               (dbg_wr_dqs_tap_set),
   .dbg_wr_dq_tap_set                (dbg_wr_dq_tap_set),
   .dbg_wr_tap_set_en                (dbg_wr_tap_set_en),
   .dbg_wrlvl_start                  (dbg_wrlvl_start),
   .dbg_wrlvl_done                   (dbg_wrlvl_done),
   .dbg_wrlvl_err                    (dbg_wrlvl_err),
   .dbg_wl_dqs_inverted              (dbg_wl_dqs_inverted),
   .dbg_wr_calib_clk_delay           (dbg_wr_calib_clk_delay),
   .dbg_wl_odelay_dqs_tap_cnt        (dbg_wl_odelay_dqs_tap_cnt),
   .dbg_wl_odelay_dq_tap_cnt         (dbg_wl_odelay_dq_tap_cnt),
   .dbg_rdlvl_start                  (dbg_rdlvl_start),
   .dbg_rdlvl_done                   (dbg_rdlvl_done),
   .dbg_rdlvl_err                    (dbg_rdlvl_err),
   .dbg_cpt_tap_cnt                  (dbg_cpt_tap_cnt),
   .dbg_cpt_first_edge_cnt           (dbg_cpt_first_edge_cnt),
   .dbg_cpt_second_edge_cnt          (dbg_cpt_second_edge_cnt),
   .dbg_rd_bitslip_cnt               (dbg_rd_bitslip_cnt),
   .dbg_rd_clkdly_cnt                (dbg_rd_clkdly_cnt),
   .dbg_rd_active_dly                (dbg_rd_active_dly),
   .dbg_pd_off                       (dbg_pd_off),
   .dbg_pd_maintain_off              (dbg_pd_maintain_off),
   .dbg_pd_maintain_0_only           (dbg_pd_maintain_0_only),
   .dbg_inc_cpt                      (dbg_inc_cpt),
   .dbg_dec_cpt                      (dbg_dec_cpt),
   .dbg_inc_rd_dqs                   (dbg_inc_rd_dqs),
   .dbg_dec_rd_dqs                   (dbg_dec_rd_dqs),
   .dbg_inc_dec_sel                  (dbg_inc_dec_sel),
   .dbg_inc_rd_fps                   (dbg_inc_rd_fps),
   .dbg_dec_rd_fps                   (dbg_dec_rd_fps),
   .dbg_dqs_tap_cnt                  (dbg_dqs_tap_cnt),
   .dbg_dq_tap_cnt                   (dbg_dq_tap_cnt),
   .dbg_rddata                       (dbg_rddata)
   );

  // If debug port is not enabled, then make certain control input
  // to Debug Port are disabled
  generate
    if (DEBUG_PORT == "OFF") begin: gen_dbg_tie_off
      assign dbg_wr_dqs_tap_set     = 'b0;
      assign dbg_wr_dq_tap_set      = 'b0;
      assign dbg_wr_tap_set_en      = 1'b0;
      assign dbg_pd_off             = 1'b0;
      assign dbg_pd_maintain_off    = 1'b0;
      assign dbg_pd_maintain_0_only = 1'b0;
      assign dbg_ocb_mon_off        = 1'b0;
      assign dbg_inc_cpt            = 1'b0;
      assign dbg_dec_cpt            = 1'b0;
      assign dbg_inc_rd_dqs         = 1'b0;
      assign dbg_dec_rd_dqs         = 1'b0;
      assign dbg_inc_dec_sel        = 'b0;
      assign dbg_inc_rd_fps         = 1'b0;
      assign dbg_pd_msb_sel         = 'b0 ;
      assign dbg_sel_idel_cpt       = 'b0 ;
      assign dbg_sel_idel_rsync     = 'b0 ;
      assign dbg_pd_byte_sel        = 'b0 ;
      assign dbg_dec_rd_fps         = 1'b0;
    end
  endgenerate
  generate
    if (DEBUG_PORT == "ON") begin: gen_dbg_enable

      // Connect these to VIO if changing output (write) 
      // IODELAY taps desired 
      assign dbg_wr_dqs_tap_set     = 'b0;
      assign dbg_wr_dq_tap_set      = 'b0;
      assign dbg_wr_tap_set_en      = 1'b0;

      // Connect these to VIO if changing read base clock
      // phase required
      assign dbg_inc_rd_fps         = 1'b0;
      assign dbg_dec_rd_fps         = 1'b0;
      
      //*******************************************************
      // CS0 - ILA for monitoring PHY status, testbench error,
      //       and synchronized read data
      //*******************************************************

      // Assignments for ILA monitoring general PHY
      // status and synchronized read data
      assign ddr3_cs0_clk             = clk;
      assign ddr3_cs0_trig[1:0]       = dbg_rdlvl_done;
      assign ddr3_cs0_trig[3:2]       = dbg_rdlvl_err;
      assign ddr3_cs0_trig[4]         = phy_init_done;
      assign ddr3_cs0_trig[5]         = error;  // ML605 ERROR from TrafficGen
      assign ddr3_cs0_trig[7:6]       = 2'b0;   // ML605

      // Support for only up to 72-bits of data
      if (DQ_WIDTH <= 72) begin: gen_dq_le_72
        assign ddr3_cs0_data[4*DQ_WIDTH-1:0] = dbg_rddata;
      end else begin: gen_dq_gt_72
        assign ddr3_cs0_data[287:0] = dbg_rddata[287:0];
      end

      assign ddr3_cs0_data[289:288]   = dbg_rdlvl_done;
      assign ddr3_cs0_data[291:290]   = dbg_rdlvl_err;
      assign ddr3_cs0_data[292]       = phy_init_done;
      assign ddr3_cs0_data[293]       = error; // ML605 connect to ERROR from TrafficGen
      assign ddr3_cs0_data[294]       = app_rd_data_valid; // ML605 read data valid
      assign ddr3_cs0_data[295]       = pll_lock; // ML605 PLL_LOCK status indicator
      assign ddr3_cs0_data[383:296]   = 'b0;

      //*******************************************************
      // CS1 - Input VIO for monitoring PHY status and
      //       write leveling/calibration delays
      //*******************************************************

      // Support for only up to 18 DQS groups
      if (DQS_WIDTH <= 18) begin: gen_dqs_le_18_cs1
        assign ddr3_cs1_async_in[5*DQS_WIDTH-1:0]     = dbg_wl_odelay_dq_tap_cnt;
        assign ddr3_cs1_async_in[5*DQS_WIDTH+89:90]   = dbg_wl_odelay_dqs_tap_cnt;
        assign ddr3_cs1_async_in[DQS_WIDTH+179:180]   = dbg_wl_dqs_inverted;
        assign ddr3_cs1_async_in[2*DQS_WIDTH+197:198] = dbg_wr_calib_clk_delay;
      end else begin: gen_dqs_gt_18_cs1
        assign ddr3_cs1_async_in[89:0]    = dbg_wl_odelay_dq_tap_cnt[89:0];
        assign ddr3_cs1_async_in[179:90]  = dbg_wl_odelay_dqs_tap_cnt[89:0];
        assign ddr3_cs1_async_in[197:180] = dbg_wl_dqs_inverted[17:0];
        assign ddr3_cs1_async_in[233:198] = dbg_wr_calib_clk_delay[35:0];
      end

      assign ddr3_cs1_async_in[235:234] = dbg_rdlvl_done[1:0];
      assign ddr3_cs1_async_in[237:236] = dbg_rdlvl_err[1:0];
      assign ddr3_cs1_async_in[238]     = phy_init_done;
      assign ddr3_cs1_async_in[239]     = 1'b0; // Pre-MIG 3.4: Used for rst_pll_ck_fb
      assign ddr3_cs1_async_in[240]     = error; // ML605 ERROR from TrafficGen
      assign ddr3_cs1_async_in[255:241] = 'b0;

      //*******************************************************
      // CS2 - Input VIO for monitoring Read Calibration
      //       results.
      //*******************************************************

      // Support for only up to 18 DQS groups
      if (DQS_WIDTH <= 18) begin: gen_dqs_le_18_cs2
        assign ddr3_cs2_async_in[5*DQS_WIDTH-1:0]     = dbg_cpt_tap_cnt;
        // Reserved for future monitoring of DQ tap counts from read leveling
        assign ddr3_cs2_async_in[5*DQS_WIDTH+89:90]   = 'b0;
        assign ddr3_cs2_async_in[3*DQS_WIDTH+179:180] = dbg_rd_bitslip_cnt;
      end else begin: gen_dqs_gt_18_cs2
        assign ddr3_cs2_async_in[89:0]    = dbg_cpt_tap_cnt[89:0];
        // Reserved for future monitoring of DQ tap counts from read leveling
        assign ddr3_cs2_async_in[179:90]  = 'b0;
        assign ddr3_cs2_async_in[233:180] = dbg_rd_bitslip_cnt[53:0];
      end

      assign ddr3_cs2_async_in[238:234] = dbg_rd_active_dly;
      assign ddr3_cs2_async_in[255:239] = 'b0;

      //*******************************************************
      // CS3 - Input VIO for monitoring more Read Calibration
      //       results.
      //*******************************************************

      // Support for only up to 18 DQS groups
      if (DQS_WIDTH <= 18) begin: gen_dqs_le_18_cs3
        assign ddr3_cs3_async_in[5*DQS_WIDTH-1:0]     = dbg_cpt_first_edge_cnt;
        assign ddr3_cs3_async_in[5*DQS_WIDTH+89:90]   = dbg_cpt_second_edge_cnt;
        assign ddr3_cs3_async_in[2*DQS_WIDTH+179:180] = dbg_rd_clkdly_cnt;
      end else begin: gen_dqs_gt_18_cs3
        assign ddr3_cs3_async_in[89:0]    = dbg_cpt_first_edge_cnt[89:0];
        assign ddr3_cs3_async_in[179:90]  = dbg_cpt_second_edge_cnt[89:0];
        assign ddr3_cs3_async_in[215:180] = dbg_rd_clkdly_cnt[35:0];
      end

      assign ddr3_cs3_async_in[255:216] = 'b0;

      //*******************************************************
      // CS4 - Output VIO for disabling OCB monitor, Read Phase
      //       Detector, and dynamically changing various
      //       IODELAY values used for adjust read data capture
      //       timing
      //*******************************************************

      assign ddr3_cs4_clk                = clk;
      assign dbg_pd_off             = ddr3_cs4_sync_out[0];
      assign dbg_pd_maintain_off    = ddr3_cs4_sync_out[1];
      assign dbg_pd_maintain_0_only = ddr3_cs4_sync_out[2];
      assign dbg_ocb_mon_off        = ddr3_cs4_sync_out[3];
      assign dbg_inc_cpt            = ddr3_cs4_sync_out[4];
      assign dbg_dec_cpt            = ddr3_cs4_sync_out[5];
      assign dbg_inc_rd_dqs         = ddr3_cs4_sync_out[6];
      assign dbg_dec_rd_dqs         = ddr3_cs4_sync_out[7];
      assign dbg_inc_dec_sel        = ddr3_cs4_sync_out[DQS_CNT_WIDTH+7:8];

// ML605 add assignments to control traffic generator function from VIO console:
      assign manual_clear_error     = ddr3_cs4_sync_out[24];     // ML605 debug
      assign modify_enable_sel      = ddr3_cs4_sync_out[25];     // ML605 debug      
      assign addr_mode_manual_sel   = ddr3_cs4_sync_out[28:26];  // ML605 debug
      assign data_mode_manual_sel   = ddr3_cs4_sync_out[31:29];  // ML605 debug

      icon5 u_icon
        (
         .CONTROL0 (ddr3_cs0_control),
         .CONTROL1 (ddr3_cs1_control),
         .CONTROL2 (ddr3_cs2_control),
         .CONTROL3 (ddr3_cs3_control),
         .CONTROL4 (ddr3_cs4_control)
         );

      ila384_8 u_cs0
        (
         .CLK     (ddr3_cs0_clk),
         .DATA    (ddr3_cs0_data),
         .TRIG0   (ddr3_cs0_trig),
         .CONTROL (ddr3_cs0_control)
         );

      vio_async_in256 u_cs1
        (
         .ASYNC_IN (ddr3_cs1_async_in),
         .CONTROL  (ddr3_cs1_control)
         );

      vio_async_in256 u_cs2
        (
         .ASYNC_IN (ddr3_cs2_async_in),
         .CONTROL  (ddr3_cs2_control)
         );

      vio_async_in256 u_cs3
        (
         .ASYNC_IN (ddr3_cs3_async_in),
         .CONTROL  (ddr3_cs3_control)
         );

      vio_sync_out32 u_cs4
        (
         .SYNC_OUT (ddr3_cs4_sync_out),
         .CLK      (ddr3_cs4_clk),
         .CONTROL  (ddr3_cs4_control)
         );
    end
  endgenerate

  wire app_done;

  // Xillybus signals
  localparam XB_SIZE = 32;
  wire bus_clk, quiesce
   , xb_rd_rden         //xb_rd_fifo -> xillybus
   , xb_rd_empty        //xb_rd_fifo -> xillybus
   , xb_rd_open         //xillybus -> xb_rd_fifo
   , fpga_msg_valid     //app -> xb_rd_fifo
   , fpga_msg_full      //xb_rd_fifo -> app
   , pc_msg_empty, pc_msg_pending //xb_wr_fifo -> app; NOT of empty
   , pc_msg_ack         // app -> xb_wr_fifo
   , xb_wr_wren         // xillybus -> xb_wr_fifo
   , xb_wr_full         // xb_wr_fifo -> xillybus
   , xb_wr_open         // xillybus -> xb_wr_fifo
   , xb_loop_rden       // xillybus -> xb_loop_fifo
   , xb_loop_empty      // xb_loop_fifo -> xillybus
   , xb_loop_full;      // xb_loop_fifo -> xillybus
  wire[XB_SIZE-1:0] xb_rd_data //xb_rd_fifo -> xillybus
   , xb_loop_data       // xb_loopback_fifo -> xillybus
   , xb_wr_data         // xillybus -> xb_wr_fifo
   , pc_msg
   , fpga_msg;          //app -> xb_rd_fifo

  localparam FP_SIZE = 19;
  generate
    if(SIMULATION == 1) begin: simulate_xb
      integer binf, rc;
      reg[XB_SIZE-1:0] pc_msg_r;
      reg bus_clk_r, pc_msg_empty_r;
      initial begin
        binf = $fopen("M2T_coeff.bin", "rb");
        bus_clk_r <= `FALSE;
        pc_msg_empty_r <= `TRUE;
        pc_msg_r <= 0;
        rc = $fread(pc_msg_r, binf);
        $display("time %d ps fread %d, %X", $time, rc, pc_msg_r);
#350000 pc_msg_empty_r <= `FALSE; // Coefficient data from PC starts
        while(!$feof(binf)) begin
          @(posedge clk)
            if(pc_msg_ack) begin
              rc = $fread(pc_msg_r, binf);
              $display("time %d ps fread %d, %X", $time, rc, pc_msg_r);
            end
        end
        $fclose(binf);
      end

      //assign pc_msg_ack = `TRUE;
      always #4000 bus_clk_r = ~bus_clk_r;
      assign bus_clk = bus_clk_r;
      assign pc_msg = pc_msg_r;
      assign pc_msg_empty = pc_msg_empty_r;
    end else begin: instantiate_xb
        
      xillybus xb(.GPIO_LED(GPIO_LED[3:0]) //For debugging
        , .PCIE_PERST_B_LS(PCIE_PERST_B_LS) // Signals to top level:
        , .PCIE_REFCLK_N(PCIE_REFCLK_N), .PCIE_REFCLK_P(PCIE_REFCLK_P)
        , .PCIE_RX_N(PCIE_RX_N), .PCIE_RX_P(PCIE_RX_P)
        , .PCIE_TX_N(PCIE_TX_N), .PCIE_TX_P(PCIE_TX_P)
        , .bus_clk(bus_clk), .quiesce(quiesce)

        , .user_r_rd_rden(xb_rd_rden), .user_r_rd_empty(xb_rd_empty)
        , .user_r_rd_data(xb_rd_data), .user_r_rd_open(xb_rd_open)
        , .user_r_rd_eof((pc_msg_pending && (pc_msg == ~0) && xb_rd_empty)
                         || app_done)
                         
        , .user_w_wr_wren(xb_wr_wren), .user_w_wr_full(xb_wr_full)
        , .user_w_wr_data(xb_wr_data), .user_w_wr_open(xb_wr_open)
        
        , .user_r_rd_loop_rden(xb_loop_rden)
        , .user_r_rd_loop_empty(xb_loop_empty)
        , .user_r_rd_loop_data(xb_loop_data)
        , .user_r_rd_loop_open(xb_loop_open)
        , .user_r_rd_loop_eof(!xb_wr_open && xb_loop_empty)
        );

      xb_wr_fifo(.wr_clk(bus_clk), .rd_clk(clk), .rst(reset)
        , .din(xb_wr_data), .wr_en(xb_wr_wren)
        , .rd_en(pc_msg_ack), .dout(pc_msg)
        , .full(xb_wr_full), .empty(pc_msg_empty));

      // Data from dram lock clock domain to PCIe domain
      xb_rd_fifo(.wr_clk(clk), .rd_clk(bus_clk), .rst(reset)
        , .din(fpga_msg), .wr_en(fpga_msg_valid && xb_rd_open)
        , .rd_en(xb_rd_rden), .dout(xb_rd_data)
        , .full(fpga_msg_full), .empty(xb_rd_empty));

      xb_loopback_fifo(.clk(bus_clk)//, .rst(reset)
        , .din(pc_msg), .wr_en(pc_msg_ack)
        , .rd_en(xb_loop_rden), .dout(xb_loop_data)
        , .full(xb_loop_full), .empty(xb_loop_empty));
    end
  endgenerate

  assign app_cmd[2:1] = 2'b00;
  assign pc_msg_pending = !pc_msg_empty;
//`ifdef ADD_APP_LOGIC
  application#(.ADDR_WIDTH(ADDR_WIDTH), .APP_DATA_WIDTH(APP_DATA_WIDTH)
    , .FP_SIZE(FP_SIZE), .XB_SIZE(XB_SIZE))
    app(//dram signals
      .dram_clk(clk), .reset(rst)
      , .error(error), .heartbeat(heartbeat)
      , .app_rdy(app_rdy), .app_en(app_en), .dram_read(app_cmd[0]), .app_addr(app_addr)
      , .app_wdf_wren(app_wdf_wren), .app_wdf_end(app_wdf_end)
      , .app_wdf_rdy(app_wdf_rdy), .app_wdf_data(app_wdf_data)
      , .app_rd_data_valid(app_rd_data_valid), .app_rd_data(app_rd_data)
      //xillybus signals
      , .bus_clk(bus_clk)
      , .pc_msg_pending(pc_msg_pending), .pc_msg_ack(pc_msg_ack)
      , .pc_msg(pc_msg)
      , .fpga_msg_valid(fpga_msg_valid), .fpga_msg_full(rd_fifo_full)
      , .fpga_msg(fpga_msg)
      , .app_done(app_done)
      );
//`endif
endmodule
