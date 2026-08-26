// -----------------------------------------------------------------------------
// wptr_full : Write-domain pointer logic and FULL generation.
//
// Pointer is ADDR_WIDTH+1 bits wide. The lower ADDR_WIDTH bits address the
// memory; the extra MSB is a "wrap" bit that lets us distinguish full from
// empty when both pointers land on the same memory word.
//
// FULL condition (Gray domain):
//   The write pointer has caught the (synchronized) read pointer, one full lap
//   ahead. In Gray code that is: the two most-significant bits differ and all
//   remaining bits match. Concretely, wgray_next equals the synchronized read
//   gray pointer with its top two bits inverted.
// -----------------------------------------------------------------------------
`default_nettype none

module wptr_full #(
    parameter int ADDR_WIDTH = 4
) (
    input  wire                    wclk,
    input  wire                    wrst_n,
    input  wire                    winc,        // write request from producer
    input  wire [ADDR_WIDTH:0]     rq2_wptr,    // read gray ptr, synced into wclk
    output reg  [ADDR_WIDTH:0]     wptr,        // gray write pointer (to reader)
    output wire [ADDR_WIDTH-1:0]   waddr,       // binary address into memory
    output reg                     wfull
);

    reg  [ADDR_WIDTH:0] wbin;               // binary write pointer
    wire [ADDR_WIDTH:0] wbin_next;
    wire [ADDR_WIDTH:0] wgray_next;
    wire                wfull_val;

    // Advance the binary pointer only on an accepted write (winc & !wfull).
    assign wbin_next  = wbin + (winc & ~wfull);

    // Binary -> Gray: g = b ^ (b >> 1).
    assign wgray_next = (wbin_next >> 1) ^ wbin_next;

    // Low bits of the binary pointer address the RAM.
    assign waddr = wbin[ADDR_WIDTH-1:0];

    always_ff @(posedge wclk or negedge wrst_n) begin
        if (!wrst_n) begin
            wbin <= '0;
            wptr <= '0;
        end else begin
            wbin <= wbin_next;
            wptr <= wgray_next;
        end
    end

    // Full when next gray write ptr == synced read ptr with top two bits flipped.
    assign wfull_val = (wgray_next == {~rq2_wptr[ADDR_WIDTH:ADDR_WIDTH-1],
                                        rq2_wptr[ADDR_WIDTH-2:0]});

    always_ff @(posedge wclk or negedge wrst_n) begin
        if (!wrst_n) wfull <= 1'b0;
        else         wfull <= wfull_val;
    end

endmodule

`default_nettype wire
