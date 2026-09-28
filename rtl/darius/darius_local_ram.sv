/*  This file is part of Darius_MiSTer.

    Darius_MiSTer is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Darius_MiSTer is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Darius_MiSTer.  If not, see <http://www.gnu.org/licenses/>.

    Author: Umberto Parisi (rmonic79)
    Version: 1.0
    Date: 2026

*/

// darius_local_ram — single-port BRAM with byte enable.
// HI/LO split for clean M10K inference with byte enable.
// Used for main RAM, local sprite RAM and other single-client RAMs.

module darius_local_ram
#(
	parameter integer ADDR_WIDTH = 11,
	// RetroAchievements RAM mirror: 1 = second, read-only 64-bit port
	// (ra_addr/ra_q, see rtl/ra/ra_ram16_rd64.sv), same M10K bits
	parameter integer RA_PORT    = 0
)
(
	input  wire                  clk,
	input  wire                  rd,
	input  wire                  wr,
	input  wire [1:0]            be,    // byte enable: be[1]=write HI, be[0]=write LO
	input  wire [ADDR_WIDTH-1:0] addr,
	input  wire [15:0]           wdata,
	output wire [15:0]           rdata,

	// RetroAchievements mirror read port (RA_PORT=1): qword n = words
	// 4n..4n+3, word 4n in bits 15:0, registered address, data 1 clk later
	input  wire                  ra_clk,
	input  wire [ADDR_WIDTH-3:0] ra_addr,
	output wire [63:0]           ra_q
);

generate
if (RA_PORT) begin : ra_ram
	// Same RAM as below, as an explicit dual-port M10K whose second port is
	// the RetroAchievements mirror's (contents power up as zero, as below).
	ra_ram16_rd64 #(.WIDTHAD(ADDR_WIDTH)) u_ram (
		.clock    (clk),
		.we       ({wr & be[1], wr & be[0]}),
		.address  (addr),
		.data     (wdata),
		.q        (rdata),
		.clock_b  (ra_clk),
		.address_b(ra_addr),
		.q_b      (ra_q)
	);
end else begin : plain_ram
assign ra_q = 64'd0;

// Split into two 8-bit RAMs for proper M10K byte-enable inference
(* ramstyle = "M10K" *) reg [7:0] ram_hi [0:(1 << ADDR_WIDTH)-1];
(* ramstyle = "M10K" *) reg [7:0] ram_lo [0:(1 << ADDR_WIDTH)-1];
reg [7:0] rdata_hi, rdata_lo;

// synthesis translate_off
initial begin : init_ram
	integer i;
	for (i = 0; i < (1 << ADDR_WIDTH); i = i + 1) begin
		ram_hi[i] = 8'h00;
		ram_lo[i] = 8'h00;
	end
end
// synthesis translate_on

// Lettura non gated (come le RAM di BoogieWings): rdata segue addr con 1 clk
// di latenza — necessario per ss_ram16_adaptor (legge via addr_out senza rd);
// per la CPU equivalente (campiona rdata solo nei propri cicli di read).
always @(posedge clk) begin
	if (wr && be[1]) ram_hi[addr] <= wdata[15:8];
	if (wr && be[0]) ram_lo[addr] <= wdata[7:0];
	rdata_hi <= ram_hi[addr];
	rdata_lo <= ram_lo[addr];
end

assign rdata = {rdata_hi, rdata_lo};
end
endgenerate

endmodule
