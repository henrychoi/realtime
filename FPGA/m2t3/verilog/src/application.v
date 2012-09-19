`timescale 1ps/1ps
module application#(parameter XB_SIZE=1,ADDR_WIDTH=1, APP_DATA_WIDTH=1, FP_SIZE=1)
(input reset, dram_clk, output error, output heartbeat
, output reg app_done
, input app_rdy, output reg app_en, output reg dram_read
, output reg[ADDR_WIDTH-1:0] app_addr
, input app_wdf_rdy, output reg app_wdf_wren, app_wdf_end
, output reg[APP_DATA_WIDTH-1:0] app_wdf_data
, input app_rd_data_valid, input[APP_DATA_WIDTH-1:0] app_rd_data
, input bus_clk, pixel_clk
, input pc_msg_empty, output pc_msg_ack, input[XB_SIZE-1:0] pc_msg
, input fpga_msg_full, output reg fpga_msg_valid, output reg[XB_SIZE-1:0] fpga_msg
);
`include "function.v"
  integer i;
  localparam HB_CTR_SIZE = 16;
  reg[HB_CTR_SIZE-1:0] hb_ctr;

  reg[3:0] n_pc_dram_msg;// = 2 * 256/32
  
  wire pc_msg_is_ds;
  reg pc_msg_is_ds_d, pc_msg_pending_d;
  wire[XB_SIZE-1:0] pixel_msg, dram_msg;
  reg[XB_SIZE-1:0] pc_msg_d;
  wire xb2pixel_full, xb2dram_full, xb2pixel_empty, xb2dram_empty
    , xb2pixel_ack, xb2dram_ack, xb2pixel_wren, xb2dram_wren;

  localparam PIXEL_ERROR = 0, PIXEL_STANDBY = 1, PIXEL_INTRALINE = 2
    , PIXEL_INTERLINE = 3, PIXEL_INTERFRAME = 4, N_PIXEL_STATE = 5;
  reg[log2(N_PIXEL_STATE)-1:0] pixel_state;

  localparam N_FRAME_SIZE = 20
    , N_COL = 2048, N_ROW = 2064 //2k rows + 8 dark pixels top and btm
    , PATCH_SIZE = 6, PATCH_SIZE_MAX = 16
    , N_PATCH = 1024*1024; //let's handle up to 1M
  reg[N_FRAME_SIZE-1:0] n_frame;
  reg[log2(N_ROW)-1:0] n_row;//, n_row_d[N_FADD_LATENCY-1:0];
  reg[log2(N_COL)-1:0] n_col;//, n_col_d[N_FADD_LATENCY-1:0];
  wire[log2(N_PATCH)-1:0] patch_num;
  wire[log2(N_ROW)-1:0] patch_top_row;
  wire patch_val;
  wire[log2(N_COL)-1:0] patch_left_col;
  localparam ROW_REDUCER_CONFIG_SIZE = PATCH_SIZE * FP_SIZE + log2(PATCH_SIZE_MAX);
  wire[ROW_REDUCER_CONFIG_SIZE-1:0] row_reducer_config;
  
  localparam N_FMULT_LATENCY = 8, N_FADD_LATENCY = 8;
  wire fval, lval, fds_val;
  reg fds_val_d;
  //Data always flows (can't stop it); need to distinguish whether it is valid
  //pval (pixel valid) indicates whether this is a legitimate data received from
  //the "camera".  Note one more delay to sync up with the sampled fds_val from
  //the sequential logic
  reg[N_FADD_LATENCY:0] pval_d, fval_d, lval_d, val_d;
  reg[1:0] p2d_fval, p2d_val; // to cross from pixel to dram clock domain
  wire[FP_SIZE-1:0] fds;
  reg[FP_SIZE-1:0] fds_d;

  wire[APP_DATA_WIDTH-1:0] dram_data;

  localparam PATCH_COEFF_SIZE = 43;
  wire row_coeff_fifo_overflow, row_coeff_fifo_high, row_coeff_fifo_empty
    , patch_coeff_fifo_overflow, patch_coeff_fifo_high, patch_coeff_fifo_empty;

  reg[ADDR_WIDTH-1:0] end_addr;
  localparam START_ADDR = 27'h000_0000//, END_ADDR = 27'h3ff_fffc;
    , ADDR_INC = 4'd8;// BL8
  localparam DRAMIFC_ERROR = 0
    , DRAMIFC_WR1 = 1, DRAMIFC_WR2 = 2, DRAMIFC_MSG_WAIT = 3
    , DRAMIFC_WR_WAIT = 4
    , DRAMIFC_READING = 5, DRAMIFC_THROTTLED = 6, DRAMIFC_INTERFRAME = 7
    , DRAMIFC_N_STATE = 8;
  reg[log2(DRAMIFC_N_STATE)-1:0] dramifc_state;
  reg[APP_DATA_WIDTH*2-1:0] tmp_data;
  reg[log2(APP_DATA_WIDTH*2-1)-1:0] tmp_data_offset;
  
  assign heartbeat = hb_ctr[HB_CTR_SIZE-1];
  assign pc_msg_ack = !(pc_msg_empty || xb2pixel_full || xb2dram_full);  
  assign {fval, lval} = pixel_msg[4+:2];
  assign fds = pixel_msg[12+:FP_SIZE];//Note: throw away the 4 LSB
  assign error = dramifc_state == DRAMIFC_ERROR
    || patch_coeff_fifo_overflow;
  // This works only if I ack the xb2pixel fifo as soon as it is !empty
  assign xb2pixel_ack = !patch_coeff_fifo_empty && !xb2pixel_empty;
  assign xb2dram_ack = !xb2dram_empty
   && !(dramifc_state == DRAMIFC_WR1 || dramifc_state == DRAMIFC_WR2
        || dramifc_state == DRAMIFC_WR_WAIT);
  assign xb2pixel_wren = !xb2pixel_full && pc_msg_pending_d &&  pc_msg_is_ds_d;
  assign xb2dram_wren  = !xb2dram_full  && pc_msg_pending_d && !pc_msg_is_ds_d;
  assign pc_msg_is_ds = pc_msg[1:0] != 0 && n_pc_dram_msg == 0;
 
  xb2pixel xb2pixel(.wr_clk(bus_clk), .rd_clk(pixel_clk)//, .rst(rst)
    , .din(pc_msg_d), .wr_en(xb2pixel_wren)
    , .rd_en(xb2pixel_ack), .dout(pixel_msg)
    , .almost_full(xb2pixel_full), .full(), .empty(xb2pixel_empty));

  xb2dram xb2dram(.wr_clk(bus_clk), .rd_clk(dram_clk)//, .rst(rst)
    , .din(pc_msg_d), .wr_en(xb2dram_wren)
    , .rd_en(xb2dram_ack), .dout(dram_msg)
    , .almost_full(xb2dram_full), .full(), .empty(xb2dram_empty));

  patch_coeff_fifo patch_coeff_fifo(.wr_clk(dram_clk), .rd_clk(pixel_clk)
    , .din(app_rd_data[80+:(4 * (PATCH_COEFF_SIZE + 1))])
    //Note: always write into FIFO when there is valid DRAM data because
    //flow control done upstream by DRAMIfc
    , .wr_en(app_rd_data_valid && !app_rd_data[0])
    , .rd_en(`FALSE)//FIXME
    , .dout({patch_num, patch_top_row, patch_val, patch_left_col})
    , .prog_full(patch_coeff_fifo_high), .full()
    , .overflow(patch_coeff_fifo_overflow), .empty(patch_coeff_fifo_empty));

  row_coeff_fifo row_coeff_fifo(.wr_clk(dram_clk), .rd_clk(pixel_clk)
    , .din(app_rd_data[12+:ROW_REDUCER_CONFIG_SIZE])
    //Note: always write into FIFO when there is valid DRAM data because
    //flow control done upstream by DRAMIfc
    , .wr_en(app_rd_data_valid && app_rd_data[0])
    , .rd_en(`FALSE)//FIXME
    , .dout(row_reducer_config)
    , .prog_full(row_coeff_fifo_high), .full()
    , .overflow(row_coeff_fifo_overflow), .empty(row_coeff_fifo_empty));

  always @(posedge reset, posedge fds_val)
    if(reset) hb_ctr <= 0;
    else hb_ctr <= hb_ctr + `TRUE;

  always @(posedge bus_clk)
    if(reset) begin
      n_pc_dram_msg <= 0;
      pc_msg_pending_d <= `FALSE;
    end else begin
      pc_msg_pending_d <= ~pc_msg_empty;
      // Note how the delay through a sequential logic syncs up with pc_msg_d
      pc_msg_is_ds_d <= pc_msg_is_ds;
      if(pc_msg_ack) begin// Was this a real message?
        pc_msg_d <= pc_msg;// delay this to match up against pc_msg_is_ds_d
        if(!pc_msg_is_ds) n_pc_dram_msg <= n_pc_dram_msg + `TRUE;
      end
    end

  always @(posedge pixel_clk) begin
    if(reset) begin
      pixel_state <= PIXEL_STANDBY;
    end else begin
      // Data always flows (fdn and fds is always available);
      // the question is whether it is valid
      pval_d[0] <= xb2pixel_ack;
      fval_d[0] <= fval;
      lval_d[0] <= lval;
      for(i=1; i <= (N_FADD_LATENCY); i=i+1) begin
        pval_d[i] <= pval_d[i-1];
        fval_d[i] <= fval_d[i-1];
        lval_d[i] <= lval_d[i-1];
      end
      // A delay to sync up the floating point logic output with delayed pval
      fds_val_d <= fds_val;
      fds_d <= fds;

     if(!xb2pixel_empty)
       case(pixel_state)
         PIXEL_STANDBY:
           if(!fval) begin
             n_row <= 0; n_col <= 0; n_frame <= 0;
             pixel_state <= PIXEL_INTERFRAME;
           end
         PIXEL_INTRALINE:
           if(patch_coeff_fifo_empty) pixel_state <= PIXEL_ERROR;
           else begin
             if(lval) n_col <= n_col + `TRUE;
             else begin
               if(fval) begin
                 n_row <= n_row + 1'b1;
                 pixel_state <= PIXEL_INTERLINE;
               end else begin
                 n_frame <= n_frame + 1'b1;
                 pixel_state <= PIXEL_INTERFRAME;
               end
             end
           end
         PIXEL_INTERLINE:
           if(lval) begin
              n_col <= 0;
              pixel_state <= PIXEL_INTRALINE;
            end
          PIXEL_INTERFRAME:
            if(lval) begin
              n_row <= 0; n_col <= 0;
              pixel_state <= PIXEL_INTRALINE;
            end
          default: begin
          end
        endcase
    end
  end //always @posedge(pixel_clk)
    
  always @(posedge dram_clk)
    if(reset) begin
  		app_addr <= START_ADDR;
      end_addr <= START_ADDR;
      app_en <= `FALSE;
      dram_read <= `FALSE;
      app_wdf_wren <= `FALSE;
      app_wdf_end <= `TRUE;
      tmp_data_offset <= 0; //APP_DATA_WIDTH - XB_SIZE;
      dramifc_state <= DRAMIFC_MSG_WAIT;
      
      fpga_msg_valid <= `FALSE;
      fpga_msg <= 0;
    end else begin // normal operation
      // Cross the pixel to DRAM clock domain with 2 registers
      p2d_fval[1] <= p2d_fval[0]; p2d_fval[0] <= fval; 
      p2d_val[1] <= p2d_val[0]; p2d_val[0] <= !xb2pixel_empty;
    
      case(dramifc_state)
        DRAMIFC_ERROR: begin
        end
        DRAMIFC_MSG_WAIT: begin
          if(!xb2dram_empty) begin
            tmp_data[tmp_data_offset+:XB_SIZE] <= dram_msg;
            // Is this the last of the tmp_data I was waiting for?
            if(tmp_data_offset == (2*APP_DATA_WIDTH - XB_SIZE)) begin
              app_en <= `TRUE;
              end_addr <= end_addr + ADDR_INC;
              dramifc_state <= DRAMIFC_WR_WAIT;
            end
            tmp_data_offset <= tmp_data_offset + XB_SIZE;
          end
        end
        DRAMIFC_WR_WAIT:
          if(app_rdy && app_wdf_rdy) begin
            app_addr <= app_addr + ADDR_INC; // for next write
            app_en <= `FALSE;
            app_wdf_data <= tmp_data[0+:APP_DATA_WIDTH];
            app_wdf_wren <= `TRUE;
            app_wdf_end <= `FALSE;
            dramifc_state <= DRAMIFC_WR1;
          end
        DRAMIFC_WR1:
          if(app_wdf_rdy) begin
            app_wdf_end <= `TRUE;
            app_wdf_data <= tmp_data[APP_DATA_WIDTH+:APP_DATA_WIDTH];
            dramifc_state <= DRAMIFC_WR2;
          end
        DRAMIFC_WR2: begin
          app_en <= `FALSE;
          app_wdf_wren <= `FALSE;
          tmp_data_offset <= 0;//APP_DATA_WIDTH - XB_SIZE;
          // Does the data I am writing mark the end of the coefficients?
          if(dram_msg[1:0] == 2'b01) begin
            app_addr <= START_ADDR;
            dram_read <= `TRUE;
            app_en <= `TRUE;
            dramifc_state <= DRAMIFC_READING;
          end else
            dramifc_state <= app_wdf_rdy ? DRAMIFC_MSG_WAIT : DRAMIFC_ERROR;
        end
        DRAMIFC_READING: begin
          if(patch_coeff_fifo_overflow || row_coeff_fifo_overflow) begin
            //invariance assertion
            app_en <= `FALSE;
            dramifc_state <= DRAMIFC_ERROR;
          end else begin
            if(app_rdy) app_addr <= app_addr + ADDR_INC;
            if(app_addr == end_addr) begin
              app_en <= `FALSE;
              dramifc_state <= DRAMIFC_INTERFRAME;
            end else if(patch_coeff_fifo_high || row_coeff_fifo_high) begin
              app_en <= `FALSE;//Note: the address is already incremented
              dramifc_state <= DRAMIFC_THROTTLED;
            end
          end
        end
        DRAMIFC_THROTTLED:
          if(app_rd_data_valid &&
             (patch_coeff_fifo_overflow || row_coeff_fifo_overflow)) begin
            //invariance assertion
            dramifc_state <= DRAMIFC_ERROR;
          end else if(!patch_coeff_fifo_high && !row_coeff_fifo_high) begin
            app_en <= `TRUE;
            dramifc_state <= DRAMIFC_READING;
          end
        DRAMIFC_INTERFRAME:
          if(p2d_val[1] && !p2d_fval[1]) begin //Get ready for the next frame
            app_addr <= START_ADDR;
            app_en <= `TRUE;
            dramifc_state <= DRAMIFC_READING;
          end
      endcase
    end

endmodule
