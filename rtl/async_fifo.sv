// -----------------------------------------------------------------------------
// async_fifo : Top-level asynchronous FIFO with clock-domain crossing.
//
// Two independent clock domains (wclk / rclk) with independent async resets.
// The only signals that cross domains are the Gray-coded pointers, each passed
// through a two-flop synchronizer:
//
//     wptr (write domain) --[sync_2ff on rclk]--> wq2_rptr  (read domain)
//     rptr (read  domain) --[sync_2ff on wclk]--> rq2_wptr  (write domain)
//
// Everything else (data, full, empty, addresses) stays wholly within one
// domain, so this is the entire CDC surface of the design.
// -----------------------------------------------------------------------------
`default_nettype none

module async_fifo #(
    parameter int DATA_WIDTH = 8,
    parameter int ADDR_WIDTH = 4          // DEPTH = 2**ADDR_WIDTH
) (
    // Write domain
    input  wire                   wclk,
    input  wire                   wrst_n,
    input  wire                   winc,     // write request
    input  wire [DATA_WIDTH-1:0]  wdata,
    output wire                   wfull,

    // Read domain
    input  wire                   rclk,
    input  wire                   rrst_n,
    input  wire                   rinc,     // read request
    output wire [DATA_WIDTH-1:0]  rdata,
    output wire                   rempty
);

    // Gray pointers exchanged between the domains.
    wire [ADDR_WIDTH:0] wptr, rptr;        // native (source-domain) gray ptrs
    wire [ADDR_WIDTH:0] wq2_rptr;          // wptr synchronized into read domain
    wire [ADDR_WIDTH:0] rq2_wptr;          // rptr synchronized into write domain

    // Memory addresses (binary).
    wire [ADDR_WIDTH-1:0] waddr, raddr;

    // --- CDC: write gray pointer -> read domain -------------------------------
    sync_2ff #(.WIDTH(ADDR_WIDTH+1)) sync_w2r (
        .clk   (rclk),
        .rst_n (rrst_n),
        .d_in  (wptr),
        .q_out (wq2_rptr)
    );

    // --- CDC: read gray pointer -> write domain -------------------------------
    sync_2ff #(.WIDTH(ADDR_WIDTH+1)) sync_r2w (
        .clk   (wclk),
        .rst_n (wrst_n),
        .d_in  (rptr),
        .q_out (rq2_wptr)
    );

    // --- Write-domain pointer + full ------------------------------------------
    wptr_full #(.ADDR_WIDTH(ADDR_WIDTH)) u_wptr_full (
        .wclk     (wclk),
        .wrst_n   (wrst_n),
        .winc     (winc),
        .rq2_wptr (rq2_wptr),
        .wptr     (wptr),
        .waddr    (waddr),
        .wfull    (wfull)
    );

    // --- Read-domain pointer + empty ------------------------------------------
    rptr_empty #(.ADDR_WIDTH(ADDR_WIDTH)) u_rptr_empty (
        .rclk     (rclk),
        .rrst_n   (rrst_n),
        .rinc     (rinc),
        .wq2_rptr (wq2_rptr),
        .rptr     (rptr),
        .raddr    (raddr),
        .rempty   (rempty)
    );

    // --- Storage ---------------------------------------------------------------
    fifo_mem #(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)) u_mem (
        .wclk  (wclk),
        .wen   (winc & ~wfull),   // accepted writes only
        .waddr (waddr),
        .wdata (wdata),
        .raddr (raddr),
        .rdata (rdata)
    );

endmodule

`default_nettype wire
