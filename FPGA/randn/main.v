module main#(parameter SIMULATION=0, DELAY=1)
(input RESET, CLK_P, CLK_N, output[7:0] GPIO_LED);
`include "function.v"
  wire CLK;
  localparam XB_SIZE = 32;
  wire BUS_CLK, quiesce
   , xb_rd_rden         //xb_rd_fifo -> xillybus
   , xb_rd_empty        //xb_rd_fifo -> xillybus
   , xb_rd_open         //xillybus -> xb_rd_fifo
   , fpga_msg_valid     //app -> xb_rd_fifo
   , fpga_msg_full, fpga_msg_overflow//xb_rd_fifo -> app
   , pc_msg_empty //xb_wr_fifo -> app; NOT of empty
   //, pc_msg_pending
   , pc_msg_ack         // app -> xb_wr_fifo
   , xb_wr_wren         // xillybus -> xb_wr_fifo
   , xb_wr_full         // xb_wr_fifo -> xillybus
   , xb_wr_open         // xillybus -> xb_wr_fifo
   , xb_loop_rden       // xillybus -> xb_loop_fifo
   , xb_loop_empty      // xb_loop_fifo -> xillybus
   , xb_loop_full;      // xb_loop_fifo -> xillybus
  reg xb_rd_eof, pc_msg_pending_d;
  wire[XB_SIZE-1:0] xb_rd_data //xb_rd_fifo -> xillybus
   , xb_loop_data       // xb_loopback_fifo -> xillybus
   , xb_wr_data         // xillybus -> xb_wr_fifo
   , pc_msg;
  reg [XB_SIZE-1:0] pc_msg_d;
  wire[XB_SIZE-1:0] fpga_msg;//app -> xb_rd_fifo

  IBUFGDS sysclk_buf(.I(CLK_P), .IB(CLK_N), .O(CLK));
  
  generate
    if(SIMULATION) begin: simulate_xb
      integer binf, idx, rc, n_msg = 0;
      reg[XB_SIZE-1:0] xb_wr_data_r;//pc_msg_r;
      reg[7:0] pool_byte;

      localparam COEFF_SYNC_SIZE = 6, N_COEFF_SYNC = {COEFF_SYNC_SIZE{`TRUE}};
      reg[COEFF_SYNC_SIZE-1:0] coeff_sync_ctr;
      reg bus_clk_r, xb_wr_wren_r;//wr_data_empty_r;
      localparam SIM_UNINITIALIZED = 0, SIM_READ_POOL = 1, SIM_DONE = 2
               , N_SIM_STATE = 3;
      reg [log2(N_SIM_STATE)-1:0] sim_state;

      always #4 bus_clk_r = ~bus_clk_r;
      assign BUS_CLK = bus_clk_r;
      //assign pc_msg = pc_msg_r;
      //assign pc_msg_empty = wr_data_empty_r;
      assign xb_wr_data = xb_wr_data_r;
      assign xb_wr_wren = xb_wr_wren_r;
      assign xb_rd_open = `TRUE;
      assign xb_rd_rden = `TRUE;
      assign xb_loop_rden = `TRUE;

      initial begin
        binf = $fopen("pool1024.bin", "rb");
        bus_clk_r <= #DELAY `FALSE;
        xb_wr_wren_r <= #DELAY `FALSE;
        sim_state <= #DELAY SIM_UNINITIALIZED;
      end

      always @(posedge BUS_CLK) begin
        case(sim_state)
          SIM_UNINITIALIZED:
            if(RESET /*|| !app_rdy */|| xb_wr_full)
              xb_wr_wren_r <= #DELAY `FALSE;
            else begin
              for(idx=0; idx < XB_SIZE; idx = idx + 8) begin
                rc = $fread(pool_byte, binf);
                xb_wr_data_r[idx+:8] <= #DELAY pool_byte;
              end
              xb_wr_wren_r <= #DELAY `TRUE;
              sim_state <= #DELAY SIM_READ_POOL;
            end

          SIM_READ_POOL:
            if($feof(binf)) begin
              xb_wr_wren_r <= #DELAY `FALSE;
              $fclose(binf);
              sim_state <= #DELAY SIM_DONE;
            end else begin
              n_msg = n_msg + 1;
              if(xb_wr_full) xb_wr_wren_r <= #DELAY `FALSE;
              else begin
                for(idx=0; idx < XB_SIZE; idx = idx + 8) begin
                  rc = $fread(pool_byte, binf);
                  xb_wr_data_r[idx+:8] <= #DELAY pool_byte;
                end
                xb_wr_wren_r <= #DELAY `TRUE;
              end
            end
            
          default: xb_wr_wren_r <= #DELAY `FALSE;
        endcase
      end //always
    end else begin// !SIMULATION
      xillybus xb(.GPIO_LED(GPIO_LED[3:0]) //For debugging
        , .PCIE_PERST_B_LS(PCIE_PERST_B_LS) // Signals to top level:
        , .PCIE_REFCLK_N(PCIE_REFCLK_N), .PCIE_REFCLK_P(PCIE_REFCLK_P)
        , .PCIE_RX_N(PCIE_RX_N), .PCIE_RX_P(PCIE_RX_P)
        , .PCIE_TX_N(PCIE_TX_N), .PCIE_TX_P(PCIE_TX_P)
        , .bus_clk(BUS_CLK), .quiesce(quiesce)

        , .user_r_rd_rden(xb_rd_rden), .user_r_rd_empty(xb_rd_empty)
        , .user_r_rd_data(xb_rd_data), .user_r_rd_open(xb_rd_open)
        , .user_r_rd_eof(xb_rd_eof)

        , .user_w_wr_wren(xb_wr_wren)
        , .user_w_wr_full(xb_wr_full/*|| xb_loop_full*/)
        , .user_w_wr_data(xb_wr_data), .user_w_wr_open(xb_wr_open)

        , .user_r_rd_loop_rden(xb_loop_rden)
        , .user_r_rd_loop_empty(xb_loop_empty)
        , .user_r_rd_loop_data(xb_loop_data)
        , .user_r_rd_loop_open(xb_loop_open)
        , .user_r_rd_loop_eof(!xb_wr_open && xb_loop_empty)
        );

    `ifdef PR_THIS
      xb_loopback_fifo xb_loopback_fifo(.wr_clk(CLK), .rd_clk(BUS_CLK), .rst(rst)
        , .din(pc_msg_d), .wr_en(pc_msg_pending_d /*pc_msg_ack*/)
        , .rd_en(xb_loop_rden), .dout(xb_loop_data)
        , .full(xb_loop_full), .empty(xb_loop_empty));
    `endif
      xb_rd_fifo xb_rd_fifo(.rst(rst) //RESET
        , .wr_clk(CLK), .din(fpga_msg), .wr_en(fpga_msg_valid /*&& xb_rd_open*/)
        , .full(fpga_msg_full), .overflow(fpga_msg_overflow)
        , .rd_clk(BUS_CLK), .rd_en(xb_rd_rden), .dout(xb_rd_data)
        , .empty(xb_rd_empty));
    end//!SIMULATION
  endgenerate

  better_fifo#(.WIDTH(XB_SIZE), .DELAY(DELAY))
    xb_wr_fifo(.RESET(RESET)
             , .WR_CLK(BUS_CLK), .din(xb_wr_data), .wren(xb_wr_wren)
             , .full(), .almost_full(xb_wr_full)
             , .RD_CLK(CLK), .rden(pc_msg_ack), .dout(pc_msg)
             , .empty(pc_msg_empty));

  application#(.DELAY(DELAY))
    app(.CLK(CLK), .RESET(RESET), .GPIO_LED(GPIO_LED));
endmodule
