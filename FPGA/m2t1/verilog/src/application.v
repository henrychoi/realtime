module application#(parameter ADDR_WIDTH=1, APP_DATA_WIDTH=1)
(input reset, clk, output reg error, heartbeat, app_done
, input app_rdy, output reg app_en, output[2:0] app_cmd
, output reg[ADDR_WIDTH-1:0] app_addr
, input app_wdf_rdy, output reg app_wdf_wren
, output[APP_DATA_WIDTH-1:0] app_wdf_data
, input app_rd_data_valid, input[APP_DATA_WIDTH-1:0] app_rd_data
, input bus_clk
, input pc_msg_pending, output reg pc_msg_ack, input[31:0] pc_msg
, input fpga_msg_full, output reg fpga_msg_valid, output reg[63:0] fpga_msg
, input clk_85);
`include "function.v"
  localparam START_ADDR = 27'h000_0000, END_ADDR = 27'h3ff_fffc;
  localparam WR_WAIT = 1, WR = 2, RD = 3, ERROR = 0, NUM_STATE = 4;
  localparam ADDR_INC = 7'h4;// Front and back of BL8 burst skips by 0x8
  reg[log2(NUM_STATE)-1:0] state;
  reg bread;
  reg[/*APP_DATA_WIDTH-1*/31:0] expected_data, wr_data;
  
  assign app_cmd = {2'b00, bread};
  assign app_wdf_data = {{(APP_DATA_WIDTH-32){1'b0}}, wr_data};

  always @(posedge clk)
    if(reset) begin
      expected_data <= 1;
      error <= `FALSE;
      heartbeat <= `FALSE;
  		app_addr <= START_ADDR;
      app_en <= `TRUE;
      bread <= `FALSE;
      app_wdf_wren <= `FALSE;
      wr_data <= 0;
      state <= WR_WAIT;
      pc_msg_ack <= `FALSE;
      fpga_msg_valid <= `FALSE;
      fpga_msg <= 0;
    end else begin
      if(app_rd_data_valid) begin
        if(app_rd_data[31:0] != expected_data) begin
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
            wr_data <= wr_data + `TRUE;
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
              heartbeat <= ~heartbeat;
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
