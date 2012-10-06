module main #(parameter SIMULATION = 0)
(input clk_ref_p, clk_ref_n, sys_rst, output[7:0] GPIO_LED
  , input PCIE_PERST_B_LS //The host's master bus reset
  , input PCIE_REFCLK_N, PCIE_REFCLK_P
  , input[3:0] PCIE_RX_N, PCIE_RX_P
  , output[3:0] PCIE_TX_N, PCIE_TX_P
);
`include "function.v"
  wire error, phy_init_done, pll_lock, heartbeat;
  wire clk;

  IBUFGDS dsClkBuf(.O(clk), .I(clk_ref_p), .IB(clk_ref_n));
  
  //***************************************************************************
  assign GPIO_LED[7:4] = {error, phy_init_done, `FALSE, heartbeat};
  localparam FP_SIZE = 20, XB_SIZE=32;
  generate
    if(SIMULATION == 1) begin: simulate_xb
      integer binf, idx, rc;
      reg[XB_SIZE-1:0] xb_wr_data_r;//pc_msg_r;
      reg[7:0] coeff_byte;
      
      localparam COEFF_SYNC_SIZE = 6, N_COEFF_SYNC = {COEFF_SYNC_SIZE{`TRUE}};
      reg[COEFF_SYNC_SIZE-1:0] coeff_sync_ctr;
      reg bus_clk_r, xb_wr_wren_r;//pc_msg_empty_r;
      localparam SIM_UNINITIALIZED = 0, SIM_READ_COEFF = 1
        , SIM_DN_WAIT = 2, SIM_DN_PLAY = 3, SIM_DONE = 4, N_SIM_STATE = 5;
      reg[log2(N_SIM_STATE)-1:0] sim_state;
      
      xb_wr_bram_fifo xb_wr_bram_fifo(.clk(bus_clk)
        //.wr_clk(bus_clk), .rd_clk(clk) //, .rst(rst)
        , .din(xb_wr_data), .wr_en(xb_wr_wren)
        , .rd_en(pc_msg_ack), .dout(pc_msg)
        , .almost_full(xb_wr_full), .empty(pc_msg_empty));

      always #4000 bus_clk_r = ~bus_clk_r;
      assign bus_clk = bus_clk_r;
      //assign pc_msg = pc_msg_r;
      //assign pc_msg_empty = pc_msg_empty_r;
      assign xb_wr_data = xb_wr_data_r;
      assign xb_wr_wren = xb_wr_wren_r;
      
      initial begin
        binf = $fopen("/data/SanityTest/pixel_coeff_0.bin", "rb");
        bus_clk_r <= `FALSE;
        xb_wr_wren_r <= `FALSE;
        sim_state <= SIM_UNINITIALIZED;
      end
      
      always @(posedge bus_clk) begin
        case(sim_state)
          SIM_UNINITIALIZED:
            if(sys_rst) xb_wr_wren_r <= `FALSE;
            else begin
              for(idx=0; idx < XB_SIZE; idx = idx + 8) begin
                rc = $fread(coeff_byte, binf);
                xb_wr_data_r[idx+:8] <= coeff_byte;
              end
              xb_wr_wren_r <= `TRUE;
              sim_state <= SIM_READ_COEFF;
            end
          SIM_READ_COEFF:
            if($feof(binf)) begin
              $fclose(binf);

              binf = $fopen("/data/SanityTest/dn_0.bin", "rb");
              // Read the first message which must be !FVAL
              for(idx=0; idx < XB_SIZE; idx = idx + 8) begin
                rc = $fread(coeff_byte, binf);
                xb_wr_data_r[idx+:8] <= coeff_byte;
              end
              xb_wr_wren_r <= `FALSE;
              coeff_sync_ctr <= 0;
              sim_state <= SIM_DN_PLAY;//SIM_DN_WAIT;
            end else
              if(xb_wr_full) xb_wr_wren_r <= `FALSE;
              else begin
                for(idx=0; idx < XB_SIZE; idx = idx + 8) begin
                  rc = $fread(coeff_byte, binf);
                  xb_wr_data_r[idx+:8] <= coeff_byte;
                end
                xb_wr_wren_r <= `TRUE;
              end
          SIM_DN_WAIT: begin
            xb_wr_wren_r <= `FALSE;
            //Doesn't have to be exact; just sufficient
            if(coeff_sync_ctr == N_COEFF_SYNC)
              sim_state <= SIM_DN_PLAY;
            coeff_sync_ctr <= coeff_sync_ctr + `TRUE;
          end
          SIM_DN_PLAY:
            if($feof(binf)) begin
              xb_wr_wren_r <= `FALSE;
              $fclose(binf);
              sim_state <= SIM_DONE;
            end else
              if(xb_wr_full) xb_wr_wren_r <= `FALSE;
              else begin
                for(idx=0; idx < XB_SIZE; idx = idx + 8) begin
                  rc = $fread(coeff_byte, binf);
                  xb_wr_data_r[idx+:8] <= coeff_byte;
                end
                xb_wr_wren_r <= `TRUE;
              end
          default: xb_wr_wren_r <= `FALSE;
        endcase
      end //always
      
    end else begin: instantiate_xb
        
      xillybus xb(.GPIO_LED(GPIO_LED[3:0]) //For debugging
        , .PCIE_PERST_B_LS(PCIE_PERST_B_LS) // Signals to top level:
        , .PCIE_REFCLK_N(PCIE_REFCLK_N), .PCIE_REFCLK_P(PCIE_REFCLK_P)
        , .PCIE_RX_N(PCIE_RX_N), .PCIE_RX_P(PCIE_RX_P)
        , .PCIE_TX_N(PCIE_TX_N), .PCIE_TX_P(PCIE_TX_P)
        , .bus_clk(bus_clk), .quiesce(quiesce)

        , .user_r_rd_rden(xb_rd_rden), .user_r_rd_empty(xb_rd_empty)
        , .user_r_rd_data(xb_rd_data), .user_r_rd_open(xb_rd_open)
        , .user_r_rd_eof((!pc_msg_empty && (pc_msg == ~0) && xb_rd_empty)
                         || app_done)
                         
        , .user_w_wr_wren(xb_wr_wren), .user_w_wr_full(xb_wr_full)
        , .user_w_wr_data(xb_wr_data), .user_w_wr_open(xb_wr_open)
        
        , .user_r_rd_loop_rden(xb_loop_rden)
        , .user_r_rd_loop_empty(xb_loop_empty)
        , .user_r_rd_loop_data(xb_loop_data)
        , .user_r_rd_loop_open(xb_loop_open)
        , .user_r_rd_loop_eof(!xb_wr_open && xb_loop_empty)
        );

      xb_wr_fifo xb_wr_fifo(.clk(bus_clk), .rst(sys_rst)//.wr_clk(bus_clk), .rd_clk(clk)
        , .din(xb_wr_data), .wr_en(xb_wr_wren)
        , .rd_en(pc_msg_ack), .dout(pc_msg)
        , .full(xb_wr_full), .empty(pc_msg_empty));

      // Data from dram lock clock domain to PCIe domain
      xb_rd_fifo xb_rd_fifo(.wr_clk(clk), .rd_clk(bus_clk), .rst(sys_rst)
        , .din(fpga_msg), .wr_en(fpga_msg_valid && xb_rd_open)
        , .rd_en(xb_rd_rden), .dout(xb_rd_data)
        , .full(fpga_msg_full), .empty(xb_rd_empty));

      xb_loopback_fifo xb_loopback_fifo(.clk(bus_clk)//, .rst(rst)
        , .din(pc_msg), .wr_en(pc_msg_ack)
        , .rd_en(xb_loop_rden), .dout(xb_loop_data)
        , .full(xb_loop_full), .empty(xb_loop_empty));
    end
  endgenerate

  application#(.FP_SIZE(FP_SIZE), .XB_SIZE(XB_SIZE))
    app(.reset(sys_rst), .clk(clk)
      , .error(error), .heartbeat(heartbeat)
      //xillybus signals
      , .bus_clk(bus_clk)
      , .pc_msg_empty(pc_msg_empty), .pc_msg_ack(pc_msg_ack)
      , .pc_msg(pc_msg)
      , .fpga_msg_valid(fpga_msg_valid), .fpga_msg_full(rd_fifo_full)
      , .fpga_msg(fpga_msg)
      );
endmodule
