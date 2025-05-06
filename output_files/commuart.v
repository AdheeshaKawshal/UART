
// Top-level UART module for serial communication
module commuart #(
  parameter CLK_FREQ = 50000000, // System clock frequency (50 MHz)
  parameter BAUD_RATE = 9600     // Desired baud rate
) (
  input        clk,
	input btn,// System clock
  input        Rx,       // Serial input (receive)
  output       Tx,       // D12 Serial output (transmit)
  output [7:0] data      // Received data output
);
  // Internal signals
  wire       datal;        // TX to RX loopback connection
  wire [7:0] tx;           // Unused TX test output
  wire [7:0] rx;           // Unused RX test output
  wire       dtx;          // Unused TX debug signal
  reg        clkn;         // Divided clock for TX/RX
  reg [7:0] fixed_data=8'b00010000; // Fixed data to transmit
  wire [7:0] data2;        // Received data from RX
  reg [31:0] counter = 0;  // Clock divider counter
  reg [31:0] countbyte=0;
  reg [63:0] buff =64'h12345612;
  wire stat;
  reg flg=1;

  // Clock divider to generate baud rate clock
  always @(posedge clk) begin
    counter <= counter + 1;
    if (counter == 325000) begin // 325Incorrect: Should be CLKS_PER_BIT/2 (e.g., 5208/2)
      counter <= 1;
		countbyte<=countbyte+1;
      clkn <= ~clkn;
    end

	 
	 end

  // Instantiate TX module
  UART_tx TX (
    .clk(clkn),
    .data(fixed_data),
    .data_out(Tx),
    .baudrate(1'b1), // Unused
    .rst_n(1'b1),    // Hardcoded: Should be input
    .start(1'b1),    // Hardcoded: Should be controlled
    .test(tx),
    .status(stat)
  );

  // Instantiate RX module
  UART_rx RX (
    .clk(clkn),
    .data_in(Rx),
    .data_val(data),
    .test(rx),
    .st(),           // Unconnected
    .btn(btn)
	 // Unconnected
  );

endmodule

// UART transmitter module
module UART_tx (
  input        clk,       // Divided clock
  input        rst_n,     // Active-low reset
  input [7:0]  data,      // Data to transmit
  input        baudrate,  // Unused baud rate control
  input        start,     // Start transmission signal
  output reg   data_out,  // Serial output
  output reg [7:0] test,  // Debug output (data buffer)
  output reg [1:0] dt,
	output reg status// Debug output (state)
);
  // State machine parameters
  parameter IDLE  = 2'b00, START = 2'b01, DATA = 2'b10, STOP = 2'b11;
  parameter CLKS_PER_BIT = 16; // Clock cycles per bit (for simulation)
  parameter CLKSidel = 200;
  // Internal registers
  reg [7:0]  data_buff=0;     // Data buffer for transmission
  reg        curr_stat;     // Tracks start status
  reg [15:0] clk_counter;   // Counts clock cycles per bit
  reg [3:0]  flag = 0;      // Bit counter (should use bit_counter)
  reg [1:0]  STATE = IDLE;  // State machine register
  reg [31:0] counter = 0;   // Unused
  reg [3:0]  bit_counter = 0; // Tracks transmitted bits
  reg        stat = 1;      // Initialization flag (causes Error 10200)
	reg [63:0] buff=64'h12345612;
  // State machine and transmission logic
  always @(posedge clk) begin // Should be @(posedge clk or negedge rst_n)
    if (stat) begin
      // Initialize on first cycle (non-synthesizable; use rst_n)
      data_out <= 1;         // Idle high
      test <= 0;             // Clear test output
      data_buff <= data;     // Load data
      clk_counter <= 0;      // Reset counter
      curr_stat <= start;    // Track start
      stat <= 0;             // Disable initialization
    end else begin
      case (STATE)
        IDLE: begin
          if (~curr_stat && clk_counter < CLKSidel ) begin
            data_out <= 1;     // Stay idle
            test <= data_out;
            data_buff <= buff[7:0]; // Reload data
				clk_counter <= clk_counter +1;
				status<=1;
            STATE <= IDLE;
          end else begin
            STATE <= START;    // Begin transmission
            status<=0;
				clk_counter <= 0;
          end
        end
        START: begin
          if (clk_counter < CLKS_PER_BIT) begin
            data_out <= 0;     // Send start bit
            STATE <= START;
            test <= data_out;
				data_buff <= buff[7:0];
            clk_counter <= clk_counter + 1;
          end else begin
            test <= data_out;
            clk_counter <= 0;
            STATE <= DATA;
            flag <= 0;         // Reset bit counter
          end
        end
        DATA: begin
          if (flag < 8) begin
            STATE <= DATA;
            if (clk_counter < CLKS_PER_BIT) begin
              data_out <= data_buff[0]; // Send LSB
              test <= data_out;
              clk_counter <= clk_counter + 1;
            end else begin
              data_buff <= data_buff >> 1; // Shift right
              clk_counter <= 0;
              flag <= flag + 1;  // Increment bit counter
            end
          end else begin
            STATE <= STOP;     // Move to stop bit
            clk_counter <= 0;
				buff<= {8'h00,buff[63:7]};
          end
        end
        STOP: begin
          if (clk_counter < CLKS_PER_BIT) begin
            data_out <= 1;     // Send stop bit
            STATE <= STOP;
            test <= data_out;
            clk_counter <= clk_counter + 1;
          end else begin
            data_out <= 1;     // Idle
            test <= 8'h01;     // Debug signal
            STATE <= IDLE;
				status<=1;
            curr_stat <= 1;    // Reset start
          end
        end
        default: STATE <= IDLE;
      endcase
    end
    dt <= STATE; // Debug state output
  end

endmodule

// UART receiver module
module UART_rx #(
  parameter CLKS_PER_BIT = 16 // Clock cycles per bit (for simulation)
) (
  input        clk,       // Divided clock
  input        data_in,   // Serial input
  output reg [7:0] test,  // Debug output (received data)
  output reg [7:0] data_val, // Received data
  output reg [1:0] st,    // Debug output (state)
  output reg   dt  ,
	input btn// Debug output (data bit)
);
  // State machine parameters
  parameter IDLE  = 2'b00, START = 2'b01, DATA = 2'b10, STOP = 2'b11;
  reg [7:0] data;
  // Internal registers
  reg [3:0]  count;         // Unused
  reg [15:0] clk_counter;   // Counts clock cycles per bit
  reg [3:0]  filtercount;   // Counts samples for oversampling
  reg [64:0] data_buffrx;   // Oversized buffer (use data_val instead)
  reg [1:0]  STATE = IDLE;  // State machine register
  reg [3:0]  bitcount;      // Tracks received bits
  reg        flag = 1;      // Start detection flag
  reg        statflag = 1;  // Initialization flag (non-synthesizable)

  // State machine and reception logic
  always @(posedge clk) begin // Should add rst_n
    if (statflag) begin
      // Initialize on first cycle (non-synthesizable; use rst_n)
      count <= 0;
      data_val <= 8'h00;
      bitcount <= 0;
      flag <= 0;
      dt <= 0;
      filtercount <= 0;
      test <= 0;
      statflag <= 0;
    end else begin
      case (STATE)
        IDLE: begin
          st <= STATE; // Debug state
          if (data_in==0) begin
            STATE <= START; // Detect start bit
          end
        end
        START: begin
          st <= STATE;
			 clk_counter <= clk_counter + 1;
          if (data_in == 0 && clk_counter == CLKS_PER_BIT/2 -1) begin
            STATE <= DATA;
            bitcount <= 0;
				data_val =8'h00;
				clk_counter<=0;
          end
        end
        DATA: begin
          clk_counter <= clk_counter + 1;
          if (data_in && clk_counter == CLKS_PER_BIT) begin
            data_val <= {1'b1, data_val[7:1]};
				clk_counter<=0;
				bitcount <= bitcount + 1;
          end
			 else if (data_in==0 && clk_counter == CLKS_PER_BIT)begin
				data_val <= {1'b0, data_val[7:1]};
				clk_counter<=0;
				bitcount <= bitcount + 1;
          end
          if (bitcount > 7) begin
				data<=data_val;
            STATE <= STOP;
            clk_counter <= 0;
          end
			 
        end
        STOP: begin
          st <= STATE;
          if (data_in && clk_counter == CLKS_PER_BIT) begin
					STATE <= IDLE;
			 end 
            clk_counter <= clk_counter + 1;
          end 
        default: STATE <= IDLE;
      endcase
    end
  end

endmodule