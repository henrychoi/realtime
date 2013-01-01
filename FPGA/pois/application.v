module application#(parameter DELAY=1)
(input CLK, RESET, output[7:0] GPIO_LED);
`include "function.v"  
  reg [31:0] frand;
  wire[31:0] rand;
  wire valid;
  wire[6:0] randint;
  wire[9:0] pois_rand;

  rand#(.DELAY(DELAY))
    tausworth(.CLK(CLK), .RESET(RESET)
            , .valid(valid), .error(error), .rand(rand));

  assign #DELAY GPIO_LED = {valid, pois_rand[6:0]};
  always @(posedge CLK) begin
    frand <= #DELAY {`FALSE//sign
                    , `FALSE, rand[23+:7]//exponent
                    , rand[0+:23]};//fraction
    //if(RESET) frand <= #DELAY 'h40000000;
    //else frand <= #DELAY frand + 'h1000;
  end
  
  // Cast to int, to decide what estimate to use
  //fint f2int(.a(frand), .operation_nd(valid), .clk(CLK), .result(randint)
  //         , .rdy(f2int_rdy));
  pois#(.DELAY(DELAY))
    pois(.CLK(CLK), .RESET(RESET), .VALID(valid), .LAMBDA(frand), .RAND(rand)
      , .RESULT(pois_rand));
endmodule
