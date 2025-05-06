`timescale 1ns / 1ps
`include "comm.v"
module tx_testbench;

// Testbench parameters
parameter CLK_FREQ = 50000000; // 50 MHz
parameter BAUD_RATE = 9600;
parameter CLK_PERIOD = 20; // 20 ns period for 50 MHz clock
parameter CLKS_PER_BIT = 16; // As defined in UART_tx2 for simulation

// Testbench signals
reg clk;
reg btn;
reg Rx;
wire Tx;
wire [7:0] data;

// Instantiate the TX module
TX #(
  .CLK_FREQ(CLK_FREQ),
  .BAUD_RATE(BAUD_RATE)
) tx(
  .clk(clk),
  .btn(btn),
  .Rx(Tx),
  .Tx(Tx),
  .data(data)
);
// Clock generation (50 MHz)
initial begin
  clk = 0;
  forever #(CLK_PERIOD/2) clk = ~clk;
end

// Test procedure
initial begin
  // Initialize signals
  btn = 0;
  Rx = 1; // Idle state for UART (high)

  // Loopback connection
    $dumpfile("commtb.vcd");
    $dumpvars(0, tx_testbench);
  // Test 1: Wait for TX to send data and verify Tx output


  // Check received data (should be 8'hA5)
  if (data == 8'hA5)
    $display("Test Passed: Received data = %h", data);
  else
    $display("Test Failed: Received data = %h, Expected = A5", data);

  // End simulation
  #100000;



  $finish;
end

// Monitor signals for debugging
initial begin
  $monitor("Time=%0t clk=%b Rx=%b Tx=%b data=%h", $time, clk, Rx, Tx, data);
end

endmodule

