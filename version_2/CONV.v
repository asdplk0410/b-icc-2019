
// `timescale 1ns/10ps

//synopsys translate_off
// `include "./DW02_mac.v"
// `include "/cad/synopsys/synthesis/2020.09/dw/sim_ver/DW02_mac.v"
//synopsys translate_on

module  CONV(
	input		clk,
	input		reset,
	output reg busy,	
	input		ready,	
			
	output reg [11:0] iaddr,
	input [19:0]idata,	
	
	output reg cwr,
	output reg [11:0] caddr_wr,
	output reg [19:0] cdata_wr,
	
	output reg crd,
	output reg [11:0] caddr_rd,
	input [19:0] cdata_rd,
	
	output reg [2:0] csel
	);

	localparam IDLE  = 4'd0;
	localparam RECV  = 4'd1;
	localparam OUT   = 4'd2;
	localparam L0    = 4'd3;
	localparam L1    = 4'd4;
	localparam KER1  = 4'd5;
	localparam RMEM  = 4'd6;
	localparam MAXP  = 4'd7;
	localparam MEM1  = 4'd8;
	localparam L2    = 4'd9;
	localparam DONE = 4'd10;
 
	parameter Bias_1 = 20'hF7295;

	reg [3:0] ps, ns;
	reg [1:0] index_kx, index_ky;
	reg signed [19:0] kernel_reg;
	reg signed [39:0] data_l0_reg;
	reg [5:0] anchor_x, anchor_y;
	reg flag_ker;
	reg [11:0] index;
	reg signed [19:0] idata_reg;
	reg [3:0] index_k;

	wire signed [19:0] kernel;
	wire signed [39:0] data_l0;
	wire signed [19:0] A, B;
	wire signed [39:0] bais;

	always @(posedge clk or posedge reset) begin
		if(reset) 
		begin
			ps <= IDLE;
		end
		else 
		begin
			ps <= ns;
		end
	end

	always @(*) begin
		case(ps)
		IDLE:    ns =                                            RECV;
		RECV:    ns = (index_k == 4'd12) ? OUT : RECV;
		OUT:     ns =                                            L0;
		L0:      ns = (anchor_y == 6'd63 && anchor_x == 6'd63) ? KER1 : RECV;
		KER1:    ns = (flag_ker                              ) ? RMEM : RECV;
		RMEM:    ns =                                            MAXP;
		MAXP:    ns = (index_ky == 2'd2  && index_kx == 2'd0 ) ? L1 : RMEM;
		L1:      ns =                                            L2;
		L2:      ns = (anchor_y == 6'd31 && anchor_x == 6'd31) ? MEM1 : RMEM;
		MEM1:    ns = (flag_ker                              ) ? DONE : RMEM;
		default: ns =                                            IDLE;
		endcase
	end

	// kernel 0/1 switch
	always @(posedge clk or posedge reset) begin
		if(reset)
		begin
			flag_ker <= 1'd0;
		end
		else if(ps == KER1 || ps == MEM1)
		begin
			flag_ker <= ~flag_ker;
		end
	end

	always @(posedge clk or posedge reset) begin
		if(reset)
		begin
			index_k <= 4'd0;
		end
		else if(ps == RECV)
		begin
			index_k <= {index_ky,index_kx};
		end
	end

	// Convolution
	assign data_l0 = idata_reg * kernel_reg;

	// initial kernel 
	always @(posedge clk or posedge reset) begin
		if(reset)
		begin
			kernel_reg <= 20'h00000; 
		end
		else if(ps == RECV)
		begin
			if(flag_ker)
			begin
				case (index_k)
					4'b0000: kernel_reg <= (anchor_y == 6'd0 || anchor_x == 6'd0)   ? 20'd0 : 20'hFDB55;
					4'b0001: kernel_reg <= (anchor_y == 6'd0)                       ? 20'd0 : 20'h02992;
					4'b0010: kernel_reg <= (anchor_y == 6'd0 || anchor_x == 6'd63)  ? 20'd0 : 20'hFC994; 
					4'b0100: kernel_reg <= (anchor_x == 6'd0)                       ? 20'd0 : 20'h050FD;
					4'b0101: kernel_reg <=                                                    20'h02F20;
					4'b0110: kernel_reg <= (anchor_x == 6'd63)                      ? 20'd0 : 20'h0202D;
					4'b1000: kernel_reg <= (anchor_y == 6'd63 || anchor_x == 6'd0)  ? 20'd0 : 20'h03BD7;
					4'b1001: kernel_reg <= (anchor_y == 6'd63)                      ? 20'd0 : 20'hFD369;
					4'b1010: kernel_reg <= (anchor_y == 6'd63 || anchor_x == 6'd63) ? 20'd0 : 20'h05E68;
					default: kernel_reg <= 20'h00000; 
				endcase
			end
			else
			begin
				case (index_k)
					4'b0000: kernel_reg <= (anchor_y == 6'd0 || anchor_x == 6'd0) ? 20'd0 : 20'h0A89E;
					4'b0001: kernel_reg <= (anchor_y == 6'd0) ? 20'd0 : 20'h092D5;
					4'b0010: kernel_reg <= (anchor_y == 6'd0 || anchor_x == 6'd63) ? 20'd0 : 20'h06D43; 
					4'b0100: kernel_reg <= (anchor_x == 6'd0) ? 20'd0 : 20'h01004;
					4'b0101: kernel_reg <= 20'hF8F71;
					4'b0110: kernel_reg <= (anchor_x == 6'd63) ? 20'd0 : 20'hF6E54;
					4'b1000: kernel_reg <= (anchor_y == 6'd63 || anchor_x == 6'd0) ? 20'd0 : 20'hFA6D7;
					4'b1001: kernel_reg <= (anchor_y == 6'd63) ? 20'd0 : 20'hFC834;
					4'b1010: kernel_reg <= (anchor_y == 6'd63 || anchor_x == 6'd63) ? 20'd0 : 20'hFAC19;
					default: kernel_reg <= 20'h00000; 
				endcase
			end
		end
	end

	// kernel index
	always @(posedge clk or posedge reset) begin
		if(reset)
		begin
			index_kx <= 2'd0;
		end
		else if(ps == RECV)
		begin
			index_kx <= (index_kx == 2'd2) ? 2'd0 : index_kx + 1'd1;
		end
		else if(ps == RMEM)
		begin
			index_kx <= (index_kx == 2'd1) ? 2'd0 : index_kx + 1'd1;
		end
	end

	always @(posedge clk or posedge reset) begin
		if(reset)
		begin
			index_ky <= 2'd0;
		end
		else if(ps == RECV)
		begin
			index_ky <= (index_kx == 2'd2) ? index_ky + 1'd1 : index_ky;
		end
		else if(ps == RMEM)
		begin
			index_ky <= (index_kx == 2'd1) ? index_ky + 1'd1 : index_ky;
		end
		else if(ps == L1)
		begin
			index_ky <= 2'd0;
		end
	end

	// input address
	always @(posedge clk or posedge reset) begin
		if(reset)
		begin
			iaddr <= 12'd0;
		end
		else if(ps == RECV)
		begin
			iaddr <= 12'd64*(index_ky - 1'd1) + index_kx - 1'd1 + {anchor_y, anchor_x};
		end
	end 

	always @(posedge clk or posedge reset) begin
		if(reset)
		begin
			idata_reg <= 19'd0;
		end
		else if(ps == RECV)
		begin
			idata_reg <= idata;
		end
	end 

	// anchor
	always @(posedge clk or posedge reset) begin
		if(reset)
		begin
			anchor_x <= 6'd0;
		end
		else if (ps == L0)
		begin
			anchor_x <= (anchor_x == 6'd63) ? 6'd0 : anchor_x + 1'd1;
		end
		else if (ps == L2)
		begin
			anchor_x <= (anchor_x == 6'd31) ? 6'd0 : anchor_x + 1'd1;
		end
	end

	always @(posedge clk or posedge reset) begin
		if(reset)
		begin
			anchor_y <= 6'd0;
		end
		else if (ps == L0)
		begin
			anchor_y <= (anchor_x == 6'd63) ? (anchor_y == 6'd63) ? 6'd0 : anchor_y + 1'd1 : anchor_y;
		end
		else if (ps == L2)
		begin
			anchor_y <= (anchor_x == 6'd31) ? (anchor_y == 6'd31) ? 6'd0 : anchor_y + 1'd1 : anchor_y;
		end
	end

	// data register
	always @(posedge clk or posedge reset) begin
		if(reset)
		begin
			data_l0_reg <= 40'd0;
		end
		else if(ps == RECV)
		begin
			data_l0_reg <= data_l0_reg + data_l0; 
		end
		else if (ps == OUT)
		begin
			data_l0_reg <= data_l0_reg + bais; 
		end
		else if(ps == L0)
		begin
			data_l0_reg <= 40'd0;
		end
	end

	assign bais   = (flag_ker) ? 40'hFF72950000 : 40'h0013100000;

	// L2 ouput index
	always @(posedge clk or posedge reset) begin
		if(reset)
		begin
			index <= 12'd0;
		end
		else if(ps == L2)
		begin
			index <= index + 1'd1;
		end
		else if(ps == MEM1)
		begin
			index <= 12'd0;
		end
	end

	// output
	always @(posedge clk or posedge reset) begin
		if(reset)
		begin
			busy <= 1'd0;
		end
		else if(ready)
		begin
			busy <= 1'd1;
		end
		else if(ps == DONE)
		begin
			busy <= 1'd0;
		end
	end

	// write memory
	always @(posedge clk or posedge reset) begin
		if(reset)
		begin
			caddr_wr <= 12'd0;
		end
		else if(ps == L0)
		begin
			caddr_wr <= {anchor_y, anchor_x};
		end
		else if(ps == L1)
		begin
			caddr_wr <= {2'd0, anchor_y[4:0], anchor_x[4:0]};
		end
		else if(ps == L2)
		begin
			caddr_wr <= 2*index + {11'd0, flag_ker};
		end
	end

	always @(posedge clk or posedge reset) begin
		if(reset)
		begin
			cdata_wr <= 20'd0;
		end
		else if(ps == L0)
		begin
			cdata_wr <= (data_l0_reg > 0) ? 
						(data_l0_reg[15]) ? data_l0_reg[35:16] + 20'd1 : data_l0_reg[35:16] :
						20'd0;
		end
		else if(ps == RMEM)
		begin
			cdata_wr <= (~|(index_kx) && ~|(index_ky)) ? 20'd0 : cdata_wr;
		end
		else if(ps == MAXP)
		begin
			cdata_wr <= (cdata_rd > cdata_wr) ? cdata_rd : cdata_wr;
		end
	end

	// read memory
	always @(posedge clk or posedge reset) begin
		if(reset)
		begin
			caddr_rd <= 12'd0;
		end
		else if(ps == RMEM)
		begin
			caddr_rd <= 64*index_ky + index_kx + 2*{anchor_y, anchor_x};
		end
	end

	// read enable
	always @(posedge clk or posedge reset) begin
		if(reset)
		begin
			crd <= 1'd0;
		end
		else if(ps == RMEM)
		begin
			crd <= 1'd1;
		end
		else 
		begin
			crd <= 1'd0;
		end
	end

	// write enable
	always @(posedge clk or posedge reset) begin
		if(reset)
		begin
			cwr <= 1'd0;
		end
		else if(ps == L0 || ps == L1 || ps == L2)
		begin
			cwr <= 1'd1;
		end
		else 
		begin
			cwr <= 1'd0;
		end
	end

	// mem select
	always @(posedge clk or posedge reset) begin
		if(reset)
		begin
			csel <= 3'b000;
		end
		else if(ps == L0 || ps == RMEM)
		begin
			csel <= (flag_ker) ? 3'b010 : 3'b001;
		end
		else if(ps == L1)
		begin
			csel <= (flag_ker) ? 3'b100 : 3'b011;
		end
		else if(ps == L2)
		begin
			csel <= 3'b101;
		end
	end

endmodule




