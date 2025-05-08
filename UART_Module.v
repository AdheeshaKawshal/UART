
// Top-level UART module for serial communication
module UART_Module(
  input        clk,
  input        tx_ctr,
  input        rst,
  input        Rx,       // Serial input (receive)
  output       Tx,       // D12 Serial output (transmit)
  output [7:0] data,      // Received data output
  output reg [7:0] tx_data
);
  // Internal signals        
  reg        clkn=0;         // Divided clock for TX/RX
  reg [7:0] fixed_data; // Fixed data to transmit
  reg [31:0] counter = 0;  // Clock divider counter
  reg [31:0] countbyte=0;
  reg [63:0] buff =64'hff; //   00010010 00110100 01010110 00010001
  wire stat;
  reg flg=1;

  // Clock divider to generate baud rate clock
  always @(posedge clk) begin
    counter <= counter + 1;
	 tx_data=fixed_data;
    if (counter == 162) begin // 325Incorrect: Should be CLKS_PER_BIT/2 (e.g., 5208/2)
      counter <= 1;
		countbyte<=countbyte+1;
      clkn <= ~clkn;
    end
	 if (stat&& flg) begin
		fixed_data<=buff[7:0];
		flg<=0;
	 end 
	 else if (~flg && ~stat) begin
		//buff<= {8'h00,buff[63:8]};
		flg<=1;
	 end
	 
	 end

  // Instantiate TX module EP4CE22F17C6
  UART_tx TX (
    .clk(clkn),
    .data(fixed_data),
    .data_out(Tx),
    .rst_n(rst),    // Hardcoded: Should be input   // Hardcoded: Should be controlled
    .status(stat),
	 .tx_ctr(tx_ctr)
  );

  // Instantiate RX module
  UART_rx RX (
    .clk(clkn),
    .data_in(Rx),
    .data_out(data),           // Unconnected
    .rst_n(rst)
	 
	 // Unconnected
  );

endmodule
//PIN_A11
//PIN_B13
//PIN_A13
//PIN_A15


