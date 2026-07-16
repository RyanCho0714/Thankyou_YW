`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/05/03 11:13:12
// Design Name: 
// Module Name: tb_uart_fifo_tx
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module tb_uart_fifo_tx();

    reg        clk;
    reg        rst;
    reg [31:0] display_data;
    reg        sel_watch_status;
    reg        sel_sw_status;
    reg        sel_sr04_status;
    reg        sel_dht_status;
    wire       tx; //To PC

    parameter BAUD_PERIOD = (100_000_000/9600) * 10;


	uart_fifo_tx U_UART_FIFO_TX(
   		.clk(clk),
   		.rst(rst),
   		.display_data(display_data),
   		.sel_watch_status(sel_watch_status),
   		.sel_sw_status(sel_sw_status),
   		.sel_sr04_status(sel_sr04_status),
   		.sel_dht_status(sel_dht_status),
   		.tx(tx) //To PC
	);

	always #5 clk = ~clk;
	integer i;

	initial begin
	    clk = 0;
        rst = 1;
		display_data = 32'd0;
   		sel_watch_status = 0;
   		sel_sw_status = 0;
   		sel_sr04_status = 0;
   		sel_dht_status = 0;
        @(negedge clk);
        @(negedge clk);

        rst = 0;

		#100
		sel_watch_status = 1;
		display_data = {4'b0001,4'b0010,4'b0101,4'b0001,4'b0000,4'b1000,4'b1001,4'b0111};
		@(posedge clk);
		sel_watch_status = 0;

		#10_000_000;

		sel_sr04_status = 1;
		display_data = {4'b0001,4'b0010,4'b1001,20'b0};
		@(posedge clk);
		sel_sr04_status = 0;
		
		#10_000_000;

		sel_dht_status = 1;
		display_data = {4'b0010,4'b0011,4'b0110,4'b0011, 16'b0};
		@(posedge clk);
		#40;
		sel_dht_status = 0;

		#10_000_000;
		$stop;
	end

	



endmodule
