`timescale 1 ns / 1 ps

module EXAMPLE_TB;
//*************************Parameter Declarations**************************
  //125.0MHz GTX Reference clock 
  localparam CLOCKPERIOD_1 = 8.0, CLOCKPERIOD_2 = 8.0
     , LATENCY0 = 0, LATENCY1 = 0, LATENCY2 = 0;
  reg reference_clk_1_n_r, reference_clk_2_n_r, reset_i;
  wire reference_clk_1_p_r, reference_clk_2_p_r;         

  //GT Serial I/O
  wire[0:2] rxp_1_i, rxn_1_i, txp_1_i, txn_1_i
          , rxp_2_i, rxn_2_i, txp_2_i, txn_2_i;

  assign #LATENCY0  rxp_1_i[0]      =    txp_2_i[0];
  assign #LATENCY0  rxn_1_i[0]      =    txn_2_i[0];
  assign #LATENCY0  rxp_2_i[0]      =    txp_1_i[0];
  assign #LATENCY0  rxn_2_i[0]      =    txn_1_i[0];

  assign #LATENCY1  rxp_1_i[1]      =    txp_2_i[1];
  assign #LATENCY1  rxn_1_i[1]      =    txn_2_i[1];
  assign #LATENCY1  rxp_2_i[1]      =    txp_1_i[1];
  assign #LATENCY1  rxn_2_i[1]      =    txn_1_i[1];

  assign #LATENCY2  rxp_1_i[2]      =    txp_2_i[2];
  assign #LATENCY2  rxn_1_i[2]      =    txn_2_i[2];
  assign #LATENCY2  rxp_2_i[2]      =    txp_1_i[2];
  assign #LATENCY2  rxn_2_i[2]      =    txn_1_i[2];

`ifdef OLD
  reg gsr_r, gts_r;
  //__________________________Global Signals_____________________________    
  //Simultate the global reset that occurs after configuration at the beginning
  //of the simulation. Note that both GT smart models use the same global signals.
  assign glbl.GSR = gsr_r;
  assign glbl.GTS = gts_r;

  initial begin
    gts_r = 1'b0;        
    gsr_r = 1'b1;
    #(16*CLOCKPERIOD_1);
    gsr_r = 1'b0;
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
    reset_i = 1'b1;
    #200 reset_i = 1'b0;
  end

  main example_design_1_i(.sys_rst(reset_i)
    , .board_clk_p(reference_clk_1_p_r), .board_clk_n(reference_clk_1_n_r)
    , .GPIO_LED(GPIO_LED1)
    , .GTXQ0_P(reference_clk_1_p_r), .GTXQ0_N(reference_clk_1_n_r)
    , .RXP(rxp_1_i), .RXN(rxn_1_i), .TXP(txp_1_i), .TXN(txn_1_i)
  );

  main example_design_2_i(.sys_rst(reset_i)
    , .board_clk_p(reference_clk_2_p_r), .board_clk_n(reference_clk_2_n_r)
    , .GPIO_LED(GPIO_LED2)
    , .GTXQ0_P(reference_clk_2_p_r), .GTXQ0_N(reference_clk_2_n_r)
    , .RXP(rxp_2_i), .RXN(rxn_2_i), .TXP(txp_2_i), .TXN(txn_2_i)
  );
endmodule
