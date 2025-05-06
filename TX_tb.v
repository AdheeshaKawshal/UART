`timescale 10ns/1ns

module TX_tb();

  reg clk;
  reg rxrst;
  reg txrst;
  wire tx_line;
  wire [7:0]tx_data;
  wire [7:0] received_data;

  // Loopback wire (TX connected to RX)
  // Instantiate DUT
  TX uut (
    .clk(clk),
    .rxrst(rxrst),
	 .txrst(txrst),
    .Rx(tx_line),
    .Tx(tx_line),
	 .tx_data(tx_data),
    .rx_data(received_data)
  );

  // Clock generation (10 ns period => 100 MHz)
  initial begin
    clk = 0;
	 	rxrst =1;
	txrst =1;
	#10;
	rxrst =0;
	txrst =0;
	#2;
	rxrst =1;
	txrst =1;
    
  end
always begin 
 #1 clk = ~clk;
end 
  // Stimulus process
  initial begin

	

    // Wait to observe transmission
    #1000000;  // Enough delay to complete UART transmission
  end

endmodule
