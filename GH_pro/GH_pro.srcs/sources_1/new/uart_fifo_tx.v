`timescale 1ns / 1ps


module uart_fifo_tx (
    input        clk,
    input        rst,
    input [31:0] display_data,
    input        sel_watch_status,
    input        sel_sw_status,
    input        sel_sr04_status,
    input        sel_dht_status,
    output       tx //To PC
);

	wire w_push_en, w_tx_busy, w_empty;
	wire [31:0] w_ascii_out, w_pop_data;


	ascii_sender U_ASCII_SENDER(
	   .clk(clk),
	   .rst(rst),
	   .sel_watch_status(sel_watch_status),
	   .sel_sw_status(sel_sw_status),
	   .sel_sr04_status(sel_sr04_status),
	   .sel_dht_status(sel_dht_status),
	   .display_data(display_data), //{Hour,Min,Sec,Msec} | {Distance, 20'd0} | {Temperature, Humidity, 16'd0}
	   .push_data(w_ascii_out),
	   .push(w_push_en)
	);



	fifo U_FIFO_TX(
		.clk(clk),
		.rst(rst),
		.push_data(w_ascii_out),
		.push(w_push_en),
		.pop(~w_tx_busy&~w_empty),
		.pop_data(w_pop_data),  // output
		.full(),
		.empty(w_empty)
    );


	uart_tx U_UART_TX(
   		.clk(clk),
   		.rst(rst),
   		.tx_start(~w_tx_busy&~w_empty),  
   		.tx_data(w_pop_data),
   		.b_tick(w_b_tick),
   		.tx_busy(w_tx_busy),
   		.tx(tx)
	);


    wire w_b_tick;
    baud_tick_gen U_BAUD_TICK_GEN (
        .clk     (clk),
        .rst     (rst),
        .o_b_tick(w_b_tick)
    );


endmodule



module uart_tx (
    input        clk,
    input        rst,
    input        tx_start,  
    input  [7:0] tx_data,
    input        b_tick,
    output       tx_busy,
    output       tx
);

    parameter IDLE = 0, START = 1, DATA = 2, STOP = 3;

    reg [2:0] c_state, n_state;
    reg tx_reg, tx_next;
    reg [7:0] data_reg, data_next;
    // 0?????? 7까?? 반복?????? ?????? 3비트 카운???
    reg [2:0] bit_cnt_reg, bit_cnt_next; 
    reg [3:0] b_tick_cnt_reg, b_tick_cnt_next; 
    
    reg tx_busy_reg, tx_busy_next;


    assign tx = tx_reg;
    assign tx_busy = tx_busy_reg;

    // state & data register
    always @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state     <= IDLE;
            tx_reg      <= 1'b1;
            data_reg    <= 8'h00;
            bit_cnt_reg <= 3'b000;
            b_tick_cnt_reg <= 4'h0;
            tx_busy_reg    <=1'b0;
        end else begin
            c_state     <= n_state;
            tx_reg      <= tx_next;
            data_reg    <= data_next;
            bit_cnt_reg <= bit_cnt_next;
            b_tick_cnt_reg <= b_tick_cnt_next;
            tx_busy_reg <= tx_busy_next;
        end
    end

    // next state CL, Output (Mealy 출력 : 빠르??? 처리?????? ??????)
    always @(*) begin
        n_state = c_state;
        tx_next = tx_reg;
        data_next = data_reg;
        bit_cnt_next = bit_cnt_reg;
        b_tick_cnt_next = b_tick_cnt_reg;
        tx_busy_next = tx_busy_reg;

        case (c_state)
            IDLE: begin
                tx_next = 1'b1;
                if (tx_start) begin
                    tx_busy_next=1'b1;
                    data_next = tx_data;
                    bit_cnt_next = 3'b000;  
                    b_tick_cnt_next = 4'b0000;
                    n_state = START;
                end 
            end

            START: begin
                tx_next = 1'b0;
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        b_tick_cnt_next = 0;
                        bit_cnt_next = 3'b000;
                        n_state = DATA;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1'b1;
                    end
                end 
            end

            DATA: begin
                // Parallel output
                // tx_next = data_reg[bit_cnt_reg];


                //Serial Output
                // to output form bit0 of data_reg
                tx_next = data_reg[0];
                
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        b_tick_cnt_next=0;
                        if(bit_cnt_reg == 7) begin 
                            n_state = STOP;           
                        end else begin    
                            // shift data_reg to the right
                            data_next = {1'b0,data_reg[7:1]};
                            bit_cnt_next = bit_cnt_reg + 1'b1; 
                            n_state = DATA;
                        end
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1'b1;
                    end
                end 
            end

            STOP: begin
                tx_next = 1'b1;
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        tx_busy_next = 1'b0;
                        n_state = IDLE;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end 
            end
        endcase
    end

endmodule


module ascii_sender (
    input         clk,
    input         rst,
    input         sel_watch_status,
    input         sel_sw_status,
    input         sel_sr04_status,
    input         sel_dht_status,
    input  [31:0] display_data, //{Hour,Min,Sec,Msec} | {Distance, 20'd0} | {Temperature, Humidity, 16'd0}
    output [7:0] push_data,
    output        push
);

    parameter IDLE = 0, WATCH = 1, STOPWATCH = 2, SR04 = 3, TH = 4;

    reg [2:0] c_state, n_state;
    reg [31:0] display_data_reg, display_data_next;
    reg [7:0] push_data_reg, push_data_next;
    reg push_reg, push_next;
	reg [2:0] push_cnt_reg, push_cnt_next;

    wire [7:0] w_ascii_out;


    always @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state         <= 0;
            display_data_reg <= 0;
            push_data_reg   <= 0;
            push_reg        <= 0;
			push_cnt_reg	<= 0;
        end else begin
            c_state <= n_state;
			display_data_reg <= display_data_next;
            push_data_reg <= push_data_next;
            push_reg <= push_next;
			push_cnt_reg <= push_cnt_next;
        end
    end

//W: 8'h57, S: 8'h53, D: 8'h44, E: 8'h45(Environment for T&H)
    always @(*) begin
        n_state = c_state;
        display_data_next = display_data_reg;
        push_data_next = push_data_reg;
        push_next = push_reg;
		push_cnt_next = push_cnt_reg;
        case (c_state)
            IDLE: begin
				push_cnt_next = 0;
				push_next = 0;
                if (sel_watch_status) begin
					push_next=1;
                    push_data_next = 8'h57;
					display_data_next = display_data;
			        n_state = WATCH;
                end else if(sel_sw_status) begin
					push_next=1;
					push_data_next = 8'h53;
					display_data_next = display_data;
					n_state = STOPWATCH;
				end else if(sel_sr04_status) begin
					push_next=1;
					push_data_next = 8'h44;
					display_data_next = display_data;
					n_state = SR04;
				end else if(sel_dht_status) begin
					push_next=1;
					push_data_next = 8'h45;
					display_data_next = display_data;
					n_state = TH;
				end
            end
            WATCH: begin
					push_next = 1;
					push_data_next = w_ascii_out;
					if(push_cnt_reg <= 6'd5) begin
                    	display_data_next = {display_data_reg[27:0], 4'b0000};
						push_cnt_next = push_cnt_reg + 1;
					end else begin
						push_next = 0;
						n_state = IDLE;
					end
            end
			STOPWATCH : begin
					push_data_next = w_ascii_out;
					push_next = 1;
					if(push_cnt_reg <= 6'd5) begin
                    	display_data_next = {display_data_reg[27:0], 4'b0000};
						push_cnt_next = push_cnt_reg + 1;
					end else begin
						push_next = 0;
						n_state = IDLE;
					end
			end
			SR04: begin
					push_data_next = w_ascii_out;
					push_next = 1;
					if(push_cnt_reg <= 6'd2) begin
                    	display_data_next = {display_data_reg[27:0], 4'b0000};
						push_cnt_next = push_cnt_reg + 1;
					end else begin
						push_next = 0;
						n_state = IDLE;
					end
			end
			TH: begin
					push_data_next = w_ascii_out;
					push_next = 1;
					if(push_cnt_reg <= 6'd3) begin
                    	display_data_next = {display_data_reg[27:0], 4'b0000};
						push_cnt_next = push_cnt_reg + 1;
					end else begin
						push_next = 0;
						n_state = IDLE;
					end
			end
        endcase

    end

	assign push = push_reg;
	assign push_data = (push_reg) ? push_data_reg : 8'bz;

    ascii_gen U_ASCII_GEN (
        .data(display_data_reg[31:28]),
        .ascii_out(w_ascii_out)
    );


endmodule

module ascii_gen (
    input [3:0] data,
    output reg [7:0] ascii_out
);

    always @(*) begin
        case (data)
            4'd0: ascii_out = 8'h30;
            4'd1: ascii_out = 8'h31;
            4'd2: ascii_out = 8'h32;
            4'd3: ascii_out = 8'h33;
            4'd4: ascii_out = 8'h34;
            4'd5: ascii_out = 8'h35;
            4'd6: ascii_out = 8'h36;
            4'd7: ascii_out = 8'h37;
            4'd8: ascii_out = 8'h38;
            4'd9: ascii_out = 8'h39;
        endcase
    end


endmodule
