// -----------------------------------------------------------------------------
// tb_async_fifo : Constrained-random, self-checking testbench for async_fifo.
//
// Verification strategy
// ---------------------
//   * Two unrelated clocks (WCLK_PERIOD vs RCLK_PERIOD, deliberately coprime)
//     to exercise the clock-domain crossing at every phase relationship.
//   * A reference queue ("scoreboard") mirrors the DUT: every accepted write
//     pushes, every accepted read pops and checks data + FIFO ordering.
//   * Assertions guarantee the DUT never overflows (write while full) nor
//     underflows (read while empty), and that occupancy stays within DEPTH.
//   * Functional coverage (under `ifdef ENABLE_COVERAGE) records fill levels
//     and the simultaneous read/write corner.
//
// The coverage block is guarded so lightweight simulators (e.g. Icarus) can run
// the self-checking core; define ENABLE_COVERAGE in Vivado xsim for coverage.
// -----------------------------------------------------------------------------
`default_nettype none
`timescale 1ns/1ps

module tb_async_fifo;

    // ---- Parameters ----------------------------------------------------------
    localparam int DATA_WIDTH  = 8;
    localparam int ADDR_WIDTH  = 4;
    localparam int DEPTH       = 1 << ADDR_WIDTH;

    localparam realtime WCLK_PERIOD = 7ns;    // ~142.9 MHz
    localparam realtime RCLK_PERIOD = 11ns;   // ~90.9 MHz (coprime-ish period)

    localparam int NUM_ITEMS = 5000;          // items to push through the FIFO

    // ---- DUT I/O -------------------------------------------------------------
    logic                  wclk, wrst_n, winc, wfull;
    logic [DATA_WIDTH-1:0] wdata;
    logic                  rclk, rrst_n, rinc, rempty;
    logic [DATA_WIDTH-1:0] rdata;

    // ---- DUT -----------------------------------------------------------------
    async_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) dut (
        .wclk (wclk), .wrst_n(wrst_n), .winc(winc), .wdata(wdata), .wfull(wfull),
        .rclk (rclk), .rrst_n(rrst_n), .rinc(rinc), .rdata(rdata), .rempty(rempty)
    );

    // ---- Clocks --------------------------------------------------------------
    initial begin
        wclk = 1'b0;
        forever #(WCLK_PERIOD/2) wclk = ~wclk;
    end
    initial begin
        rclk = 1'b0;
        forever #(RCLK_PERIOD/2) rclk = ~rclk;
    end

    // ---- Scoreboard ----------------------------------------------------------
    logic [DATA_WIDTH-1:0] model [$];   // reference FIFO
    int                    occupancy;   // TB-side occupancy estimate
    int                    n_written;
    int                    n_read;
    int                    errors;

    // ---- Reset ---------------------------------------------------------------
    initial begin
        wrst_n = 1'b0;
        rrst_n = 1'b0;
        winc   = 1'b0;
        rinc   = 1'b0;
        wdata  = '0;
        occupancy = 0; n_written = 0; n_read = 0; errors = 0;
        repeat (5) @(posedge wclk);
        repeat (5) @(posedge rclk);
        wrst_n = 1'b1;
        rrst_n = 1'b1;
    end

    // ---- Write agent: constrained-random producer ----------------------------
    initial begin
        @(posedge wrst_n);
        @(posedge wclk);
        while (n_written < NUM_ITEMS) begin
            // ~70% attempt-to-write density; back-pressure honored via wfull.
            winc  <= ($urandom_range(0, 9) < 7);
            wdata <= $urandom_range(0, (1 << DATA_WIDTH) - 1);
            @(posedge wclk);
            if (winc && !wfull) begin
                model.push_back(wdata);
                n_written++;
                occupancy++;
                if (occupancy > DEPTH) begin
                    $error("[%0t] OVERFLOW: occupancy %0d > DEPTH %0d",
                           $time, occupancy, DEPTH);
                    errors++;
                end
            end
        end
        winc <= 1'b0;
    end

    // ---- Read agent: constrained-random consumer -----------------------------
    initial begin
        logic [DATA_WIDTH-1:0] expected;
        @(posedge rrst_n);
        @(posedge rclk);
        while (n_read < NUM_ITEMS) begin
            // ~60% attempt-to-read density; back-pressure honored via rempty.
            rinc <= ($urandom_range(0, 9) < 6);
            @(posedge rclk);
            if (rinc && !rempty) begin
                if (model.size() == 0) begin
                    $error("[%0t] UNDERFLOW: read with empty scoreboard", $time);
                    errors++;
                end else begin
                    expected = model.pop_front();
                    if (rdata !== expected) begin
                        $error("[%0t] DATA MISMATCH: got 0x%02h exp 0x%02h",
                               $time, rdata, expected);
                        errors++;
                    end
                    n_read++;
                    occupancy--;
                end
            end
        end
        rinc <= 1'b0;
    end

    // ---- Protocol assertions -------------------------------------------------
    // Never assert a write that would be accepted while full is asserting, etc.
    // (The DUT masks internally; these check that our own occupancy stays sane.)
    always @(posedge wclk) if (wrst_n) begin
        assert (!(occupancy > DEPTH))
            else $error("[%0t] occupancy exceeded DEPTH", $time);
    end

    // ==========================================================================
    // Functional coverage (Vivado xsim: compile with +define+ENABLE_COVERAGE)
    // ==========================================================================
`ifdef ENABLE_COVERAGE
    covergroup cg_fill @(posedge wclk);
        option.per_instance = 1;
        fill_level: coverpoint occupancy {
            bins empty      = {0};
            bins low        = {[1:DEPTH/4]};
            bins mid        = {[DEPTH/4 + 1 : 3*DEPTH/4 - 1]};
            bins high       = {[3*DEPTH/4 : DEPTH-1]};
            bins full       = {DEPTH};
        }
    endgroup

    covergroup cg_corners @(posedge wclk);
        option.per_instance = 1;
        wr_en:  coverpoint winc;
        full:   coverpoint wfull;
        // simultaneous write-attempt while full (back-pressure corner)
        wr_x_full: cross wr_en, full;
    endgroup

    covergroup cg_rd_corners @(posedge rclk);
        option.per_instance = 1;
        rd_en:  coverpoint rinc;
        empty:  coverpoint rempty;
        // simultaneous read-attempt while empty (starvation corner)
        rd_x_empty: cross rd_en, empty;
    endgroup

    cg_fill        cov_fill    = new();
    cg_corners     cov_corner  = new();
    cg_rd_corners  cov_rdcorn  = new();
`endif

    // ---- End-of-test ---------------------------------------------------------
    initial begin
        wait (n_written >= NUM_ITEMS && n_read >= NUM_ITEMS);
        repeat (10) @(posedge rclk);
        $display("------------------------------------------------------------");
        $display("  async_fifo test complete");
        $display("    items written : %0d", n_written);
        $display("    items read    : %0d", n_read);
        $display("    errors        : %0d", errors);
`ifdef ENABLE_COVERAGE
        $display("    fill coverage : %0.2f%%", cov_fill.get_inst_coverage());
`endif
        if (errors == 0 && n_read == NUM_ITEMS)
            $display("  RESULT: PASS");
        else
            $display("  RESULT: FAIL");
        $display("------------------------------------------------------------");
        $finish;
    end

    // ---- Watchdog ------------------------------------------------------------
    initial begin
        #(NUM_ITEMS * 50ns + 100000ns);
        $error("[%0t] TIMEOUT watchdog fired (wrote %0d, read %0d)",
               $time, n_written, n_read);
        $finish;
    end

endmodule

`default_nettype wire
