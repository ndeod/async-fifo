// -----------------------------------------------------------------------------
// fifo_mem : Dual-port synchronous RAM used as the FIFO storage.
//
//   * Write port is clocked by the write-domain clock (wclk).
//   * Read  port is combinational: rdata reflects the word at raddr.
//
// The memory itself carries no synchronization; all CDC safety lives in the
// pointer/synchronizer logic. The full/empty guards guarantee the write and
// read sides never touch the same word simultaneously, so there is no race on
// any given location.
// -----------------------------------------------------------------------------
`default_nettype none

module fifo_mem #(
    parameter int DATA_WIDTH = 8,
    parameter int ADDR_WIDTH = 4
) (
    input  wire                   wclk,
    input  wire                   wen,      // write enable (write & !full)
    input  wire [ADDR_WIDTH-1:0]  waddr,
    input  wire [DATA_WIDTH-1:0]  wdata,
    input  wire [ADDR_WIDTH-1:0]  raddr,
    output wire [DATA_WIDTH-1:0]  rdata
);

    localparam int DEPTH = 1 << ADDR_WIDTH;

    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    always_ff @(posedge wclk) begin
        if (wen)
            mem[waddr] <= wdata;
    end

    assign rdata = mem[raddr];

endmodule

`default_nettype wire