
// Top-level UART module for serial communication
module TX(
  input        clk,
  input        txrst,
  input        rxrst,
  input        Rx,       // Serial input (receive)
  output       Tx,       // D12 Serial output (transmit)
  output [7:0] data,      // Received data output
  output reg [7:0] tx_data
);
  // Internal signals        // Unused TX debug signal
  reg        clkn=0;         // Divided clock for TX/RX
  reg [7:0] fixed_data=8'b01001000; // Fixed data to transmit
  reg [31:0] counter = 0;  // Clock divider counter
  reg [31:0] countbyte=0;
  reg [63:0] buff =64'h987654321; //   00010010 00110100 01010110 00010001
  wire stat;
  reg flg=1;

  // Clock divider to generate baud rate clock
  always @(posedge clk) begin
    counter <= counter + 1;
	 tx_data=fixed_data;
    if (counter == 162) begin // 50MHz/(9600*16*2) = 162
      counter <= 1;
		countbyte<=countbyte+1;
      clkn <= ~clkn;
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
    .rst_n(txrst),    // Hardcoded: Should be input   // Hardcoded: Should be controlled
    .status(stat)
  );

  // Instantiate RX module
  UART_rx2 RX (
    .clk(clkn),
    .data_in(Rx),
    .data_out(data),           // Unconnected
    .rst_n(rxrst)
	 
	 // Unconnected
  );

endmodule

// UART transmitter module
module UART_tx2 (
  input        clk,       // Divided clock
  input        rst_n,     // Active-low reset
  input [7:0]  data,      // Data to transmit
  output reg   data_out,  // Serial output
  output reg   status// Debug output (state)
);
  // State machine parameters
  parameter IDLE  = 2'b00, START = 2'b01, DATA = 2'b10, STOP = 2'b11;
  parameter CLKS_PER_BIT = 16; // Clock cycles per bit (for simulation)
  parameter CLKSidel = 20;
  // Internal registers
  reg [7:0]  data_buff=0;     // Data buffer for transmission
  reg        curr_stat;     // Tracks start status
  reg [15:0] clk_counter;   // Counts clock cycles per bit
  reg [3:0]  flag = 0;      // Bit counter (should use bit_counter)
  reg [1:0]  STATE = IDLE;  // State machine register
  reg [31:0] counter = 0;   // Unused
  reg [3:0]  bit_counter = 0; // Tracks transmitted bits
  reg        stat = 1;      // Initialization flag (causes Error 10200)
	
  // State machine and transmission logic
  always @(posedge clk or negedge rst_n) begin // Should be @(posedge clk or negedge rst_n)
    if (!rst_n) begin
      // Initialize on first cycle (non-synthesizable; use rst_n)
      data_out <= 1;         // Idle high
      data_buff <= data;     // Load data
      clk_counter <= 0; 
			status<=1;// Reset counter           // Disable initialization
    end else begin
      case (STATE)
        IDLE: begin
          if (clk_counter < CLKSidel ) begin
            data_out <= 1;     // Stay idle
            data_buff <= data; // Reload data
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
				data_buff <= data;
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
            if (clk_counter < CLKS_PER_BIT) begin
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
          if (clk_counter < CLKS_PER_BIT) begin
            data_out <= 1;     // Send stop bit
            STATE <= STOP;
            clk_counter <= clk_counter + 1;
          end else begin
            data_out <= 1;     // Idle
            STATE <= IDLE;
				status<=1;
          end
        end
        default: STATE <= IDLE;
      endcase
    end
  end

endmodule

// UART receiver module
module UART_rx2 #(
  parameter CLKS_PER_BIT = 16 // Clock cycles per bit (for simulation)
) (
  input        clk,       // Divided clock
   input    rst_n, 
  input        data_in,   // Serial input
  output reg [7:0] data_out // Received data
);
  // State machine parameters
  parameter IDLE  = 2'b00, START = 2'b01, DATA = 2'b10, STOP = 2'b11;
  reg [7:0] data_val;
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
   always @(posedge clk or negedge rst_n) begin // Should add rst_n
    if (~rst_n) begin
      // Initialize on first cycle (non-synthesizable; use rst_n)
      count <= 0;
      //data_val <= 8'h00;
      bitcount <= 0;
      statflag <= 0;
		data_out<=0;
    end else begin
      case (STATE)
        IDLE: begin
          if (data_in==0) begin
            STATE <= START; // Detect start bit
				clk_counter<=0;
          end
        end
        START: begin
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
				
            STATE <= STOP;
            clk_counter <= 0;
          end
			 
        end
        STOP: begin
          if (data_in && clk_counter == CLKS_PER_BIT) begin
					data_out<=data_val;
					STATE <= IDLE;
			 end 
            clk_counter <= clk_counter + 1;
          end 
        default: STATE <= IDLE;
      endcase
    end
  end

endmodule