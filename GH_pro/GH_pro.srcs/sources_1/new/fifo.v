`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/04/28 16:40:49
// Design Name: 
// Module Name: fifo
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


module fifo(
	input clk,
	input rst,
	input [7:0] push_data,
	input push,
	input pop,
	output [7:0] pop_data,
	output full,
	output empty
    );

	parameter DEPTH = 8, BIT_WIDTH = $clog2(DEPTH) -1;
	wire [BIT_WIDTH:0] w_wptr, w_rptr;

	register_file
	#(.DEPTH(DEPTH)
	) U_REG_FILE(
		.clk(clk),
		.wdata(push_data),
		.waddr(w_wptr),
		.raddr(w_rptr),
		.we(((~full)&push)),
		.rdata(pop_data)
	);
	


	control_unit 
	#(.DEPTH(DEPTH)
	) U_CONTORL_UNIT(
		.clk(clk),
		.rst(rst),
		.push(push),
		.pop(pop),
		.wptr(w_wptr),
		.rptr(w_rptr),
		.full(full),
		.empty(empty)
	);

endmodule



module register_file
#(parameter DEPTH = 8,
BIT_WIDTH = $clog2(DEPTH)-1
)(
	input clk,
	input [7:0] wdata,
	input [BIT_WIDTH:0] waddr,
	input [BIT_WIDTH:0] raddr,
	input we,
	output [7:0] rdata
	);

	reg [7:0] register_file [0:DEPTH-1];	
	always @(posedge clk) begin
		if(we) begin
			register_file[waddr] <= wdata;
		end
	end

	assign rdata = register_file[raddr];
endmodule

module control_unit 
#(parameter DEPTH = 8,
BIT_WIDTH = $clog2(DEPTH)-1
)(
	input clk,
	input rst,
	input push,
	input pop,
	output [BIT_WIDTH:0] wptr,
	output [BIT_WIDTH:0] rptr,
	output full,
	output empty
);
	reg [BIT_WIDTH:0] wptr_reg, wptr_next;
	reg [BIT_WIDTH:0] rptr_reg, rptr_next;
	reg full_reg, full_next, empty_reg, empty_next;

	assign wptr = wptr_reg;
	assign rptr = rptr_reg;
	assign full = full_reg;
	assign empty = empty_reg;

	always @(posedge clk, posedge rst) begin
		if(rst) begin
			wptr_reg <= 0;
			rptr_reg <= 0;
			full_reg <= 1'b0;
			empty_reg <= 1'b1;      
		end else begin
			wptr_reg <= wptr_next;
			rptr_reg <= rptr_next;
			full_reg <= full_next;
			empty_reg <= empty_next; 
		end
	end

	always @(*) begin
		wptr_next = wptr_reg;
		rptr_next = rptr_reg;
		full_next = full_reg;
		empty_next = empty_reg; 

		case({push,pop})
		2'b10: begin //push only
			if(!full_reg) begin
				wptr_next = wptr_reg + 1;
				empty_next = 1'b0;
				if(wptr_next == rptr_reg) begin
					full_next = 1'b1;
				end
			end 
		end

		2'b01 : begin // pop only
			if(!empty_reg) begin
				rptr_next = rptr_reg + 1;
				full_next = 1'b0;
				if(wptr_reg == rptr_next) begin
					empty_next = 1'b1;
				end
			end
		end
		
		
		2'b11: begin //push&pop 
			if(full_reg) begin
				//pop only
				rptr_next = rptr_reg + 1;
				full_next = 1'b0;
			end else if(empty_reg) begin
				//push only
				wptr_next = wptr_reg + 1;
				empty_next = 1'b0;
			end else begin
				wptr_next = wptr_reg + 1;
				rptr_next = rptr_reg + 1;
			end
		end
		

			
		endcase
	end
endmodule

