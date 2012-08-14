module application#(parameter ADDR_WIDTH=1, APP_DATA_WIDTH=1)
(input reset, clk, output reg error
, input app_rdy, output reg app_en, output[2:0] app_cmd
, output reg[ADDR_WIDTH-1:0] app_addr
, input app_wdf_rdy, output reg app_wdf_wren, output app_wdf_end
, output reg[APP_DATA_WIDTH-1:0] app_wdf_data
, input app_rd_data_valid, input[APP_DATA_WIDTH-1:0] app_rd_data
);
`include "function.v"
  localparam WR_WAIT = 0, WR = 1, RD = 2, ERROR = 3
    , NUM_STATE = 4;
  localparam START_ADDR = 27'h0001ff0, END_ADDR = 27'h0002010//0001fc0
    , ADDR_INC = 7'h8; // Front and back of BL8 burst skips by 0x8
  reg[log2(NUM_STATE)-1:0] state;
  reg bread;
  reg[APP_DATA_WIDTH-1:0] expected_data;
  
  assign app_cmd = {2'b00, bread};
  assign app_wdf_end = `TRUE;

  always @(posedge clk)
    if(reset) begin
      expected_data <= 1;
      error <= `FALSE;
  		app_addr <= START_ADDR;
      app_en <= `TRUE;
      bread <= `FALSE;
      app_wdf_wren <= `FALSE;
      app_wdf_data <= 0;
      state <= WR_WAIT;
    end else begin
      if(app_rd_data_valid) begin
        if(app_rd_data != expected_data) begin
          error <= `TRUE;
          state <= ERROR;
        end
        expected_data <= expected_data + `TRUE;
      end
      
      case(state)
        WR_WAIT: begin
          if(app_rdy && app_wdf_rdy) begin
            app_en <= `FALSE;
            app_wdf_wren <= `TRUE;
            state <= WR;
            app_wdf_data <= app_wdf_data + `TRUE;
          end
        end
        WR: begin
   			  app_wdf_wren <= `FALSE;
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
          bread <= `FALSE;
          app_wdf_wren <= `FALSE;
          error <= `TRUE;
        end
      endcase
    end
endmodule
