module main#(parameter SIMULATION=0, DELAY=1)
(input RESET
  , input PCIE_PERST_B_LS //The host's master bus reset
  //For Virtex-6 a 250 MHz clock, which is derived from the PCIe bus clock,
  //is expected on these wires. If a different clock is applied, the Xilinx
  //PCIe Coregen core (defined by pcie v6 4x.xco in the bundle) must be
  //reconfigured to expect the real clock frequency. Such a change may also
  //involve changes in the constraints.
  , input PCIE_REFCLK_N, PCIE_REFCLK_P
  , input[3:0] PCIE_RX_N, PCIE_RX_P
  , output[3:0] PCIE_TX_N, PCIE_TX_P
  , output[7:0] GPIO_LED // For debugging
);
`include "function.v"
  localparam N_PATCH = 600000 // Total # of patches I expect
    , SYNC_WINDOW = 2**13//I can handle up to this may out-of-order patches
    , LFSR_SIZE = log2(SYNC_WINDOW) - 1
    , FP_SIZE = 20
    , WTSUM_SIZE = log2(N_PATCH) + FP_SIZE
    , N_CAM = 3
    , XB_SIZE = 32;//xillybus size
  wire BUS_CLK, quiesce
     , rd_rden, rd_empty, rd_open, wr_wren, wr_full, wr_open
     , loop_rden, loop_empty, rd_loop_open, loop_full
     , wr_fifo_ack, app_msg_valid, wr_fifo_empty, rd_fifo_full;
  reg  xb_rd_eof;
  wire[XB_SIZE-1:0] rd_data, wr_data, rd_loop_data, output_data;
  wire[2*XB_SIZE-1:0] wr_fifo_data;
  wire app_rdy, app_done, output_valid;
  reg [N_CAM-1:0] input_valid;
  reg [(N_CAM*WTSUM_SIZE)-1:0] input_data;
  reg fpga_msg_valid;
  reg [XB_SIZE-1:0] fpga_msg;
  
  integer i;
  genvar geni;
  //If you have a clock signal coming in, if it is routed over a global clock
  //buffer then everything that uses that clock must be after the clock buffer
  //IBUFG dsClkBuf(.O(cl_pclk), .I(cl_z_pclk));

  xillybus xb(.GPIO_LED(GPIO_LED[3:0]) //For debugging
    , .PCIE_PERST_B_LS(PCIE_PERST_B_LS) // Signals to top level:
    , .PCIE_REFCLK_N(PCIE_REFCLK_N), .PCIE_REFCLK_P(PCIE_REFCLK_P)
    , .PCIE_RX_N(PCIE_RX_N), .PCIE_RX_P(PCIE_RX_P)
    , .PCIE_TX_N(PCIE_TX_N), .PCIE_TX_P(PCIE_TX_P)
    , .bus_clk(BUS_CLK), .quiesce(quiesce)

    , .user_r_rd_rden(rd_rden), .user_r_rd_empty(rd_empty)
    , .user_r_rd_data(rd_data), .user_r_rd_open(rd_open)
    , .user_r_rd_eof(xb_rd_eof)
    
    , .user_w_wr_wren(wr_wren), .user_w_wr_full(wr_full)
    , .user_w_wr_data(wr_data), .user_w_wr_open(wr_open)
    
    , .user_r_rd_loop_rden(loop_rden), .user_r_rd_loop_empty(loop_empty)
    , .user_r_rd_loop_data(rd_loop_data)
    , .user_r_rd_loop_open(rd_loop_open)
    , .user_r_rd_loop_eof(!wr_open && loop_empty));

  // BRAM FIFOs, so these can be behaviorally simulated
  xb_wr_fifo xb_wr_fifo(.wr_clk(BUS_CLK), .rd_clk(BUS_CLK), .rst(RESET)
    , .din(wr_data), .wr_en(wr_wren)
    , .rd_en(wr_fifo_ack), .dout(wr_fifo_data)
    , .full(wr_full), .empty(wr_fifo_empty));

  xb_rd_fifo xb_rd_fifo(.rst(RESET), .wr_clk(BUS_CLK), .rd_clk(BUS_CLK)
    , .din(fpga_msg), .wr_en(fpga_msg_valid && rd_open)
    , .rd_en(rd_rden), .dout(rd_data)
    , .full(rd_fifo_full), .empty(rd_empty));

  xb_loopback_fifo xb_loopback_fifo(.rst(RESET)
    , .wr_clk(BUS_CLK), .rd_clk(BUS_CLK)
    , .din(wr_fifo_data), .wr_en(wr_fifo_ack)
    , .rd_en(loop_rden), .dout(rd_loop_data)
    , .full(loop_full), .empty(loop_empty));

  application#(.DELAY(DELAY), .SYNC_WINDOW(SYNC_WINDOW), .FP_SIZE(FP_SIZE)
    , .N_PATCH(N_PATCH), .N_CAM(N_CAM), .XB_SIZE(XB_SIZE))
    app(.CLK(BUS_CLK), .RESET(RESET)
      , .GPIO_LED(GPIO_LED[7:4]), .ready(app_rdy)
      , .input_valid(input_valid), .input_data(input_data)
      , .output_valid(output_valid), .output_data(output_data));

  assign wr_fifo_ack = !wr_fifo_empty && app_rdy;
  
  //assign GPIO_LED[7:4] = {input_valid, app_rdy};

  always @(posedge BUS_CLK)
    if(RESET) xb_rd_eof <= #DELAY `FALSE;
    else //cmd (top nibble) = 0xF means close the read file
      xb_rd_eof <= #DELAY !wr_fifo_empty && (&wr_fifo_data[(2*XB_SIZE-1)-:4]);

  //Multiplex the data according to the header
  always @(posedge BUS_CLK) begin
    if(RESET) begin
      input_valid <= #DELAY 0;
      input_data <= #DELAY 0;
    end else begin
      if(wr_fifo_empty) begin//Did I get a message from the PC?
        input_valid <= #DELAY 0;
      end else begin//a message from PC; hand off to app (1 clock delay)
        input_valid <= #DELAY wr_fifo_data[56+:N_CAM];
        //Write the same data for all cameras
        for(i=0; i < N_CAM; i=i+1)
          input_data[(i*WTSUM_SIZE) +: WTSUM_SIZE] <= #DELAY //'h2CAFE4BABE;
            wr_fifo_data[(32-FP_SIZE)   //Keep only FP_SIZE of fp
                         +: WTSUM_SIZE];//and include the patch num too
      end//!wr_fifo_empty
    end//!RESET
  end//always

