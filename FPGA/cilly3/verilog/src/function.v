`ifndef function_v
`define function_v

function integer max(input integer a, input integer b);
  begin //The actual manipulation of data in the function has to be placed
        //between begin and end statements.
    max = a > b ? a : b;
  end
endfunction

function integer log2(input integer n);
  integer i;
  begin //Without this, will get "Declarations not allowed in unnamed block"
    log2 = 1;
    for(i = 0; 2**i < n; i = i+1) log2 = i + 1;
  end
endfunction

`endif//function_v