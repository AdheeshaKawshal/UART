
// Top-level UART module for serial communication
module TX (
  input clk,
  input txrst,
  input rxrst,
  input   rst,// System clock
  input   Rx,       // Serial input (receive)
  output  Tx,       // D12 Serial output (transmit)
  output [7:0] data,      // Received data output
  output [1:0] test,
  output reg clkN
);
  // Internal signals
  wire       datal;        // TX to RX loopback connection
  wire [7:0] tx;           // Unused TX test output
  wire [7:0] rx;           // Unused RX test output
  wire       dtx;          // Unused TX debug signal
  reg        clkn=0;         // Divided clock for TX/RX
  reg [7:0] fixed_data=8'b00001000; // Fixed data to transmit
  reg [31:0] counter = 0;  // Clock divider counter
  reg [63:0] buff =64'h9876543210;//68656c6f68656c6f; //64'h987654321;//   00010010 00110100 01010110 00010001
  wire stat;
  reg flg=1;

  // Clock divider to generate baud rate clock
  always @(posedge clk) begin
    counter <= counter + 1;
	 
    if (counter == 152) begin //152 325Incorrect: Should be CLKS_PER_BIT/2 (e.g., 5208/2)
      counter <= 1;
      clkn <= ~clkn;
		clkN<=clkn;
		//Tx<= ~Tx;
    end
	 if (stat&& flg) begin
		fixed_data<=buff[7:0];
		flg<=0;
	 end 
	 else if (~flg && ~stat) begin
		buff<= {8'h00,buff[63:8]};
		flg<=1;
	 end
	 
	 end

  // Instantiate TX module
  UART_tx2 TX (
    .clk(clkn),
    .data(fixed_data),
    .data_out(Tx),
    .rst_n(txrst),    // Hardcoded: Should be input
    .start(1'b1),    // Hardcoded: Should be controlled
    .test(test),
    .status(stat)
  );

  // Instantiate RX module
  UART_rx2 RX (
    .clk(clkn),
    .data_in(Rx),
    .data_val(data),           // Unconnected
    .rst_n(rxrst)
	 // Unconnected
  );

endmodule

// UART transmitter module
module UART_tx2 (
  input        clk,       // Divided clock
  input        rst_n,     // Active-low reset
  input [7:0]  data,      // Data to transmit
  input        start,     // Start transmission signal
  output reg   data_out,  // Serial output
  output reg [1:0] test,  // Debug output (data buffer)
  output reg [1:0] dt,
	output reg status// Debug output (state)
);
  // State machine parameters
  parameter IDLE  = 2'b00, START = 2'b01, DATA = 2'b10, STOP = 2'b11;
  parameter CLKS_PER_BIT = 16; // Clock cycles per bit (for simulation)
  parameter CLKSidel = 16;//750000; //63000
  // Internal registers
  reg [7:0]  data_buff;     // Data buffer for transmission
  reg        curr_stat;     // Tracks start status
  reg [19:0] clk_counter=0;   // Counts clock cycles per bit
  reg [3:0]  flag=0;      // Bit counter (should use bit_counter)
  reg [1:0]  STATE=IDLE;  // State machine register
  reg [31:0] counter=0;   // Unused
  reg [3:0]  bit_counter=0; // Tracks transmitted bits      // Initialization flag (causes Error 10200)
  // State machine and transmission logic
  always @(posedge clk or negedge rst_n) begin // Should be @(posedge clk or negedge rst_n)
    if (!rst_n) begin
      // Initialize on first cycle (non-synthesizable; use rst_n)
      data_out <= 1;         // Idle high           // Clear test output
      data_buff <= data;     // Load data
      clk_counter <= 0;      // Reset counter               // Disable initialization   // Data buffer for transmission    // Tracks start status   // Counts clock cycles per bit
      flag = 0;      // Bit counter (should use bit_counter)
      STATE = IDLE;  // State machine register
      counter = 0;   // Unused
      bit_counter = 0;
	  test=STATE;
    end else begin
      case (STATE)
        IDLE: begin
          if (clk_counter < CLKSidel ) begin
            data_out <= 1;     // Stay idle
            data_buff <= data; // Reload data
				clk_counter <= clk_counter +1;
            STATE <= IDLE;
				test=STATE;
          end else begin
            STATE <= START;    // Begin transmission
				clk_counter <= 0;
				status<=0;
          end
        end
        START: begin
          if (clk_counter < CLKS_PER_BIT-1) begin
            data_out <= 0;     // Send start bit
            STATE <= START;
				data_buff <= data;
				test=STATE;
            clk_counter <= clk_counter + 1;
          end else begin
            clk_counter <= 0;
            STATE <= DATA;
            flag <= 0;         // Reset bit counter
          end
        end
        DATA: begin
          if (flag < 8) begin
            STATE <= DATA;
				test=STATE;
            if (clk_counter < CLKS_PER_BIT-1) begin
              data_out <= data_buff[0]; // Send LSB
              clk_counter <= clk_counter + 1;
            end else begin
              data_buff <= data_buff >> 1; // Shift right
              clk_counter <= 0;
              flag <= flag + 1;  // Increment bit counter
            end
          end else begin
            STATE <= STOP;     // Move to stop bit
            clk_counter <= 0;
          end
        end
        STOP: begin
          if (clk_counter < CLKS_PER_BIT-1) begin
            data_out <= 1;     // Send stop bit
            STATE <= STOP;
            clk_counter <= clk_counter + 1;
          end else begin
            data_out <= 1;     // Idle  // Debug signal
            STATE <= IDLE;
				status<=1;
            curr_stat <= 0;    // Reset start
          end
        end
        default: STATE <= IDLE;
      endcase
    end // Debug state output
  end

endmodule

// UART receiver module
module UART_rx2 #(
  parameter CLKS_PER_BIT = 16 // Clock cycles per bit (for simulation)
) (
  input        clk,       // Divided clock
  input        data_in,   // Serial input
  input    rst_n,  // Debug output (received data)
  output reg [7:0] data_val, // Received data
  output reg [1:0] st,    // Debug output (state)
  output reg   dt  ,
	input btn// Debug output (data bit)
);
  // State machine parameters
  parameter IDLE  = 2'b00, START = 2'b01, DATA = 2'b10, STOP = 2'b11;
  reg [7:0] data;
  // Internal registers
  reg [3:0]  count=0;         // Unused
  reg [15:0] clk_counter=0;   // Counts clock cycles per bit
  reg [3:0]  filtercount;   // Counts samples for oversampling
  reg [64:0] data_buffrx;   // Oversized buffer (use data_val instead)
  reg [1:0]  STATE = IDLE;  // State machine register
  reg [3:0]  bitcount=0;      // Tracks received bits
  reg        flag = 1;      // Start detection flag
  reg        statflag = 1;  // Initialization flag (non-synthesizable)

  // State machine and reception logic
  always @(posedge clk or negedge rst_n) begin // Should add rst_n
    if (~rst_n) begin
      // Initialize on first cycle (non-synthesizable; use rst_n)
      count <= 0;
      //data_val <= 8'h00;
      bitcount <= 0;
    end else begin
      case (STATE)
        IDLE: begin
          st <= STATE; // Debug state
          if (data_in==0) begin
            STATE <= START; // Detect start bit
				clk_counter<=0;
          end
        end
        START: begin
          st <= STATE;
			 clk_counter <= clk_counter + 1;
          if (data_in == 0 && clk_counter == CLKS_PER_BIT/2 -1) begin
            STATE <= DATA;
            bitcount <= 0;
				//data_val =8'h00;
				clk_counter<=0;
				data_val<=8'h00;
          end
        end
        DATA: begin
          clk_counter <= clk_counter + 1;
          if (data_in && clk_counter == CLKS_PER_BIT-1) begin
            data_val <= {1'b1, data_val[7:1]};
				clk_counter<=0;
				bitcount <= bitcount + 1;
          end
			 else if (data_in==0 && clk_counter == CLKS_PER_BIT-1)begin
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
          if (data_in && clk_counter == CLKS_PER_BIT-1) begin
					STATE <= IDLE;
			 end 
            clk_counter <= clk_counter + 1;
          end 
        default: STATE <= IDLE;
      endcase
    end
  end

endmodule