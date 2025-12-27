# =============================================================================
# ARM7 Computer System - FPGA Programming Script
# =============================================================================
# Usage: vivado -mode batch -source program.tcl
# =============================================================================

# Open hardware manager
open_hw_manager

# Connect to hardware server
connect_hw_server -allow_non_jtag

# Auto-detect target
open_hw_target

# Get the device
set device [lindex [get_hw_devices] 0]
current_hw_device $device

# Set bitstream file
set_property PROGRAM.FILE {arm7_computer.bit} $device

# Program the device
puts "Programming FPGA..."
program_hw_devices $device

# Verify
refresh_hw_device $device

puts "Programming complete!"

# Close
close_hw_target
disconnect_hw_server
close_hw_manager