`ifdef RANDOM_PATCHES
  reg [log2(SYNC_WINDOW)-2:0] ctr[N_CAM-1:0], random[N_CAM-1:0];
  reg [log2(N_PATCH)-1:0] random_offset;
  wire[log2(N_PATCH)-1:0] random_patch_num[N_CAM-1:0];
  reg[1:0] ready_r; //To cross the clock domain

  localparam ERROR = 0, INIT = 1
    , INTERFRAME = 2, INTER2INTRA = 3, INTRAFRAME = 4, N_STATE = 5;
  reg [log2(N_STATE)-1:0] state;
  
  assign BUS_CLK = PCIE_REFCLK_P;
  for(geni=0; geni < N_CAM; geni=geni+1)
    assign random_patch_num[geni] = random[geni] + random_offset;

  always @(posedge BUS_CLK)
    if(RESET) begin
      input_valid <= #DELAY 0;
      input_data <= #DELAY 0;
      ready_r <= #DELAY 2'b00;
      random[0] <= #DELAY 512;
      random[1] <= #DELAY 1024;
      random[2] <= #DELAY 2048;
      random_offset <= #DELAY 0;
      for(i=0; i < N_CAM; i=i+1) ctr[i] <= #DELAY 0;
      state <= #DELAY INIT;
    end else begin
      ready_r[1] <= #DELAY ready_r[0]; //To cross the clock domain
      ready_r[0] <= #DELAY app_rdy;

      case(state)
        INIT: begin
          input_valid <= #DELAY 0;
          if(ready_r[1]) begin: init2interframe
            for(i=0; i < N_CAM; i=i+1) ctr[i] <= #DELAY 0;
            state <= #DELAY INTERFRAME;
          end
        end

        INTERFRAME: begin
          for(i=0; i < N_CAM; i=i+1) begin
            input_valid[i] <= #DELAY `TRUE;
            input_data[(i*WTSUM_SIZE) +: WTSUM_SIZE]
              <= #DELAY {random_patch_num[i]
                       , random[i][11], 4'b1000, random[i][10:0], 4'b0000};
          end
          for(i=0; i < N_CAM; i=i+1) ctr[i] <= #DELAY ctr[i] + `TRUE;
          if(ctr[0] == 'h003) begin
            random_offset <= #DELAY -1;//Reserved patch num for SOF
            for(i=0; i < N_CAM; i=i+1) begin
              random[i] <= #DELAY 0;
              ctr[i] <= #DELAY 1;//SOF
            end
            state <= #DELAY INTER2INTRA;
          end
        end
        
        INTER2INTRA: begin
          for(i=0; i < N_CAM; i=i+1) begin
            input_valid[i] <= #DELAY `TRUE;
            input_data[(i*WTSUM_SIZE) +: WTSUM_SIZE]
              <= #DELAY {random_patch_num[i]
                       , random[i][11], 4'b1000, random[i][10:0], 4'b0000};
          end
          random_offset <= #DELAY 0;
          random[0] <= #DELAY 'd512;
          random[1] <= #DELAY 'd1024;
          random[2] <= #DELAY 'd2048;
          for(i=0; i < N_CAM; i=i+1) ctr[i] <= #DELAY 0;
          state <= #DELAY INTRAFRAME;
        end

        INTRAFRAME: begin
          for(i=0; i < N_CAM; i=i+1) begin
            input_valid[i] <= #DELAY `TRUE;
            input_data[(i*WTSUM_SIZE) +: WTSUM_SIZE]
              <= #DELAY {random_patch_num[i]
                       , random[i][11], 4'b1000, random[i][10:0], 4'b0000};
          end
          if(!ready_r[1]) begin
            random_offset <= #DELAY 0;
            random[0] <= #DELAY 512;
            random[1] <= #DELAY 1024;
            random[2] <= #DELAY 2048;
            for(i=0; i < N_CAM; i=i+1) ctr[i] <= #DELAY 0;
            state <= #DELAY ERROR;
          end else begin
            for(i=0; i < N_CAM; i=i+1) begin
              random[i] <= #DELAY {random[i][0+:LFSR_SIZE-1]
                //12 bit implementation
                , !(random[i][11]^random[i][10]^random[i][9]^random[i][3])};
              ctr[i] <= #DELAY ctr[i] + `TRUE;
            end
            
            if(ctr[0] == (2**LFSR_SIZE-2)) begin
              //The last random number sequence in LFSR implementation
              for(i=0; i < N_CAM; i=i+1) ctr[i] <= #DELAY 0;

              if(random_offset > (N_PATCH - 2**12)) begin //rolling over
                //Completely done with N_PATCH, ^EOF
                for(i=0; i < N_CAM; i=i+1) begin
                  random[i] <= #DELAY 0;
                  ctr[i] <= #DELAY 0;
                end
                random_offset <= #DELAY -2;//Reserved patch num for EOF
                state <= #DELAY INTERFRAME;
              end else begin
                random_offset <= #DELAY random_offset + (2**LFSR_SIZE-1);
                state <= #DELAY INTRAFRAME;
              end
            end
          end
        end
        default: begin
          input_valid <= #DELAY 0;
          random_offset <= #DELAY 0;
          random[0] <= #DELAY 512;
          random[1] <= #DELAY 1024;
          random[2] <= #DELAY 2048;
          for(i=0; i < N_CAM; i=i+1) ctr[i] <= #DELAY 0;
          state <= #DELAY ERROR;
        end
      endcase
    end //if(!RESET)
