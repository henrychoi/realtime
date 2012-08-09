module application#(parameter ADDR_WIDTH=1, APP_DATA_WIDTH=1)
(input reset, clk, output reg error
, input app_rdy, output reg app_en, output[2:0] app_cmd
, output reg[ADDR_WIDTH-1:0] app_addr
, input app_wdf_rdy, output reg app_wdf_wren, app_wdf_end
, output reg[APP_DATA_WIDTH-1:0] app_wdf_data
, input app_rd_data_valid, input[APP_DATA_WIDTH-1:0] app_rd_data
);
`include "function.v"
  localparam ERROR = 0, STARTUP = 1, WRFIFO_WAIT = 2, WR2 = 3, WR_WAIT = 4
    , JUST_WAIT = 5, RD_WAIT = 6, DATA_WAIT = 7, NUM_STATE = 8;
  localparam TEST_VAL = {{2{64'h0123456789ABCDEF}}, {2{64'hFEDCBA9876543210}}}
           , TEST_ADDR = 'h0000000;//{ADDR_WIDTH{1'b0}};
  reg[log2(NUM_STATE)-1:0] state;
  reg[APP_DATA_WIDTH-1:0] data_read;
  reg bwrite;
  reg[ADDR_WIDTH-1:0] addr;
  
  assign app_cmd = {2'b00, bwrite};

  always @(posedge clk)
    if(reset) begin
      error = `FALSE;
      data_read <= 0;
      addr <= 0;//app_addr <= TEST_ADDR;
      bwrite <= `FALSE;
      app_en <= `FALSE;
      app_wdf_data <= 0;//TEST_VAL;
      app_wdf_wren <= `FALSE;
      app_wdf_end <= `FALSE;
      state <= STARTUP;
    end else begin
      case(state)
        STARTUP: begin
          if(app_rdy) begin
            app_en <= `FALSE;
            app_wdf_wren <= `TRUE;
            app_wdf_end <= `FALSE;
            state <= WRFIFO_WAIT;
          end
        end
        WRFIFO_WAIT: begin
          if(app_wdf_rdy) begin
            addr <= addr + 'h40;
            app_wdf_data <= {{(256-APP_DATA_WIDTH){`FALSE}}, addr};
            app_addr <= addr;
            bwrite <= `TRUE;
            app_en <= `TRUE;
            app_wdf_end <= `TRUE;
            state <= WR2;
          end
        end
        WR2: begin
          if(app_rdy) app_en <= `FALSE;
          app_wdf_wren <= `FALSE;
          app_wdf_end <= `FALSE;
          state <= WR_WAIT;
        end
        WR_WAIT: begin
          if(app_rdy) begin
            if(addr == 0/*'h00003C0*/) begin
              app_en <= `TRUE;
              bwrite <= `FALSE;
              //state <= JUST_WAIT;//RD_WAIT;
              state <= RD_WAIT;
            end else begin
              app_en <= `FALSE;
              app_wdf_wren <= `TRUE;
              state <= WRFIFO_WAIT;
            end
          end
        end
        //JUST_WAIT: begin
        //  wait_timer <= wait_timer + 1'b1;
        //  if(wait_timer == 0) begin
        //    app_en = `TRUE;
        //    state <= RD_WAIT;
        //  end
        //end
        RD_WAIT: begin
          //app_en <= `TRUE;
          if(app_rdy) begin
            app_en <= `FALSE;
            state <= DATA_WAIT;
          end
        end
        DATA_WAIT: begin
          if(app_rd_data_valid) begin
            data_read <= app_rd_data;
            
            if(app_rd_data == TEST_VAL) begin
              bwrite <= `TRUE;
              app_wdf_wren <= `TRUE;
              state <= WR_WAIT;
            end else begin
              state <= ERROR;
            end
          end
        end
        default: begin
          app_en <= `FALSE;
          bwrite = `TRUE;
          app_wdf_wren <= `FALSE;
          error = `FALSE;
          state <= ERROR;
        end
      endcase
    end
endmodule
