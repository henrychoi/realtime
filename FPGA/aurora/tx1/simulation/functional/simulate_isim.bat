REM!\bin\sh
REM Remove existing work directory
echo "Removing existing work directory"
rm -rf work
REM Create "work" directory
mkdir work
REM Compile glbl module, used to simulate global powerup features of the FPGA
vlogcomp -work work %XILINX%\verilog\src\glbl.v
REM Compile testbench source
vlogcomp -work work ..\demo_tb.v
REM To simulate an tx1_example_design module you need an rx1_example_design module
REM Generate the appropriate aurora rx module and set the SIMPLEX_PARTNER
REM environment variable to point to it's directory

REM Compile the HDL for the Device Under Test
REM Aurora Lane Modules
set SIMPLEX_PARTNER=rx1
vlogcomp -work work ..\..\..\%SIMPLEX_PARTNER%\src\rx1_sym_dec.v
vlogcomp -work work ..\..\..\%SIMPLEX_PARTNER%\src\rx1_rx_err_detect_simplex.v
vlogcomp -work work ..\..\..\%SIMPLEX_PARTNER%\src\rx1_rx_lane_init_sm_simplex.v
vlogcomp -work work ..\..\..\%SIMPLEX_PARTNER%\src\rx1_rx_aurora_lane_simplex.v
vlogcomp -work work ..\..\src\tx1_sym_gen.v
vlogcomp -work work ..\..\src\tx1_tx_err_detect_simplex.v
vlogcomp -work work ..\..\src\tx1_tx_lane_init_sm_simplex.v
vlogcomp -work work ..\..\src\tx1_tx_aurora_lane_simplex.v
REM Aurora Lane Modules

REM Global Logic Modules
vlogcomp -work work ..\..\..\%SIMPLEX_PARTNER%\src\rx1_rx_channel_err_detect_simplex.v
vlogcomp -work work ..\..\..\%SIMPLEX_PARTNER%\src\rx1_rx_channel_init_sm_simplex.v
vlogcomp -work work ..\..\..\%SIMPLEX_PARTNER%\src\rx1_rx_global_logic_simplex.v
vlogcomp -work work ..\..\src\tx1_tx_ch_bond_code_gen_simplex.v
vlogcomp -work work ..\..\src\tx1_tx_channel_err_detect_simplex.v
vlogcomp -work work ..\..\src\tx1_tx_channel_init_sm_simplex.v
vlogcomp -work work ..\..\src\tx1_tx_global_logic_simplex.v
REM TX Streaming User Interface modules
vlogcomp -work work ..\..\src\tx1_tx_stream_datapath_simplex.v
vlogcomp -work work ..\..\src\tx1_tx_stream_control_sm_simplex.v
vlogcomp -work work ..\..\src\tx1_tx_stream_simplex.v
vlogcomp -work work ..\..\..\%SIMPLEX_PARTNER%\src\rx1_rx_stream_datapath_simplex.v
vlogcomp -work work ..\..\..\%SIMPLEX_PARTNER%\src\rx1_rx_stream_simplex.v


vlogcomp -work work ..\..\example_design\cc_manager\tx1_standard_cc_module.v
vlogcomp -work work ..\..\example_design\clock_module\tx1_clock_module.v
vlogcomp -work work ..\..\example_design\gt\tx1_gtx.v
vlogcomp -work work ..\..\example_design\tx1_reset_logic.v
vlogcomp -work work ..\..\example_design\gt\tx1_wrapper.v
vlogcomp -work work ..\..\src\tx1_aurora_to_gtx.v
vlogcomp -work work ..\..\src\tx1_64b66b_scrambler.v
vlogcomp -work work ..\..\example_design\tx1_block.v

vlogcomp -work work ..\..\..\%SIMPLEX_PARTNER%\example_design\rx1_block.v
vlogcomp -work work ..\..\..\%SIMPLEX_PARTNER%\example_design\rx1_example_design.v
vlogcomp -work work ..\..\..\%SIMPLEX_PARTNER%\example_design\rx1_reset_logic.v
vlogcomp -work work ..\..\example_design\tx1_example_design.v
vlogcomp -work work ..\..\example_design\traffic_gen_and_check\tx1_frame_gen.v
vlogcomp -work work ..\..\..\%SIMPLEX_PARTNER%\example_design\rx1_example_design.v
vlogcomp -work work ..\..\..\%SIMPLEX_PARTNER%\example_design\traffic_gen_and_check\rx1_frame_check.v
vlogcomp -work work ..\..\..\%SIMPLEX_PARTNER%\example_design\gt\rx1_gtx.v
vlogcomp -work work ..\..\..\%SIMPLEX_PARTNER%\example_design\gt\rx1_wrapper.v

vlogcomp -work work ..\..\..\%SIMPLEX_PARTNER%\src\rx1_gtx_to_aurora.v
vlogcomp -work work ..\..\..\%SIMPLEX_PARTNER%\src\rx1_64b66b_descrambler.v
vlogcomp -work work ..\..\..\%SIMPLEX_PARTNER%\src\rx1_block_sync_sm.v
vlogcomp -work work ..\..\..\%SIMPLEX_PARTNER%\src\rx1_cbcc_gtx_6466.v

REM Begin the test
fuse -top DEMO_TB -top glbl -lib gtx_dual_ver -lib unisims_ver -initfile %XILINX%\vhdl\hdp\lin\xilinxsim.ini -o demo_tb.exe

.\demo_tb.exe -tclbatch wave_isim.tcl 