`else
  generate
    if(SIMULATION) begin //because I can't simulate Xillybus
      assign wr_wren = wr_wren_r;
      assign wr_data = wr_data_r;
      assign rd_open = `TRUE;
      assign rd_rden = rd_rden_r;
        
      reg  wr_wren_r, rd_rden_r;
      reg [XB_SIZE-1:0] wr_data_r;
      
      initial begin //simulation
#    0  wr_wren_r = `FALSE;

        //Send SOF
# 8700  wr_wren_r = `TRUE;
        wr_data_r = 'h010FFFFF;
#    8  wr_data_r = 'h3F800000;
#    8  wr_wren_r = `FALSE;

#    8  wr_wren_r = `TRUE;
        wr_data_r = 'h020FFFFF;
#    8  wr_data_r = 'h40000000;
#    8  wr_wren_r = `FALSE;

#    8  wr_wren_r = `TRUE;
        wr_data_r = 'h040FFFFF;
#    8  wr_data_r = 'h40400000;
#    8  wr_wren_r = `FALSE;

        // Send patch #1
#  100  wr_wren_r = `TRUE;
        wr_data_r = 'h01000000;
#    8  wr_data_r = 'hc2480000;//-50.0
#    8  wr_wren_r = `FALSE;

#    8  wr_wren_r = `TRUE;
        wr_data_r = 'h02000000;
#    8  wr_data_r = 'h42480000;//50.0
#    8  wr_wren_r = `FALSE;

#    8  wr_wren_r = `TRUE;
        wr_data_r = 'h04000000;
#    8  wr_data_r = 'h44c00000;//1536.0
#    8  wr_wren_r = `FALSE;

        // Send EOF
#  100  wr_wren_r = `TRUE;
        wr_data_r = 'h010FFFFE;
#    8  wr_data_r = 'h3F800000;
#    8  wr_wren_r = `FALSE;

#    8  wr_wren_r = `TRUE;
        wr_data_r = 'h020FFFFE;
#    8  wr_data_r = 'h40000000;
#    8  wr_wren_r = `FALSE;

#    8  wr_wren_r = `TRUE;
        wr_data_r = 'h040FFFFE;
#    8  wr_data_r = 'h40400000;
#    8  wr_wren_r = `FALSE;
      end

      always @(posedge BUS_CLK)
        if(RESET) rd_rden_r <= #DELAY `FALSE;
        else rd_rden_r <= #DELAY !rd_empty;
    end else begin // not simulation
    end
  endgenerate
`endif

  always @(posedge BUS_CLK)
    if(RESET) begin
      fpga_msg_valid <= #DELAY `FALSE;
      fpga_msg <= #DELAY 0;
    end else begin
      fpga_msg_valid <= #DELAY output_valid;
      fpga_msg <= #DELAY output_data;
    end
endmodule
