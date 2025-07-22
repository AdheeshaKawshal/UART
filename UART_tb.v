`timescale 1ns/1ns

module UART_tb;

  // Testbench signals
  reg clk;
  reg tx_ctr;
  reg rst;
  reg Rx;           // Simulated receive line
  wire Tx;          // Output from UART transmitter
  wire [7:0] data;  // Received data
  wire [7:0] tx_data;

  // Instantiate the DUT
  UART_Module uut (
    .clk(clk),
    .tx_ctr(tx_ctr),
    .rst(rst),
    .Rx(Tx),
    .Tx(Tx),
    .data(data),
    .tx_data(tx_data)
  );

  // Clock generation: 10ns period => 100MHz
  always #1 clk = ~clk;

  // Simulated RX input (not used unless you're testing loopback)
  initial Rx = 1;

  initial begin
    // Initialize inputs
    clk     = 0;
    rst     = 0;
    tx_ctr  = 0;

    // Reset pulse
    #5;
    rst = 1;

    // Wait and trigger tx_ctr to start transmission
    #2;
    tx_ctr = 1;
    #10;
    tx_ctr = 0;

    // Wait for several frames to be transmitted
    #500;

    // Second transmission trigger (optional)
    tx_ctr = 1;
    #10;
    tx_ctr = 0;

    #500;

  end

endmodule
