`timescale 1 ns / 1 ps

module EXAMPLE_TB;
`include "function.v"
  localparam N_LANE = 1;
  //125.0MHz GTX Reference clock 
  localparam CLOCKPERIOD_1 = 8.0, CLOCKPERIOD_2 = 8.0, LATENCY = 0;;
  reg reference_clk_1_n_r, reference_clk_2_n_r, reset_i;
  wire reference_clk_1_p_r, reference_clk_2_p_r;         

  //GT Serial I/O
  wire[0:N_LANE-1] rxp_1_i, rxn_1_i, txp_1_i, txn_1_i
          , rxp_2_i, rxn_2_i, txp_2_i, txn_2_i;

  genvar geni;
  generate
    for(geni=0; geni < N_LANE; geni=geni+1) begin: connect_tx_rx
      assign #LATENCY rxp_1_i[geni] = txp_2_i[geni];
      assign #LATENCY rxn_1_i[geni] = txn_2_i[geni];
      assign #LATENCY rxp_2_i[geni] = txp_1_i[geni];
      assign #LATENCY rxn_2_i[geni] = txn_1_i[geni];
    end
  endgenerate

`ifdef OLD
  reg gsr_r, gts_r;
  //__________________________Global Signals_____________________________    
  //Simultate the global reset that occurs after configuration at the beginning
  //of the simulation. Note that both GT smart models use the same global signals.
  assign glbl.GSR = gsr_r;
  assign glbl.GTS = gts_r;

  initial begin
    gts_r = `FALSE;
    gsr_r = `TRUE;
    #(16*CLOCKPERIOD_1);
    gsr_r = `FALSE;
  end
`endif

  //____________________________Clocks____________________________
  initial reference_clk_1_n_r = 1'b0;
  always #(CLOCKPERIOD_1/2) reference_clk_1_n_r = !reference_clk_1_n_r;
  assign reference_clk_1_p_r = !reference_clk_1_n_r;

  initial reference_clk_2_n_r = 1'b0;
  always #(CLOCKPERIOD_2/2) reference_clk_2_n_r = !reference_clk_2_n_r;
  assign reference_clk_2_p_r = !reference_clk_2_n_r;

  //____________________________Resets____________________________    
  initial begin
    reset_i = `FALSE;
    #10 reset_i = `TRUE;
    #40 reset_i = `FALSE;
  end

  wire[7:0] GPIO_LED1, GPIO_LED2;
  main#(.N_LANE(N_LANE)) example_design_1_i(.sys_rst(reset_i)
    , .board_clk_p(reference_clk_1_p_r), .board_clk_n(reference_clk_1_n_r)
    , .GPIO_LED(GPIO_LED1)
    , .GTXQ4_P(reference_clk_1_p_r), .GTXQ4_N(reference_clk_1_n_r)
    , .RXP(rxp_1_i), .RXN(rxn_1_i), .TXP(txp_1_i), .TXN(txn_1_i)
  );

  main#(.N_LANE(N_LANE)) example_design_2_i(.sys_rst(reset_i)
    , .board_clk_p(reference_clk_2_p_r), .board_clk_n(reference_clk_2_n_r)
    , .GPIO_LED(GPIO_LED2)
    , .GTXQ4_P(reference_clk_2_p_r), .GTXQ4_N(reference_clk_2_n_r)
    , .RXP(rxp_2_i), .RXN(rxn_2_i), .TXP(txp_2_i), .TXN(txn_2_i)
  );
endmodule
