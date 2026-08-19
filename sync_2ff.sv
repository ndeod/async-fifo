// -----------------------------------------------------------------------------
// sync_2ff : Two-flop synchronizer for a multi-bit (Gray-coded) pointer bus.
//
// Only ONE bit of a Gray code changes between adjacent values, so sampling the
// bus with a two-flop synchronizer can never resolve to an illegal value: at
// worst a single bit metastabilizes and the register lands on either the old
// or the new pointer, both of which are valid. That is the property that makes
// Gray-coded pointers safe to carry across an unrelated clock domain.
// -----------------------------------------------------------------------------
`default_nettype none

module sync_2ff #(
    parameter int WIDTH = 4
) (
    input  wire              clk,      // destination-domain clock
    input  wire              rst_n,    // async active-low reset (dest domain)
    input  wire [WIDTH-1:0]  d_in,     // bus from the source domain
    output reg  [WIDTH-1:0]  q_out     // synchronized bus in the dest domain
);

    reg [WIDTH-1:0] meta;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            meta  <= '0;
            q_out <= '0;
        end else begin
            meta  <= d_in;   // first capture: may go metastable
            q_out <= meta;   // second capture: allowed a full cycle to settle
        end
    end

endmodule

`default_nettype wire
