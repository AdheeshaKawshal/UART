module UART_RX #(
  parameter CLKS_PER_BIT = 16
) (
   input            clk,      
   input            rst_n, 
   input            data_in,   
   output reg [7:0] data_out
);
  parameter IDLE  = 2'b00, START = 2'b01, DATA = 2'b10, STOP = 2'b11;
  reg [7:0]  data_val;       
  reg [15:0] clk_counter;   
  reg [3:0]  filtercount;      
  reg [1:0]  STATE = IDLE; 
  reg [3:0]  bitcount;      
  reg        flag = 1;     
  reg        statflag = 1; 
  
  always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
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
			 else if (data_in == 1 && clk_counter == CLKS_PER_BIT/2 -1) begin 
				STATE <= IDLE;
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
			 else if (data_in==0 && clk_counter == CLKS_PER_BIT) begin
					STATE <= IDLE;
			 end 
            clk_counter <= clk_counter + 1;
          end 
        default: STATE <= IDLE;
      endcase
    end
  end

endmodule