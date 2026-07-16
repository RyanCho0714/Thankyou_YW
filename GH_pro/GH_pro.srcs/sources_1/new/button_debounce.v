`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/04/15 15:11:48
// Design Name: 
// Module Name: button_debounce
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


module button_debounce(
		input clk,
		input rst,
		input i_btn,
		output o_btn
    );

	//synchronizer
	reg [7:0] sync_reg, sync_next;
	wire debounce;	

	always @(posedge clk, posedge rst) begin
		if(rst) begin
			sync_reg <= 0;
		end else begin
			sync_reg <= sync_next;
		end
	end

	always @(*) begin //<<
		sync_next = {i_btn, sync_reg[7:1]};
	//	sync_next = {sync_reg[6:0], i_btn};
	end

	//8-bit to 1 output AND gate
	assign debounce = &sync_reg;

	reg edge_reg;

	// rising edge detect
	always @(posedge clk, posedge rst) begin
		if(rst) begin
			edge_reg <=1'b0;
		end else begin
			edge_reg <= debounce;
		end
	end
	
	assign o_btn = debounce & (~edge_reg);			

endmodule
