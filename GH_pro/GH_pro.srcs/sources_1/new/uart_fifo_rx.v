`timescale 1ns / 1ps


module uart_fifo_rx (
    input        clk,
    input        rst,
    input        rx, //from PC
    output [4:0] ascii_out
	);

    wire w_b_tick;
	wire [7:0] w_rx_data;
	wire w_rx_done;

    baud_tick_gen U_BAUD_TICK_GEN (
        .clk     (clk),
        .rst     (rst),
        .o_b_tick(w_b_tick)
    );

    uart_rx U_UART_RX(
    .clk        (clk),
    .rst        (rst),
    .b_tick     (w_b_tick),
    .rx         (rx),
    .rx_data    (w_rx_data),
    .rx_done    (w_rx_done)
	);

	wire w_pop, w_empty;
	assign w_pop = (!w_empty) ? 1 : 0;
	wire [7:0] w_pop_data;
	wire [4:0] w_ascii_out;

	fifo U_FIFO_RX(
		.clk(clk),
		.rst(rst),
		.push_data(w_rx_data),
		.push(w_rx_done),
		.pop(w_pop),
		.pop_data(w_pop_data),  // output
		.full(),
		.empty(w_empty)
    );

	ascii_decoder U_ASCII_DECODER(
		.clk(clk),
		.rst(rst),
		.ascii_in(w_pop_data),
		.read_en(w_pop),
		.ascii_out(w_ascii_out)     //5bit
	);
	
	assign ascii_out = w_ascii_out;

endmodule



module uart_rx(
    input           clk,
    input           rst,
    input           b_tick,
    input           rx,
    output [7:0]    rx_data,
    output          rx_done
);

    parameter IDLE = 0, START = 1, DATA = 2, STOP = 3;
    
    reg [1:0] c_state, n_state;
    reg [4:0] b_tick_cnt_reg, b_tick_cnt_next;
    reg [2:0] bit_cnt_reg, bit_cnt_next;
    reg [7:0] data_reg, data_next;              // ?????? ????????? ?????   

    reg rx_done_reg, rx_done_next;
    
    // output ????????? 

    assign rx_done = rx_done_reg;
    assign rx_data =data_reg;


    always @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state         <= IDLE;
            b_tick_cnt_reg  <= 0;
            bit_cnt_reg     <= 0;
            data_reg        <= 8'h00;
            rx_done_reg     <= 1'b0;
        end else begin
            c_state         <= n_state; 
            b_tick_cnt_reg  <= b_tick_cnt_next;
            bit_cnt_reg     <= bit_cnt_next;
            data_reg        <= data_next;
            rx_done_reg     <= rx_done_next;
        end
    end


    // next, output CL <- 같?? ?????밍에 처리?????? ????????? ????????? ????????? 
    always @(*) begin
        n_state             = c_state;
        b_tick_cnt_next     = b_tick_cnt_reg;
        bit_cnt_next        = bit_cnt_reg;
        data_next           = data_reg;
        rx_done_next        = rx_done_reg;
        case (c_state) 
            IDLE: begin
                rx_done_next  = 0;
                if (b_tick && (!rx)) begin
                    b_tick_cnt_next = 0;
                    n_state = START;
                end 
            end
            START : begin
                if (b_tick) begin
                    if (b_tick_cnt_reg == 7) begin
                        b_tick_cnt_next = 0;
                        bit_cnt_next = 0;
                        n_state = DATA; 
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1'b1;
                    end
                end
            end
            DATA : begin
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        data_next = {rx,data_reg[7:1]};
                        b_tick_cnt_next         = 0;
                        if (bit_cnt_reg ==  7 )begin
                            b_tick_cnt_next     = 0;
                            n_state             = STOP;
                        end else begin
                            bit_cnt_next = bit_cnt_reg + 1'b1;
                        end 
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg +1;
                    end
                end
            end
            STOP : begin
                if(b_tick) begin
					
               	     if((b_tick_cnt_reg == 23)||(b_tick_cnt_reg>16)&&(!rx)) begin
               	         rx_done_next = 1'b1;
               	         n_state = IDLE;
               	     end else begin
               	         b_tick_cnt_next = b_tick_cnt_reg + 1;
               	     end
                end
            end
        endcase 
    end
    
endmodule

// baud tick * 16
module baud_tick_gen (
    input clk,
    input rst,
    output reg o_b_tick
);


    // baud tick 9600 bps (hz) tick gen
    parameter F_COUNT = 100_000_000 / (9600*16);     // 기존 baud tick * 16??? 
    parameter WIDTH = $clog2(F_COUNT) - 1;          // 9600*16 = 153600 (bit width ?????? 계산)
                                                    // 153600 = 10010110101100000

    reg [WIDTH:0] counter_reg;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            counter_reg <= 0;
            o_b_tick <= 1'b0;
        end else begin
                //// period 9600hz
            counter_reg <= counter_reg + 1'b1;
            if (counter_reg == F_COUNT - 1) begin
                counter_reg <= 0;
                o_b_tick <= 1'b1;
            end else begin
                o_b_tick <= 1'b0;
            end
        end
    end

endmodule


module ascii_decoder (
	input clk,
	input rst,
	input [7:0] ascii_in,
	input read_en,
	output [4:0] ascii_out
);

	
	parameter [4:0] ascii_s = 5'b00001, ascii_2 = 5'b00010, ascii_4 = 5'b00100, ascii_6 = 5'b01000, ascii_8 = 5'b10000;

	reg [4:0] one_pulse_reg, one_pulse_delay;

	always @(posedge clk, posedge rst) begin
		if(rst) begin
			one_pulse_reg <= 5'b00000;
		end else if(read_en) begin
			case(ascii_in)
				8'h73 : one_pulse_reg <= ascii_s;
				8'h32 : one_pulse_reg <= ascii_2;
				8'h34 : one_pulse_reg <= ascii_4;
				8'h36 : one_pulse_reg <= ascii_6;
				8'h38 : one_pulse_reg <= ascii_8;
				default : one_pulse_reg <= 5'b00000;
			endcase
		end else begin
			one_pulse_reg <= 5'b00000;
		end 
	end

	always @(posedge clk, posedge rst) begin
		if(rst) begin
			one_pulse_delay <= 5'b00000;
		end else begin
			one_pulse_delay <= one_pulse_reg;
		end
	end	

	assign ascii_out = one_pulse_reg & (~one_pulse_delay);

endmodule	


