`timescale 1ps/1ps //1ps/100fs

module simmain;
  parameter REFCLK_FREQ           = 200;
                                    // # = 200 for all design frequencies of
                                    //         -1 speed grade devices
                                    //   = 200 when design frequency < 480 MHz
                                    //         for -2 and -3 speed grade devices.
                                    //   = 300 when design frequency >= 480 MHz
                                    //         for -2 and -3 speed grade devices.
  parameter SIM_BYPASS_INIT_CAL   = "SKIP";//"FAST";
                                    // # = "OFF" -  Complete memory init &
                                    //              calibration sequence
                                    // # = "SKIP" - Skip memory init &
                                    //              calibration sequence
                                    // # = "FAST" - Skip memory init & use
                                    //              abbreviated calib sequence
  parameter RST_ACT_LOW           = 0;//For ML605
                                    // =1 for active low reset,
                                    // =0 for active high.
  parameter IODELAY_GRP           = "IODELAY_MIG";
                                    //to phy_top
  parameter nCK_PER_CLK           = 2;
                                    // # of memory CKs per fabric clock.
                                    // # = 2, 1.
  parameter nCS_PER_RANK          = 1;
                                    // # of unique CS outputs per Rank for
                                    // phy.
  parameter DQS_CNT_WIDTH         = 3;
                                    // # = ceil(log2(DQS_WIDTH)).
  parameter RANK_WIDTH            = 1;
                                    // # = ceil(log2(RANKS)).
  parameter BANK_WIDTH            = 3;
                                    // # of memory Bank Address bits.
  parameter CK_WIDTH              = 1;
                                    // # of CK/CK# outputs to memory.
  parameter CKE_WIDTH             = 1;
                                    // # of CKE outputs to memory.
  parameter COL_WIDTH             = 10;
                                    // # of memory Column Address bits.
  parameter CS_WIDTH              = 1;
                                    // # of unique CS outputs to memory.
  parameter DM_WIDTH              = 8;
                                    // # of Data Mask bits.
  parameter DQ_WIDTH              = 64;
                                    // # of Data (DQ) bits.
  parameter DQS_WIDTH             = 8;
                                    // # of DQS/DQS# bits.
  parameter ROW_WIDTH             = 13;
                                    // # of memory Row Address bits.
  parameter BURST_MODE            = "4";
                                    // Burst Length (Mode Register 0).
                                    // # = "8", "4", "OTF".
  parameter INPUT_CLK_TYPE        = "DIFFERENTIAL";
                                    // input clock type DIFFERENTIAL or SINGLE_ENDED
  parameter BM_CNT_WIDTH          = 2;
                                    // # = ceil(log2(nBANK_MACHS)).
  parameter ADDR_CMD_MODE         = "1T" ;
                                    // # = "2T", "1T".
  parameter ORDERING              = "STRICT";
                                    // # = "NORM", "STRICT".
  parameter RTT_NOM               = "60";
                                    // RTT_NOM (ODT) (Mode Register 1).
                                    // # = "DISABLED" - RTT_NOM disabled,
                                    //   = "120" - RZQ/2,
                                    //   = "60" - RZQ/4,
                                    //   = "40" - RZQ/6.
   parameter RTT_WR               = "OFF";
                                       // RTT_WR (ODT) (Mode Register 2).
                                       // # = "OFF" - Dynamic ODT off,
                                       //   = "120" - RZQ/2,
                                       //   = "60" - RZQ/4,
  parameter OUTPUT_DRV            = "HIGH";
                                    // Output Driver Impedance Control (Mode Register 1).
                                    // # = "HIGH" - RZQ/7,
                                    //   = "LOW" - RZQ/6.
  parameter REG_CTRL              = "OFF";
                                    // # = "ON" - RDIMMs,
                                    //   = "OFF" - Components, SODIMMs, UDIMMs.
  parameter CLKFBOUT_MULT_F       = 6;
                                    // write PLL VCO multiplier.
  // See http://forums.xilinx.com/t5/Xilinx-Boards-and-Kits/ML605-MIG-Reference-Design/td-p/135372
  parameter DIVCLK_DIVIDE = 1;//2; // write PLL VCO divisor.
  
  parameter CLKOUT_DIVIDE         = 3;
                                    // VCO output divisor for fast (memory) clocks.
  parameter tCK                   = 2500;
                                    // memory tCK paramter.
                                    // # = Clock Period.
  parameter DEBUG_PORT            = "OFF";
                                    // # = "ON" Enable debug signals/controls.
                                    //   = "OFF" Disable debug signals/controls.
  parameter tPRDI                   = 1_000_000;
                                    // memory tPRDI paramter.
  parameter tREFI                   = 7800000;
                                    // memory tREFI paramter.
  parameter tZQI                    = 128_000_000;
                                    // memory tZQI paramter.
  parameter ADDR_WIDTH              = 27;
                                    // # = RANK_WIDTH + BANK_WIDTH
                                    //     + ROW_WIDTH + COL_WIDTH;
  parameter TCQ                     = 100;
  parameter ECC                     = "OFF";
  parameter ECC_TEST                = "OFF";

  //**************************************************************************//
  // Local parameters Declarations
  //**************************************************************************//
  localparam real TPROP_DQS          = 0.00;  // Delay for DQS signal during Write Operation
  localparam real TPROP_DQS_RD       = 0.00;  // Delay for DQS signal during Read Operation
  localparam real TPROP_PCB_CTRL     = 0.00;  // Delay for Address and Ctrl signals
  localparam real TPROP_PCB_DATA     = 0.00;  // Delay for data signal during Write operation
  localparam real TPROP_PCB_DATA_RD  = 0.00;  // Delay for data signal during Read operation

  localparam MEMORY_WIDTH = 16;
  localparam NUM_COMP = DQ_WIDTH/MEMORY_WIDTH;
  localparam real CLK_PERIOD = tCK;
  localparam real REFCLK_PERIOD = (1000000.0/(2*REFCLK_FREQ));
  localparam DRAM_DEVICE = "SODIMM";
                         // DRAM_TYPE: "UDIMM", "RDIMM", "COMPS"

   // VT delay change options/settings
  localparam VT_ENABLE                  = "OFF";
                                        // Enable VT delay var's
  localparam VT_RATE                    = CLK_PERIOD/500;
                                        // Size of each VT step
  localparam VT_UPDATE_INTERVAL         = CLK_PERIOD*50;
                                        // Update interval
  localparam VT_MAX                     = CLK_PERIOD/40;
                                        // Maximum VT shift


  //**************************************************************************//
  // Wire Declarations
  //**************************************************************************//
  wire[7:0] GPIO_LED;
  reg clk_ref;// sys_clk;
  reg sys_rst_n;
  wire clk_ref_p, clk_ref_n;// sys_clk_p, sys_clk_n;

  reg [DM_WIDTH-1:0]                 ddr3_dm_sdram_tmp;

  wire sys_rst;

  wire                               error;
  wire                               phy_init_done;
  wire                               ddr3_parity;
  wire                               ddr3_reset_n;
  //wire sda, scl;

  wire [DQ_WIDTH-1:0]                ddr3_dq_fpga;
  wire [ROW_WIDTH-1:0]               ddr3_addr_fpga;
  wire [BANK_WIDTH-1:0]              ddr3_ba_fpga;
  wire                               ddr3_ras_n_fpga;
  wire                               ddr3_cas_n_fpga;
  wire                               ddr3_we_n_fpga;
  wire [(CS_WIDTH*nCS_PER_RANK)-1:0] ddr3_cs_n_fpga;
  wire [(CS_WIDTH*nCS_PER_RANK)-1:0] ddr3_odt_fpga;
  wire [CKE_WIDTH-1:0]               ddr3_cke_fpga;
  wire [DM_WIDTH-1:0]                ddr3_dm_fpga;
  wire [DQS_WIDTH-1:0]               ddr3_dqs_p_fpga;
  wire [DQS_WIDTH-1:0]               ddr3_dqs_n_fpga;
  wire [CK_WIDTH-1:0]                ddr3_ck_p_fpga;
  wire [CK_WIDTH-1:0]                ddr3_ck_n_fpga;

  wire [DQ_WIDTH-1:0]                ddr3_dq_sdram;
  reg [ROW_WIDTH-1:0]                ddr3_addr_sdram;
  reg [BANK_WIDTH-1:0]               ddr3_ba_sdram;
  reg                                ddr3_ras_n_sdram;
  reg                                ddr3_cas_n_sdram;
  reg                                ddr3_we_n_sdram;
  reg [(CS_WIDTH*nCS_PER_RANK)-1:0]  ddr3_cs_n_sdram;
  reg [(CS_WIDTH*nCS_PER_RANK)-1:0]  ddr3_odt_sdram;
  reg [CKE_WIDTH-1:0]                ddr3_cke_sdram;
  wire [DM_WIDTH-1:0]                ddr3_dm_sdram;
  wire [DQS_WIDTH-1:0]               ddr3_dqs_p_sdram;
  wire [DQS_WIDTH-1:0]               ddr3_dqs_n_sdram;
  reg [CK_WIDTH-1:0]                 ddr3_ck_p_sdram;
  reg [CK_WIDTH-1:0]                 ddr3_ck_n_sdram;

  reg [ROW_WIDTH-1:0]               ddr3_addr_r;
  reg [BANK_WIDTH-1:0]              ddr3_ba_r;
  reg                               ddr3_ras_n_r;
  reg                               ddr3_cas_n_r;
  reg                               ddr3_we_n_r;
  reg [(CS_WIDTH*nCS_PER_RANK)-1:0] ddr3_cs_n_r;
  reg [(CS_WIDTH*nCS_PER_RANK)-1:0] ddr3_odt_r;
  reg [CKE_WIDTH-1:0]               ddr3_cke_r;



  //**************************************************************************//
  // Clock generation and reset
  //**************************************************************************//

  initial begin
    //sys_clk   = 1'b0;
    clk_ref   = 1'b1;
    sys_rst_n = 1'b0;

    #120000
      sys_rst_n = 1'b1;
  end

   assign sys_rst = RST_ACT_LOW ? sys_rst_n : ~sys_rst_n;

  // Generate system clock = twice rate of CLK
  //always sys_clk = #(CLK_PERIOD/2.0) ~sys_clk;

  // Generate IDELAYCTRL reference clock (200MHz)
  always clk_ref = #REFCLK_PERIOD ~clk_ref;

  //assign sys_clk_p = sys_clk;
  //assign sys_clk_n = ~sys_clk;

  assign clk_ref_p = clk_ref;
  assign clk_ref_n = ~clk_ref;


  //**************************************************************************//

  always @( * ) begin
    ddr3_ck_p_sdram   <=  #(TPROP_PCB_CTRL) ddr3_ck_p_fpga;
    ddr3_ck_n_sdram   <=  #(TPROP_PCB_CTRL) ddr3_ck_n_fpga;
    ddr3_addr_sdram   <=  #(TPROP_PCB_CTRL) ddr3_addr_fpga;
    ddr3_ba_sdram     <=  #(TPROP_PCB_CTRL) ddr3_ba_fpga;
    ddr3_ras_n_sdram  <=  #(TPROP_PCB_CTRL) ddr3_ras_n_fpga;
    ddr3_cas_n_sdram  <=  #(TPROP_PCB_CTRL) ddr3_cas_n_fpga;
    ddr3_we_n_sdram   <=  #(TPROP_PCB_CTRL) ddr3_we_n_fpga;
    ddr3_cs_n_sdram   <=  #(TPROP_PCB_CTRL) ddr3_cs_n_fpga;
    ddr3_cke_sdram    <=  #(TPROP_PCB_CTRL) ddr3_cke_fpga;
    ddr3_odt_sdram    <=  #(TPROP_PCB_CTRL) ddr3_odt_fpga;
    ddr3_dm_sdram_tmp <=  #(TPROP_PCB_DATA) ddr3_dm_fpga;//DM signal generation
  end

  assign ddr3_dm_sdram = ddr3_dm_sdram_tmp;

// Controlling the bi-directional BUS
  genvar dqwd;
  generate
    for (dqwd = 1;dqwd < DQ_WIDTH;dqwd = dqwd+1) begin : dq_delay
      WireDelay #
       (
        .Delay_g  (TPROP_PCB_DATA),
        .Delay_rd (TPROP_PCB_DATA_RD),
        .ERR_INSERT ("OFF")
       )
      u_delay_dq
       (
        .A     (ddr3_dq_fpga[dqwd]),
        .B     (ddr3_dq_sdram[dqwd]),
        .reset (sys_rst_n),
        .phy_init_done (phy_init_done)
       );
     end
      WireDelay #
       (
        .Delay_g  (TPROP_PCB_DATA),
        .Delay_rd (TPROP_PCB_DATA_RD),
        .ERR_INSERT (ECC)
       )
      u_delay_dq_0
       (
        .A     (ddr3_dq_fpga[0]),
        .B     (ddr3_dq_sdram[0]),
        .reset (sys_rst_n),
        .phy_init_done (phy_init_done)
       );

  endgenerate

  genvar dqswd;
  generate
    for (dqswd = 0;dqswd < DQS_WIDTH;dqswd = dqswd+1) begin : dqs_delay
      WireDelay #
       (
        .Delay_g  (TPROP_DQS),
        .Delay_rd (TPROP_DQS_RD),
        .ERR_INSERT ("OFF")
       )
      u_delay_dqs_p
       (
        .A     (ddr3_dqs_p_fpga[dqswd]),
        .B     (ddr3_dqs_p_sdram[dqswd]),
        .reset (sys_rst_n),
        .phy_init_done (phy_init_done)
       );

      WireDelay #
       (
        .Delay_g  (TPROP_DQS),
        .Delay_rd (TPROP_DQS_RD),
        .ERR_INSERT ("OFF")
       )
      u_delay_dqs_n
       (
        .A     (ddr3_dqs_n_fpga[dqswd]),
        .B     (ddr3_dqs_n_sdram[dqswd]),
        .reset (sys_rst_n),
        .phy_init_done (phy_init_done)
       );
    end
  endgenerate
  //assign sda = 1'b1;
  //assign scl = 1'b1;

  main #(.SIMULATION(1),
     .nCK_PER_CLK               (nCK_PER_CLK),
     .tCK                       (tCK),
     .RST_ACT_LOW               (RST_ACT_LOW),
     .REFCLK_FREQ               (REFCLK_FREQ),
     .IODELAY_GRP               (IODELAY_GRP),
     .INPUT_CLK_TYPE            (INPUT_CLK_TYPE),
     .BANK_WIDTH                (BANK_WIDTH),
     .CK_WIDTH                  (CK_WIDTH),
     .CKE_WIDTH                 (CKE_WIDTH),
     .COL_WIDTH                 (COL_WIDTH),
     .nCS_PER_RANK              (nCS_PER_RANK),
     .DQ_WIDTH                  (DQ_WIDTH),
     .DM_WIDTH                  (DM_WIDTH),
     .DQS_CNT_WIDTH             (DQS_CNT_WIDTH),
     .DQS_WIDTH                 (DQS_WIDTH),
     .ROW_WIDTH                 (ROW_WIDTH),
     .RANK_WIDTH                (RANK_WIDTH),
     .CS_WIDTH                  (CS_WIDTH),
     .BURST_MODE                (BURST_MODE),
     .BM_CNT_WIDTH              (BM_CNT_WIDTH),
     .CLKFBOUT_MULT_F           (CLKFBOUT_MULT_F),
     .DIVCLK_DIVIDE             (DIVCLK_DIVIDE),
     .CLKOUT_DIVIDE             (CLKOUT_DIVIDE),
     .OUTPUT_DRV                (OUTPUT_DRV),
     .REG_CTRL                  (REG_CTRL),
     .RTT_NOM                   (RTT_NOM),
     .RTT_WR                    (RTT_WR),
     .SIM_BYPASS_INIT_CAL       (SIM_BYPASS_INIT_CAL),
     .DEBUG_PORT                (DEBUG_PORT),
     .tPRDI                     (tPRDI),
     .tREFI                     (tREFI),
     .tZQI                      (tZQI),
     .ADDR_CMD_MODE             (ADDR_CMD_MODE),
     .ORDERING                  (ORDERING),
     .ADDR_WIDTH                (ADDR_WIDTH),
     .ECC                       (ECC),
     .ECC_TEST                  (ECC_TEST),
     .TCQ                       (TCQ)
     )main(
       //.sys_clk_p            (sys_clk_p),//Not for ML605
       //.sys_clk_n            (sys_clk_n),//Not for ML605
       .clk_ref_p            (clk_ref_p),
       .clk_ref_n            (clk_ref_n),
       .sys_rst              (sys_rst),
       .ddr3_ck_p            (ddr3_ck_p_fpga),
       .ddr3_ck_n            (ddr3_ck_n_fpga),
       .ddr3_addr            (ddr3_addr_fpga),
       .ddr3_ba              (ddr3_ba_fpga),
       .ddr3_ras_n           (ddr3_ras_n_fpga),
       .ddr3_cas_n           (ddr3_cas_n_fpga),
       .ddr3_we_n            (ddr3_we_n_fpga),
       .ddr3_cs_n            (ddr3_cs_n_fpga),
       .ddr3_cke             (ddr3_cke_fpga),
       .ddr3_odt             (ddr3_odt_fpga),
       .ddr3_reset_n         (ddr3_reset_n),
       .ddr3_dm              (ddr3_dm_fpga),
       .ddr3_dq              (ddr3_dq_fpga),
       .ddr3_dqs_p           (ddr3_dqs_p_fpga),
       .ddr3_dqs_n           (ddr3_dqs_n_fpga),
       //.sda                  (sda),//Not for ML605
       //.scl                  (scl),//Not for ML605
       .GPIO_LED(GPIO_LED)
       );

   // Extra one clock pipelining for RDIMM address and
   // control signals is implemented here (Implemented external to memory model)
   always @( posedge ddr3_ck_p_sdram[0] ) begin
     if ( ddr3_reset_n == 1'b0 ) begin
       ddr3_ras_n_r <= 1'b1;
       ddr3_cas_n_r <= 1'b1;
       ddr3_we_n_r  <= 1'b1;
       ddr3_cs_n_r  <= {(CS_WIDTH*nCS_PER_RANK){1'b1}};
       ddr3_odt_r   <= 1'b0;
     end
     else begin
       ddr3_addr_r  <= #(CLK_PERIOD/2) ddr3_addr_sdram;
       ddr3_ba_r    <= #(CLK_PERIOD/2) ddr3_ba_sdram;
       ddr3_ras_n_r <= #(CLK_PERIOD/2) ddr3_ras_n_sdram;
       ddr3_cas_n_r <= #(CLK_PERIOD/2) ddr3_cas_n_sdram;
       ddr3_we_n_r  <= #(CLK_PERIOD/2) ddr3_we_n_sdram;
       if (~(ddr3_cs_n_sdram[0] | ddr3_cs_n_sdram[1]) & ~phy_init_done)
         ddr3_cs_n_r  <= #(CLK_PERIOD/2) {(CS_WIDTH*nCS_PER_RANK){1'b1}};
       else
         ddr3_cs_n_r  <= #(CLK_PERIOD/2) ddr3_cs_n_sdram;
       ddr3_odt_r   <= #(CLK_PERIOD/2) ddr3_odt_sdram;
     end
   end

   // to avoid tIS violations on CKE when reset is deasserted
   always @( posedge ddr3_ck_n_sdram[0] )
     if ( ddr3_reset_n == 1'b0 )
       ddr3_cke_r <= 1'b0;
     else
       ddr3_cke_r <= #(CLK_PERIOD) ddr3_cke_sdram;



  //***************************************************************************
  // Instantiate memories
  //***************************************************************************

  genvar r,i,dqs_x;
  generate
    if(DRAM_DEVICE == "COMP") begin : comp_inst
      for (r = 0; r < CS_WIDTH; r = r+1) begin: mem_rnk
        if(MEMORY_WIDTH == 16) begin: mem_16
          if(DQ_WIDTH/16) begin: gen_mem
            for (i = 0; i < NUM_COMP; i = i + 1) begin: gen_mem
              ddr3_model u_comp_ddr3
                (
                 .rst_n   (ddr3_reset_n),
                 .ck      (ddr3_ck_p_sdram),
                 .ck_n    (ddr3_ck_n_sdram),
                 .cke     (ddr3_cke_sdram[r]),
                 .cs_n    (ddr3_cs_n_sdram[r]),
                 .ras_n   (ddr3_ras_n_sdram),
                 .cas_n   (ddr3_cas_n_sdram),
                 .we_n    (ddr3_we_n_sdram),
                 .dm_tdqs (ddr3_dm_sdram[(2*(i+1)-1):(2*i)]),
                 .ba      (ddr3_ba_sdram),
                 .addr    (ddr3_addr_sdram),
                 .dq      (ddr3_dq_sdram[16*(i+1)-1:16*(i)]),
                 .dqs     (ddr3_dqs_p_sdram[(2*(i+1)-1):(2*i)]),
                 .dqs_n   (ddr3_dqs_n_sdram[(2*(i+1)-1):(2*i)]),
                 .tdqs_n  (),
                 .odt     (ddr3_odt_sdram[r])
                 );
            end
          end
          if (DQ_WIDTH%16) begin: gen_mem_extrabits
            ddr3_model u_comp_ddr3
              (
               .rst_n   (ddr3_reset_n),
               .ck      (ddr3_ck_p_sdram),
               .ck_n    (ddr3_ck_n_sdram),
               .cke     (ddr3_cke_sdram[r]),
               .cs_n    (ddr3_cs_n_sdram[r]),
               .ras_n   (ddr3_ras_n_sdram),
               .cas_n   (ddr3_cas_n_sdram),
               .we_n    (ddr3_we_n_sdram),
               .dm_tdqs ({ddr3_dm_sdram[DM_WIDTH-1],ddr3_dm_sdram[DM_WIDTH-1]}),
               .ba      (ddr3_ba_sdram),
               .addr    (ddr3_addr_sdram),
               .dq      ({ddr3_dq_sdram[DQ_WIDTH-1:(DQ_WIDTH-8)],
                          ddr3_dq_sdram[DQ_WIDTH-1:(DQ_WIDTH-8)]}),
               .dqs     ({ddr3_dqs_p_sdram[DQS_WIDTH-1],
                          ddr3_dqs_p_sdram[DQS_WIDTH-1]}),
               .dqs_n   ({ddr3_dqs_n_sdram[DQS_WIDTH-1],
                          ddr3_dqs_n_sdram[DQS_WIDTH-1]}),
               .tdqs_n  (),
               .odt     (ddr3_odt_sdram[r])
               );
          end
        end
        else if((MEMORY_WIDTH == 8) || (MEMORY_WIDTH == 4)) begin: mem_8_4
          for (i = 0; i < NUM_COMP; i = i + 1) begin: gen_mem
            ddr3_model u_comp_ddr3
              (
               .rst_n   (ddr3_reset_n),
               .ck      (ddr3_ck_p_sdram),
               .ck_n    (ddr3_ck_n_sdram),
               .cke     (ddr3_cke_sdram[r]),
               .cs_n    (ddr3_cs_n_sdram[r]),
               .ras_n   (ddr3_ras_n_sdram),
               .cas_n   (ddr3_cas_n_sdram),
               .we_n    (ddr3_we_n_sdram),
               .dm_tdqs (ddr3_dm_sdram[i]),
               .ba      (ddr3_ba_sdram),
               .addr    (ddr3_addr_sdram),
               .dq      (ddr3_dq_sdram[MEMORY_WIDTH*(i+1)-1:MEMORY_WIDTH*(i)]),
               .dqs     (ddr3_dqs_p_sdram[i]),
               .dqs_n   (ddr3_dqs_n_sdram[i]),
               .tdqs_n  (),
               .odt     (ddr3_odt_sdram[r])
               );
          end
        end
      end
    end
    else if(DRAM_DEVICE == "RDIMM") begin: rdimm_inst
      for (r = 0; r < CS_WIDTH; r = r+1) begin: mem_rnk
        if((MEMORY_WIDTH == 8) || (MEMORY_WIDTH == 4)) begin: mem_8_4
          for (i = 0; i < NUM_COMP; i = i + 1) begin: gen_mem
            ddr3_model u_comp_ddr3
              (
               .rst_n   (ddr3_reset_n),
               .ck      (ddr3_ck_p_sdram[(i*MEMORY_WIDTH)/72]),
               .ck_n    (ddr3_ck_n_sdram[(i*MEMORY_WIDTH)/72]),
               .cke     (ddr3_cke_r[((i*MEMORY_WIDTH)/72)+(nCS_PER_RANK*r)]),
               .cs_n    (ddr3_cs_n_r[((i*MEMORY_WIDTH)/72)+(nCS_PER_RANK*r)]),
               .ras_n   (ddr3_ras_n_r),
               .cas_n   (ddr3_cas_n_r),
               .we_n    (ddr3_we_n_r),
               .dm_tdqs (ddr3_dm_sdram[i]),
               .ba      (ddr3_ba_r),
               .addr    (ddr3_addr_r),
               .dq      (ddr3_dq_sdram[MEMORY_WIDTH*(i+1)-1:MEMORY_WIDTH*(i)]),
               .dqs     (ddr3_dqs_p_sdram[i]),
               .dqs_n   (ddr3_dqs_n_sdram[i]),
               .tdqs_n  (),
               .odt     (ddr3_odt_r[((i*MEMORY_WIDTH)/72)+(nCS_PER_RANK*r)])
               );
          end
        end
      end
    end
    else if(DRAM_DEVICE == "UDIMM") begin: udimm_inst
      for (r = 0; r < CS_WIDTH; r = r+1) begin: mem_rnk
        if(MEMORY_WIDTH == 16) begin: mem_16
          if(DQ_WIDTH/16) begin: gen_mem
            for (i = 0; i < NUM_COMP; i = i + 1) begin: gen_mem
              ddr3_model u_comp_ddr3
                (
                 .rst_n   (ddr3_reset_n),
                 .ck      (ddr3_ck_p_sdram[(i*MEMORY_WIDTH)/72]),
                 .ck_n    (ddr3_ck_n_sdram[(i*MEMORY_WIDTH)/72]),
                 .cke     (ddr3_cke_sdram[((i*MEMORY_WIDTH)/72)+(nCS_PER_RANK*r)]),
                 .cs_n    (ddr3_cs_n_sdram[((i*MEMORY_WIDTH)/72)+(nCS_PER_RANK*r)]),
                 .ras_n   (ddr3_ras_n_sdram),
                 .cas_n   (ddr3_cas_n_sdram),
                 .we_n    (ddr3_we_n_sdram),
                 .dm_tdqs (ddr3_dm_sdram[(2*(i+1)-1):(2*i)]),
                 .ba      (ddr3_ba_sdram),
                 .addr    (ddr3_addr_sdram),
                 .dq      (ddr3_dq_sdram[MEMORY_WIDTH*(i+1)-1:MEMORY_WIDTH*(i)]),
                 .dqs     (ddr3_dqs_p_sdram[(2*(i+1)-1):(2*i)]),
                 .dqs_n   (ddr3_dqs_n_sdram[(2*(i+1)-1):(2*i)]),
                 .tdqs_n  (),
                 .odt     (ddr3_odt_sdram[((i*MEMORY_WIDTH)/72)+(nCS_PER_RANK*r)])
                 );
            end
          end
          if (DQ_WIDTH%16) begin: gen_mem_extrabits
            ddr3_model u_comp_ddr3
              (
               .rst_n   (ddr3_reset_n),
               .ck      (ddr3_ck_p_sdram[(DQ_WIDTH-1)/72]),
               .ck_n    (ddr3_ck_n_sdram[(DQ_WIDTH-1)/72]),
               .cke     (ddr3_cke_sdram[((DQ_WIDTH-1)/72)+(nCS_PER_RANK*r)]),
               .cs_n    (ddr3_cs_n_sdram[((DQ_WIDTH-1)/72)+(nCS_PER_RANK*r)]),
               .ras_n   (ddr3_ras_n_sdram),
               .cas_n   (ddr3_cas_n_sdram),
               .we_n    (ddr3_we_n_sdram),
               .dm_tdqs ({ddr3_dm_sdram[DM_WIDTH-1],ddr3_dm_sdram[DM_WIDTH-1]}),
               .ba      (ddr3_ba_sdram),
               .addr    (ddr3_addr_sdram),
               .dq      ({ddr3_dq_sdram[DQ_WIDTH-1:(DQ_WIDTH-8)],
                          ddr3_dq_sdram[DQ_WIDTH-1:(DQ_WIDTH-8)]}),
               .dqs     ({ddr3_dqs_p_sdram[DQS_WIDTH-1],
                          ddr3_dqs_p_sdram[DQS_WIDTH-1]}),
               .dqs_n   ({ddr3_dqs_n_sdram[DQS_WIDTH-1],
                          ddr3_dqs_n_sdram[DQS_WIDTH-1]}),
               .tdqs_n  (),
               .odt     (ddr3_odt_sdram[((DQ_WIDTH-1)/72)+(nCS_PER_RANK*r)])
               );
          end
        end
        else if((MEMORY_WIDTH == 8) || (MEMORY_WIDTH == 4)) begin: mem_8_4
          for (i = 0; i < NUM_COMP; i = i + 1) begin: gen_mem
            ddr3_model u_comp_ddr3
              (
               .rst_n   (ddr3_reset_n),
               .ck      (ddr3_ck_p_sdram[(i*MEMORY_WIDTH)/72]),
               .ck_n    (ddr3_ck_n_sdram[(i*MEMORY_WIDTH)/72]),
               .cke     (ddr3_cke_sdram[((i*MEMORY_WIDTH)/72)+(nCS_PER_RANK*r)]),
               .cs_n    (ddr3_cs_n_sdram[((i*MEMORY_WIDTH)/72)+(nCS_PER_RANK*r)]),
               .ras_n   (ddr3_ras_n_sdram),
               .cas_n   (ddr3_cas_n_sdram),
               .we_n    (ddr3_we_n_sdram),
               .dm_tdqs (ddr3_dm_sdram[i]),
               .ba      (ddr3_ba_sdram),
               .addr    (ddr3_addr_sdram),
               .dq      (ddr3_dq_sdram[MEMORY_WIDTH*(i+1)-1:MEMORY_WIDTH*(i)]),
               .dqs     (ddr3_dqs_p_sdram[i]),
               .dqs_n   (ddr3_dqs_n_sdram[i]),
               .tdqs_n  (),
               .odt     (ddr3_odt_sdram[((i*MEMORY_WIDTH)/72)+(nCS_PER_RANK*r)])
               );
          end
        end
      end
    end
    else if(DRAM_DEVICE == "SODIMM") begin: sodimm_inst
      for (r = 0; r < CS_WIDTH; r = r+1) begin: mem_rnk
        if(MEMORY_WIDTH == 16) begin: mem_16
          if(DQ_WIDTH/16) begin: gen_mem
            for (i = 0; i < NUM_COMP; i = i + 1) begin: gen_mem
              ddr3_model u_comp_ddr3
                (
                 .rst_n   (ddr3_reset_n),
                 .ck      (ddr3_ck_p_sdram[(i*MEMORY_WIDTH)/72]),
                 .ck_n    (ddr3_ck_n_sdram[(i*MEMORY_WIDTH)/72]),
                 .cke     (ddr3_cke_sdram[((i*MEMORY_WIDTH)/72)+(nCS_PER_RANK*r)]),
                 .cs_n    (ddr3_cs_n_sdram[((i*MEMORY_WIDTH)/72)+(nCS_PER_RANK*r)]),
                 .ras_n   (ddr3_ras_n_sdram),
                 .cas_n   (ddr3_cas_n_sdram),
                 .we_n    (ddr3_we_n_sdram),
                 .dm_tdqs (ddr3_dm_sdram[(2*(i+1)-1):(2*i)]),
                 .ba      (ddr3_ba_sdram),
                 .addr    (ddr3_addr_sdram),
                 .dq      (ddr3_dq_sdram[MEMORY_WIDTH*(i+1)-1:MEMORY_WIDTH*(i)]),
                 .dqs     (ddr3_dqs_p_sdram[(2*(i+1)-1):(2*i)]),
                 .dqs_n   (ddr3_dqs_n_sdram[(2*(i+1)-1):(2*i)]),
                 .tdqs_n  (),
                 .odt     (ddr3_odt_sdram[((i*MEMORY_WIDTH)/72)+(nCS_PER_RANK*r)])
                 );
            end
          end
          if (DQ_WIDTH%16) begin: gen_mem_extrabits
            ddr3_model u_comp_ddr3
              (
               .rst_n   (ddr3_reset_n),
               .ck      (ddr3_ck_p_sdram[(DQ_WIDTH-1)/72]),
               .ck_n    (ddr3_ck_n_sdram[(DQ_WIDTH-1)/72]),
               .cke     (ddr3_cke_sdram[((DQ_WIDTH-1)/72)+(nCS_PER_RANK*r)]),
               .cs_n    (ddr3_cs_n_sdram[((DQ_WIDTH-1)/72)+(nCS_PER_RANK*r)]),
               .ras_n   (ddr3_ras_n_sdram),
               .cas_n   (ddr3_cas_n_sdram),
               .we_n    (ddr3_we_n_sdram),
               .dm_tdqs ({ddr3_dm_sdram[DM_WIDTH-1],ddr3_dm_sdram[DM_WIDTH-1]}),
               .ba      (ddr3_ba_sdram),
               .addr    (ddr3_addr_sdram),
               .dq      ({ddr3_dq_sdram[DQ_WIDTH-1:(DQ_WIDTH-8)],
                          ddr3_dq_sdram[DQ_WIDTH-1:(DQ_WIDTH-8)]}),
               .dqs     ({ddr3_dqs_p_sdram[DQS_WIDTH-1],
                          ddr3_dqs_p_sdram[DQS_WIDTH-1]}),
               .dqs_n   ({ddr3_dqs_n_sdram[DQS_WIDTH-1],
                          ddr3_dqs_n_sdram[DQS_WIDTH-1]}),
               .tdqs_n  (),
               .odt     (ddr3_odt_sdram[((DQ_WIDTH-1)/72)+(nCS_PER_RANK*r)])
               );
          end
        end
        if((MEMORY_WIDTH == 8) || (MEMORY_WIDTH == 4)) begin: mem_8_4
          for (i = 0; i < NUM_COMP; i = i + 1) begin: gen_mem
            ddr3_model u_comp_ddr3
              (
               .rst_n   (ddr3_reset_n),
               .ck      (ddr3_ck_p_sdram[(i*MEMORY_WIDTH)/72]),
               .ck_n    (ddr3_ck_n_sdram[(i*MEMORY_WIDTH)/72]),
               .cke     (ddr3_cke_sdram[((i*MEMORY_WIDTH)/72)+(nCS_PER_RANK*r)]),
               .cs_n    (ddr3_cs_n_sdram[((i*MEMORY_WIDTH)/72)+(nCS_PER_RANK*r)]),
               .ras_n   (ddr3_ras_n_sdram),
               .cas_n   (ddr3_cas_n_sdram),
               .we_n    (ddr3_we_n_sdram),
               .dm_tdqs (ddr3_dm_sdram[i]),
               .ba      (ddr3_ba_sdram),
               .addr    (ddr3_addr_sdram),
               .dq      (ddr3_dq_sdram[MEMORY_WIDTH*(i+1)-1:MEMORY_WIDTH*(i)]),
               .dqs     (ddr3_dqs_p_sdram[i]),
               .dqs_n   (ddr3_dqs_n_sdram[i]),
               .tdqs_n  (),
               .odt     (ddr3_odt_sdram[((i*MEMORY_WIDTH)/72)+(nCS_PER_RANK*r)])
               );
          end
        end
      end
    end
  endgenerate

   

  //***************************************************************************
  // Reporting the test case status
  //***************************************************************************
  initial
  begin : Logging
     fork
        begin : calibration_done
           wait (phy_init_done);
           $display("Calibration Done");
           #50000000;
           if (!error) begin
              $display("TEST PASSED");
           end
           else begin
              $display("TEST FAILED: DATA ERROR");
           end
           disable calib_not_done;
            $finish;
        end

        begin : calib_not_done
           #1000000000;
           if (!phy_init_done) begin
              $display("TEST FAILED: INITIALIZATION DID NOT COMPLETE");
           end
           disable calibration_done;
            $finish;
        end
     join
  end

endmodule

