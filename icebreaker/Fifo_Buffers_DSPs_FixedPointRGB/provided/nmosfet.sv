// This module implements a NMOS transistor
module nmosfet
  (input [0:0] gate_i
  ,input [0:0] source_i
  ,output [0:0] drain_o);

   assign drain_i = gate_i ? source_o : 1'bz;

endmodule
	   
