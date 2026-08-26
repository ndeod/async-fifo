// -----------------------------------------------------------------------------
// rptr_empty : Read-domain pointer logic and EMPTY generation.
//
// Mirror image of wptr_full, but the flag condition is simpler:
//
//   EMPTY when the read pointer has caught up to the (synchronized) write
//   pointer *exactly* -- same slot, same lap. Unlike full, there is NO bit
//   inversion: reader == writer means "nothing left to read".
//
// The read address feeds the memory combinationally, so rdata for the word at
// raddr is available in the same cycle; the consumer advances rptr with rinc.
// -----------------------------------------------------------------------------
`default_nettype none

module rptr_empty #(
    parameter int ADDR_WIDTH = 4
) (
    input  wire                    rclk,
    input  wire                    rrst_n,
    input  wire                    rinc,        // read request from consumer
    input  wire [ADDR_WIDTH:0]     wq2_rptr,    // write gray ptr, synced into rclk
    output reg  [ADDR_WIDTH:0]     rptr,        // gray read pointer (to writer)
    output wire [ADDR_WIDTH-1:0]   raddr,       // binary address into memory
    output reg                     rempty
);

    reg  [ADDR_WIDTH:0] rbin;               // binary read pointer
    wire [ADDR_WIDTH:0] rbin_next;
    wire [ADDR_WIDTH:0] rgray_next;
    wire                rempty_val;

    // Advance the binary pointer only on an accepted read (rinc & !rempty).
    assign rbin_next  = rbin + (rinc & ~rempty);

    // Binary -> Gray.
    assign rgray_next = (rbin_next >> 1) ^ rbin_next;

    // Low bits of the binary pointer address the RAM.
    assign raddr = rbin[ADDR_WIDTH-1:0];

    always_ff @(posedge rclk or negedge rrst_n) begin
        if (!rrst_n) begin
            rbin <= '0;
            rptr <= '0;
        end else begin
            rbin <= rbin_next;
            rptr <= rgray_next;
        end
    end

    // Empty when the next gray read ptr exactly equals the synced write ptr.
    assign rempty_val = (rgray_next == wq2_rptr);

    always_ff @(posedge rclk or negedge rrst_n) begin
        if (!rrst_n) rempty <= 1'b1;   // FIFO powers up empty
        else         rempty <= rempty_val;
    end

endmodule

`default_nettype wire
