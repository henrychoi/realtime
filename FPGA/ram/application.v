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
  localparam START_ADDR = 27'h0000000, END_ADDR = 27'h0000000//0001fc0
    , ADDR_INC = 7'h40;
  reg[log2(NUM_STATE)-1:0] state;
  reg bread;
  reg[APP_DATA_WIDTH-1:0] expected_data;
  
  assign app_cmd = {2'b00, bread};

  always @(posedge clk)
    if(reset) begin
      expected_data <= 0;
      error = `FALSE;
  		app_addr <= START_ADDR;
      app_en <= `TRUE;
      bread <= `FALSE;
      app_wdf_wren <= `FALSE;
      app_wdf_end <= `FALSE;
      app_wdf_data <= 0;
      state <= WR_WAIT;
    end else begin
      case(state)
        WR_WAIT: begin
          if(app_rdy && app_wdf_rdy) begin
            app_en <= `FALSE;
            app_wdf_wren <= `TRUE;
            app_wdf_end <= `FALSE;
            state <= WR1;
            app_wdf_data <= app_wdf_data + `TRUE;
          end
        end
        WR1: begin
          if(app_wdf_rdy) begin
            app_wdf_end <= `TRUE;
            app_wdf_data <= app_wdf_data + `TRUE;
            state <= WR2;
          end
        end
        WR2: begin
   			  app_wdf_wren <= `FALSE;
		   	  app_wdf_end <= `FALSE;
			    if(app_addr == END_ADDR) begin
			      app_addr <= START_ADDR;
				    bread <= `TRUE;
				    app_en <= `TRUE;
			      state <= RD;
			    end else begin
			      app_addr <= app_addr + ADDR_INC;
				    bread <= `FALSE;
				    app_en <= `TRUE;
				    state <= WR_WAIT;
			    end
        end
        RD: begin
          if(app_rdy) begin
				    if(app_addr == END_ADDR) begin
					    app_addr <= START_ADDR;
              bread <= `FALSE;
              app_en <= `TRUE;
              state <= WR_WAIT;
            end else begin
              app_addr <= app_addr + ADDR_INC;
              app_en <= `TRUE;
              state <= RD;
            end
          end
        end
        default: begin
          app_en <= `FALSE;
          bread = `FALSE;
          app_wdf_wren <= `FALSE;
          error = `TRUE;
        end
      endcase
    end
endmodule
