// -----------------------------------------------------------------------------
// sync_2ff : Two-flop synchronizer for a multi-bit (Gray-coded) pointer bus.
//
// Only ONE bit of a Gray code changes between adjacent values, so sampling the
// bus with a two-flop synchronizer can never resolve to an illegal value: at
// worst a single bit metastabilizes and the register lands on either the old
// or the new pointer, both of which are valid. That is the property that makes
// Gray-coded pointers safe to carry across an unrelated clock domain.
//
// The ASYNC_REG attribute asks the tools to keep the two flops together (same
// slice) for the best mean-time-between-failures, and marks the pair as an
// intentional synchronizer so report_cdc classifies the crossing as safe.
// -----------------------------------------------------------------------------
`default_nettype none

module sync_2ff #(
    parameter int WIDTH = 4
) (
    input  wire              clk,      // destination-domain clock
    input  wire              rst_n,    // async active-low reset (dest domain)
    input  wire [WIDTH-1:0]  d_in,     // bus from the source domain
    output wire [WIDTH-1:0]  q_out     // synchronized bus in the dest domain
);

    (* ASYNC_REG = "TRUE" *) reg [WIDTH-1:0] sync_ff1;  // first capture (may be metastable)
    (* ASYNC_REG = "TRUE" *) reg [WIDTH-1:0] sync_ff2;  // second capture (settled)

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sync_ff1 <= '0;
            sync_ff2 <= '0;
        end else begin
            sync_ff1 <= d_in;      // allowed a full cycle to settle before ff2
            sync_ff2 <= sync_ff1;
        end
    end

    assign q_out = sync_ff2;

endmodule

`default_nettype wire
