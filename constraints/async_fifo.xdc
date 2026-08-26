# =============================================================================
# async_fifo.xdc : Timing constraints for the asynchronous FIFO.
#
# The write and read domains are driven by unrelated clocks. These constraints
# tell the tools so, which keeps timing analysis honest and lets report_cdc
# classify the Gray-pointer crossings (through the 2-flop synchronizers) as
# safe rather than flagging them as unconstrained or failing paths.
#
# The periods below are representative -- edit them to your real board clocks.
# =============================================================================

# ---- Clocks -----------------------------------------------------------------
# Write domain: 200 MHz (5.000 ns).  Read domain: ~142.9 MHz (7.000 ns).
create_clock -name wclk -period 5.000 [get_ports wclk]
create_clock -name rclk -period 7.000 [get_ports rclk]

# ---- Declare the two domains asynchronous -----------------------------------
# No phase relationship exists between wclk and rclk, so do not attempt to meet
# setup/hold between them. This is the constraint report_cdc keys on to treat
# the pointer paths as genuine clock-domain crossings.
set_clock_groups -asynchronous \
    -group [get_clocks wclk] \
    -group [get_clocks rclk]

# ---- Bound the crossing skew ------------------------------------------------
# Even though the domains are asynchronous, the bits of each Gray pointer must
# still land in the destination within a single destination-clock period, so a
# single-bit Gray transition is never split across two captures. Constrain the
# path from each source pointer flop to the first synchronizer flop, using the
# tighter of the two periods as the datapath-only bound.
#
# datapath_only ignores the (nonexistent) clock relationship and checks only
# the physical route + logic delay.

# write gray pointer (wclk) -> first sync flop in the read domain
set_max_delay -datapath_only 5.000 \
    -from [get_cells -hierarchical -filter {NAME =~ *u_wptr_full/wptr_reg*}] \
    -to   [get_cells -hierarchical -filter {NAME =~ *sync_w2r/sync_ff1_reg*}]

# read gray pointer (rclk) -> first sync flop in the write domain
set_max_delay -datapath_only 5.000 \
    -from [get_cells -hierarchical -filter {NAME =~ *u_rptr_empty/rptr_reg*}] \
    -to   [get_cells -hierarchical -filter {NAME =~ *sync_r2w/sync_ff1_reg*}]
