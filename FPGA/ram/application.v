module application#(parameter ADDR_WIDTH=1, APP_DATA_WIDTH=1)
(input reset, clk, output reg error
, input app_rdy, output reg app_en, output[2:0] app_cmd
, output reg[ADDR_WIDTH-1:0] app_addr
, input app_wdf_rdy, output reg app_wdf_wren, app_wdf_end
, output reg[APP_DATA_WIDTH-1:0] app_wdf_data
, input app_rd_data_valid, input[APP_DATA_WIDTH-1:0] app_rd_data
);
`include "function.v"
  localparam WR_WAIT = 0, WR1 = 1, WR2 = 2, RD = 3, NUM_STATE = 4;
  localparam END_ADDR = 27'h0000000;
  reg[log2(NUM_STATE)-1:0] state;
  //reg[APP_DATA_WIDTH-1:0] data_read;
  reg bwrite;
  
  assign app_cmd = {2'b00, bwrite};

  always @(posedge clk)
    if(reset) begin
      error = `FALSE;
		app_addr <= 0;
      bwrite <= `TRUE;
      app_en <= `TRUE;
      app_wdf_data <= 0;
      app_wdf_wren <= `FALSE;
      app_wdf_end <= `FALSE;
      state <= WR_WAIT;
    end else begin
	   app_wdf_data <= app_wdf_data + `TRUE;

      case(state)
        WR_WAIT: begin
          if(app_rdy && app_wdf_rdy) begin
            app_en <= `FALSE;
            app_wdf_wren <= `TRUE; // Write the first half of the burst
            app_wdf_end <= `FALSE;
            state <= WR1;
          end
        end
        WR1: begin
			app_wdf_end <= `TRUE;
			state <= WR2;
        end
        WR2: begin
			 app_wdf_wren <= `FALSE;
			 app_wdf_end <= `FALSE;
			 if(app_addr == END_ADDR) begin
			   app_addr <= 0;
				bwrite <= `FALSE;
				app_en <= `TRUE;
			   state <= RD;
			 end else begin
			   app_addr <= app_addr + 'h40;
				bwrite <= `TRUE;
				app_en <= `TRUE;
				state <= WR_WAIT;
			end
        end
        RD: begin
          if(app_rdy) begin
				 if(app_addr == END_ADDR) begin
					app_addr <= 0;
					bwrite <= `TRUE;
					app_en <= `TRUE;
					state <= WR_WAIT;
				 end else begin
					app_addr <= app_addr + 'h40;
					app_en <= `TRUE;
					state <= RD;
				end
          end
        end
        default: begin
          app_en <= `TRUE;
          bwrite = `FALSE;
          app_wdf_wren <= `FALSE;
          error = `FALSE;
        end
      endcase
    end
endmodule
