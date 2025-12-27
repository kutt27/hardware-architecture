# =============================================================================
# ARM7 Computer System - Vivado Build Script
# =============================================================================
# Usage: vivado -mode batch -source build.tcl
# =============================================================================

# Project settings
set project_name "arm7_computer"
set project_dir "./vivado_project"
set top_module "fpga_top"

# Target device (modify for your board)
# Basys3: xc7a35tcpg236-1
# Arty A7-35T: xc7a35ticsg324-1L
# Nexys A7-100T: xc7a100tcsg324-1
set part "xc7a35tcpg236-1"

# =============================================================================
# Create Project
# =============================================================================

puts "Creating project: $project_name"
create_project $project_name $project_dir -part $part -force

# =============================================================================
# Add Source Files
# =============================================================================

puts "Adding source files..."

# FPGA wrapper
add_files fpga_top.v

# SoC top
add_files ../src/verilog/system/soc_top.v

# CPU
add_files ../src/verilog/cpu/cpu_top.v
add_files ../src/verilog/cpu/fetch_stage.v
add_files ../src/verilog/cpu/decode_stage.v
add_files ../src/verilog/cpu/execute_stage.v
add_files ../src/verilog/cpu/memory_stage.v
add_files ../src/verilog/cpu/instruction_decoder.v
add_files ../src/verilog/cpu/hazard_unit.v
add_files ../src/verilog/cpu/alu.v
add_files ../src/verilog/cpu/barrel_shifter.v
add_files ../src/verilog/cpu/icache.v

# Memory
add_files ../src/verilog/memory/sp_ram.v
add_files ../src/verilog/memory/dp_ram.v
add_files ../src/verilog/memory/rom.v

# I/O
add_files ../src/verilog/io/uart.v
add_files ../src/verilog/io/gpio.v

# Basic components
add_files ../src/verilog/basic/gates.v
add_files ../src/verilog/basic/mux.v
add_files ../src/verilog/basic/decoder.v

# Arithmetic
add_files ../src/verilog/arithmetic/adder.v
add_files ../src/verilog/arithmetic/comparator.v

# Sequential
add_files ../src/verilog/sequential/dff.v
add_files ../src/verilog/sequential/register_file.v
add_files ../src/verilog/sequential/counter.v

# =============================================================================
# Add Constraints
# =============================================================================

puts "Adding constraints..."
add_files -fileset constrs_1 constraints.xdc

# =============================================================================
# Set Top Module
# =============================================================================

set_property top $top_module [current_fileset]

# =============================================================================
# Synthesis
# =============================================================================

puts "Running synthesis..."
launch_runs synth_1 -jobs 4
wait_on_run synth_1

# Check for errors
if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {
    puts "ERROR: Synthesis failed!"
    exit 1
}

puts "Synthesis complete!"
open_run synth_1

# Report utilization
report_utilization -file $project_dir/utilization_synth.txt
report_timing_summary -file $project_dir/timing_synth.txt

# =============================================================================
# Implementation
# =============================================================================

puts "Running implementation..."
launch_runs impl_1 -jobs 4
wait_on_run impl_1

# Check for errors
if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
    puts "ERROR: Implementation failed!"
    exit 1
}

puts "Implementation complete!"
open_run impl_1

# Report results
report_utilization -file $project_dir/utilization_impl.txt
report_timing_summary -file $project_dir/timing_impl.txt
report_power -file $project_dir/power.txt

# =============================================================================
# Generate Bitstream
# =============================================================================

puts "Generating bitstream..."
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1

# Check for errors
if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
    puts "ERROR: Bitstream generation failed!"
    exit 1
}

puts "Bitstream generated successfully!"

# Copy bitstream to fpga directory
file copy -force $project_dir/$project_name.runs/impl_1/$top_module.bit ./$project_name.bit

puts "Build complete! Bitstream: $project_name.bit"

# =============================================================================
# Summary
# =============================================================================

puts "\n========================================="
puts "Build Summary"
puts "========================================="
puts "Project: $project_name"
puts "Device: $part"
puts "Bitstream: $project_name.bit"
puts "========================================="
puts "\nTo program the FPGA:"
puts "  1. Open Vivado Hardware Manager"
puts "  2. Connect to your board"
puts "  3. Program with $project_name.bit"
puts "========================================="

