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
//, input clk_85
);
`include "function.v"
  integer i;
  localparam HEARTBEAT_CTR_SIZE = 8;
  reg[HEARTBEAT_CTR_SIZE-1:0] heartbeat_ctr;
  localparam PIXEL_ERROR = 0, PIXEL_STANDBY = 1, PIXEL_INTRALINE = 2
    , PIXEL_INTERLINE = 3, PIXEL_INTERFRAME = 4, N_PIXEL_STATE = 5;
  reg[log2(N_PIXEL_STATE)-1:0] pixel_state;
  reg[3:0] n_pc_dram_msg;// = 2 * 256/32
  
  reg pc_msg_is_dn_d, pc_msg_pending_d;
  wire[XB_SIZE-1:0] pixel_msg, dram_msg;
  reg[XB_SIZE-1:0] pc_msg_d;
  wire xb2pixel_full, xb2dram_full, xb2pixel_empty, xb2dram_empty;

  localparam N_FRAME_SIZE = 20
    , N_COL_MAX = 2048, N_ROW_MAX = 2064 //2k rows + 8 dark pixels top and btm
    , N_FSUB_LATENCY = 8;
  reg[N_FRAME_SIZE-1:0] cl_n_frame;
  reg[log2(N_ROW_MAX)-1:0] cl_n_row, cl_n_row_d[N_FSUB_LATENCY-1:0];
  reg[log2(N_COL_MAX)-1:0] cl_n_col, cl_n_col_d[N_FSUB_LATENCY-1:0];
  
  localparam DN_SIZE = 12, N_DN2F_LATENCY = 6;
  wire fval, lval, dark_sub_valid;
  reg[N_DN2F_LATENCY+N_FSUB_LATENCY-1:0] fval_d, lval_d;
  wire[DN_SIZE-1:0] dn;
  wire[FP_SIZE-1:0] fdn, dark, fdark_subtracted;
  wire[3:0] dark_lsb;

  wire[APP_DATA_WIDTH-1:0] dram_data;

  wire pixel_coeff_fifo_overflow, pixel_coeff_fifo_high, pixel_coeff_fifo_empty;
  //reg pixel_coeff_fifo_ack;
  //reg dram_rd_fifo_ack;
  //localparam COEFFRD_BELOW_LOW = 0, COEFFRD_ABOVE_HIGH = 1, COEFFRD_FULL = 2
  //  , COEFFRD_N_STATE = 3;
  //reg[log2(COEFFRD_N_STATE)-1:0] coeffrd_state;
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
  
  assign heartbeat = heartbeat_ctr[HEARTBEAT_CTR_SIZE-1];
  assign pc_msg_ack = !(pc_msg_empty || xb2pixel_full || xb2dram_full);  
  assign {fval, lval} = pixel_msg[4+:2];
  assign dn = pixel_msg[8+:DN_SIZE];//Note: throw away the 4 MSB
  assign error = pixel_state == PIXEL_ERROR
    || dramifc_state == DRAMIFC_ERROR
    || pixel_coeff_fifo_overflow;

  xb2pixel xb2pixel(.wr_clk(bus_clk), .rd_clk(pixel_clk)//, .rst(rst)
    , .din(pc_msg_d), .wr_en(!xb2pixel_full && pc_msg_pending_d && pc_msg_is_dn_d)
    , .rd_en(`TRUE), .dout(pixel_msg)
    , .prog_full(xb2pixel_full), .full(), .empty(xb2pixel_empty));

  xb2dram xb2dram(.wr_clk(bus_clk), .rd_clk(dram_clk)//, .rst(rst)
    , .din(pc_msg_d), .wr_en(!xb2dram_full && pc_msg_pending_d && !pc_msg_is_dn_d)
    , .rd_en(!(dramifc_state == DRAMIFC_WR1
               || dramifc_state == DRAMIFC_WR2
               || dramifc_state == DRAMIFC_WR_WAIT))
    , .dout(dram_msg)
    , .prog_full(xb2dram_full), .full(), .empty(xb2dram_empty));

  pixel_coeff_fifo pixel_coeff_fifo(.wr_clk(dram_clk), .rd_clk(dram_clk)
    , .din(app_rd_data[64+:(8 * (FP_SIZE + 4))])
    , .wr_en(//Note: always write into FIFO when there is valid DRAM data
             app_rd_data_valid)//flow control done upstream by DRAMIfc
    // Note that I have to delay the ACK by N_DN2F_LATENCY to sync the output
    // of DN2f with the stream of dark values
    , .rd_en(lval_d[N_DN2F_LATENCY-1])//Keep reading from FIFO coeff when LVAL_d
    , .dout({dark, dark_lsb /* just a bitbucket */})
    , .prog_full(pixel_coeff_fifo_high), .full()
    , .overflow(pixel_coeff_fifo_overflow), .empty(pixel_coeff_fifo_empty));

  DN2f dn2f(.clk(pixel_clk), .a(dn), .result(fdn));
  fsub fsub(.clk(pixel_clk)
    , .a(fdn), .b(dark), .operation_nd(lval_d[N_DN2F_LATENCY-1])
    , .rdy(dark_sub_valid), .result(fdark_subtracted));

  always @(posedge reset, posedge dark_sub_valid)
    if(reset) heartbeat_ctr <= 0;
    else heartbeat_ctr <= heartbeat_ctr + `TRUE;

  always @(posedge bus_clk)
    if(reset) begin
      n_pc_dram_msg <= 0;
      pc_msg_pending_d <= `FALSE;
    end else begin
      pc_msg_pending_d <= ~pc_msg_empty;
      pc_msg_is_dn_d <= ~pc_msg[0] && n_pc_dram_msg == 0;
      if(pc_msg_ack) begin
        pc_msg_d <= pc_msg;// delay this to match up against pc_msg_is_dn_d
        if(n_pc_dram_msg || pc_msg[0]) n_pc_dram_msg <= n_pc_dram_msg + `TRUE;
      end
    end

  always @(posedge pixel_clk) begin
    if(reset) begin
      pixel_state <= PIXEL_STANDBY;      
    end else begin
      fval_d[0] <= pc_msg_is_dn_d && fval;
      lval_d[0] <= pc_msg_is_dn_d && lval;
      for(i=1; i < (N_DN2F_LATENCY + N_FSUB_LATENCY); i=i+1) begin
        fval_d[i] <= fval_d[i-1];
        lval_d[i] <= lval_d[i-1];
      end

      cl_n_col_d[0] <= cl_n_col;
      cl_n_row_d[0] <= cl_n_row;
      for(i=1; i < N_FSUB_LATENCY; i=i+1) begin
        cl_n_col_d[i] <= cl_n_col_d[i-1];
        cl_n_row_d[i] <= cl_n_row_d[i-1];
      end

      case(pixel_state)
        PIXEL_ERROR: begin
        end
        PIXEL_STANDBY:
          if(fval_d[N_DN2F_LATENCY-1]) begin
            cl_n_row <= 0;
            cl_n_col <= 0;
            cl_n_frame <= 0;
            pixel_state <= PIXEL_INTRALINE;
          end
        PIXEL_INTRALINE:
          if(pixel_coeff_fifo_empty) pixel_state <= PIXEL_ERROR;
          else
            if(lval_d[N_DN2F_LATENCY-1]) cl_n_col <= cl_n_col + `TRUE;
            else
              if(fval_d[N_DN2F_LATENCY-1]) begin
                cl_n_row <= cl_n_row + 1'b1;
                pixel_state <= PIXEL_INTERLINE;
              end else begin
                cl_n_frame <= cl_n_frame + 1'b1;
                pixel_state <= PIXEL_INTERFRAME;
              end
        PIXEL_INTERLINE:
          if(lval_d[N_DN2F_LATENCY-1]) begin
            cl_n_col <= 0;
            pixel_state <= PIXEL_INTRALINE;
          end
        PIXEL_INTERFRAME:
          if(lval_d[N_DN2F_LATENCY-1]) begin
            cl_n_row <= 0;
            cl_n_col <= 0;
            pixel_state <= PIXEL_INTRALINE;
          end
      endcase
    end //!reset
  end //always @posedge(pixel_clk)
    
  always @(posedge dram_clk)
    if(reset) begin
  		app_addr <= START_ADDR;
      end_addr <= START_ADDR + ADDR_INC;
      app_en <= `FALSE;
      dram_read <= `FALSE;
      app_wdf_wren <= `FALSE;
      app_wdf_end <= `TRUE;
      tmp_data_offset <= 0; //APP_DATA_WIDTH - XB_SIZE;
      dramifc_state <= DRAMIFC_MSG_WAIT;
      
      fpga_msg_valid <= `FALSE;
      fpga_msg <= 0;
    end else begin // normal operation
      case(dramifc_state)
        DRAMIFC_ERROR: begin
        end
        DRAMIFC_MSG_WAIT: begin
          //$display("%d ps, pending = %d, offset = %x, ack = %d"
          //  , $time, pc_msg_pending_d, tmp_data_offset, pc_msg_ack);
          if(!xb2dram_empty) begin
            tmp_data[tmp_data_offset+:XB_SIZE] <= dram_msg;
            // Is this the beginning of the pixel data?
            if(dram_msg[1]// The E bit indicates the end of coeff
              && tmp_data_offset == 0) begin 
              app_addr <= START_ADDR;
              dram_read <= `TRUE;
              app_en <= `TRUE;
              dramifc_state <= DRAMIFC_READING;
            end else begin
              // Is this the last of the tmp_data I was waiting for?
              if(tmp_data_offset == (2*APP_DATA_WIDTH - XB_SIZE)) begin
                app_en <= `TRUE;
                end_addr <= end_addr + ADDR_INC;
                dramifc_state <= DRAMIFC_WR_WAIT;
              end
              tmp_data_offset <= tmp_data_offset + XB_SIZE;
            end
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
          dramifc_state <= app_wdf_rdy ? DRAMIFC_MSG_WAIT : DRAMIFC_ERROR;
        end
        DRAMIFC_READING: begin
          if(pixel_coeff_fifo_overflow) begin //invariance assertion
            app_en <= `FALSE;
            dramifc_state <= DRAMIFC_ERROR;
          end else begin
            if(app_rd_data_valid) app_addr <= app_addr + ADDR_INC;
            if(app_addr == end_addr) begin
              app_en <= `FALSE;
              dramifc_state <= DRAMIFC_INTERFRAME;
            end else if(pixel_coeff_fifo_high) begin
              app_en <= `FALSE;//Note: the address is already incremented
              dramifc_state <= DRAMIFC_THROTTLED;
            end
          end
        end
        DRAMIFC_THROTTLED:
          if(pixel_coeff_fifo_overflow && app_rd_data_valid) begin
            //invariance assertion
            dramifc_state <= DRAMIFC_ERROR;
          end else if(!pixel_coeff_fifo_high) begin
            app_en <= `TRUE;
            dramifc_state <= DRAMIFC_READING;
          end
        DRAMIFC_INTERFRAME:
          if(pixel_state == PIXEL_INTERFRAME) begin
            app_en <= `TRUE;
            dramifc_state <= DRAMIFC_READING;
          end
      endcase
    end

endmodule
