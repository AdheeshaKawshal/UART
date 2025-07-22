module UART_TX (
  input        clk,       
  input        rst_n,     // Active-low reset
  input [7:0]  data,      // Data to transmit
  output reg   data_out,  // Serial output
  output reg   status,
  input        tx_ctr
);
  parameter IDLE  = 2'b00, START = 2'b01, DATA = 2'b10, STOP = 2'b11;
  parameter CLKS_PER_BIT = 16;
  parameter CLKSidel = 100000;
  reg [7:0]  data_buff=0;     // Data buffer for transmission
  reg        curr_stat;       // Tracks start status
  reg [19:0] clk_counter;     // Counts clock cycles per bit
  reg [1:0]  STATE = IDLE;    // State machine register
  reg [3:0]  bit_index = 0;   // Tracks transmitted bits
  

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      data_out    <= 1;         
      data_buff   <= data;   
      clk_counter <= 0; 
		status      <= 1;
    end else begin
      case (STATE)
        IDLE: begin
          if (clk_counter < CLKSidel ) begin
            data_out    <= 1;    
            data_buff   <= data; 
				clk_counter <= clk_counter +1;
				status		<=1;
          end else begin
            STATE 		<= START;
            status		<= 0;
				clk_counter <= 0;
          end
        end
        START: begin
          if (clk_counter < CLKS_PER_BIT-1) begin
            data_out    <= 0;   
				data_buff   <= data;
            clk_counter <= clk_counter + 1;
          end else begin
            clk_counter <= 0;
            STATE 		<= DATA;
            bit_index 	<= 0;  
          end
        end
        DATA: begin
          if (bit_index < 8) begin
            STATE <= DATA;
            if (clk_counter < CLKS_PER_BIT-1) begin
              data_out 		<= data_buff[0];   // Send LSB
              clk_counter  <= clk_counter + 1;
            end else begin
              data_buff 	<= data_buff >> 1; // Shift right
              clk_counter  <= 0;
              bit_index 	<= bit_index + 1;
            end
          end else begin 
            STATE <= STOP;   
            clk_counter <= 0;
          end
        end
        STOP: begin
          if (clk_counter < CLKS_PER_BIT-1) begin
            data_out 	<= 1;     // Send stop bit
            STATE 		<= STOP;
            clk_counter <= clk_counter + 1;
          end else begin
            data_out <= 1;   
            STATE 	<= IDLE;
				status	<=1;
          end
        end
        default: STATE <= IDLE;
      endcase
    end
  end

endmodule