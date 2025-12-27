# =============================================================================
# ARM7 Computer System - FPGA Constraints File
# =============================================================================
# Target: Xilinx Artix-7 / Spartan-7 / Zynq-7000 (Basys3, Arty, etc.)
# Modify pin assignments based on your specific board
# =============================================================================

# =============================================================================
# Clock and Reset
# =============================================================================

# 100 MHz system clock (modify for your board)
set_property -dict { PACKAGE_PIN W5 IOSTANDARD LVCMOS33 } [get_ports clk]
create_clock -period 10.000 -name sys_clk_pin -waveform {0.000 5.000} -add [get_ports clk]

# Reset button (active high)
set_property -dict { PACKAGE_PIN U18 IOSTANDARD LVCMOS33 } [get_ports rst]

# =============================================================================
# UART Interface
# =============================================================================

# UART TX (FPGA -> PC)
set_property -dict { PACKAGE_PIN A18 IOSTANDARD LVCMOS33 } [get_ports uart_tx]

# UART RX (PC -> FPGA)
set_property -dict { PACKAGE_PIN B18 IOSTANDARD LVCMOS33 } [get_ports uart_rx]

# =============================================================================
# GPIO - LEDs (16 bits)
# =============================================================================

set_property -dict { PACKAGE_PIN U16 IOSTANDARD LVCMOS33 } [get_ports {gpio_out[0]}]
set_property -dict { PACKAGE_PIN E19 IOSTANDARD LVCMOS33 } [get_ports {gpio_out[1]}]
set_property -dict { PACKAGE_PIN U19 IOSTANDARD LVCMOS33 } [get_ports {gpio_out[2]}]
set_property -dict { PACKAGE_PIN V19 IOSTANDARD LVCMOS33 } [get_ports {gpio_out[3]}]
set_property -dict { PACKAGE_PIN W18 IOSTANDARD LVCMOS33 } [get_ports {gpio_out[4]}]
set_property -dict { PACKAGE_PIN U15 IOSTANDARD LVCMOS33 } [get_ports {gpio_out[5]}]
set_property -dict { PACKAGE_PIN U14 IOSTANDARD LVCMOS33 } [get_ports {gpio_out[6]}]
set_property -dict { PACKAGE_PIN V14 IOSTANDARD LVCMOS33 } [get_ports {gpio_out[7]}]
set_property -dict { PACKAGE_PIN V13 IOSTANDARD LVCMOS33 } [get_ports {gpio_out[8]}]
set_property -dict { PACKAGE_PIN V3  IOSTANDARD LVCMOS33 } [get_ports {gpio_out[9]}]
set_property -dict { PACKAGE_PIN W3  IOSTANDARD LVCMOS33 } [get_ports {gpio_out[10]}]
set_property -dict { PACKAGE_PIN U3  IOSTANDARD LVCMOS33 } [get_ports {gpio_out[11]}]
set_property -dict { PACKAGE_PIN P3  IOSTANDARD LVCMOS33 } [get_ports {gpio_out[12]}]
set_property -dict { PACKAGE_PIN N3  IOSTANDARD LVCMOS33 } [get_ports {gpio_out[13]}]
set_property -dict { PACKAGE_PIN P1  IOSTANDARD LVCMOS33 } [get_ports {gpio_out[14]}]
set_property -dict { PACKAGE_PIN L1  IOSTANDARD LVCMOS33 } [get_ports {gpio_out[15]}]

# =============================================================================
# GPIO - Switches (16 bits input)
# =============================================================================

set_property -dict { PACKAGE_PIN V17 IOSTANDARD LVCMOS33 } [get_ports {gpio_in[0]}]
set_property -dict { PACKAGE_PIN V16 IOSTANDARD LVCMOS33 } [get_ports {gpio_in[1]}]
set_property -dict { PACKAGE_PIN W16 IOSTANDARD LVCMOS33 } [get_ports {gpio_in[2]}]
set_property -dict { PACKAGE_PIN W17 IOSTANDARD LVCMOS33 } [get_ports {gpio_in[3]}]
set_property -dict { PACKAGE_PIN W15 IOSTANDARD LVCMOS33 } [get_ports {gpio_in[4]}]
set_property -dict { PACKAGE_PIN V15 IOSTANDARD LVCMOS33 } [get_ports {gpio_in[5]}]
set_property -dict { PACKAGE_PIN W14 IOSTANDARD LVCMOS33 } [get_ports {gpio_in[6]}]
set_property -dict { PACKAGE_PIN W13 IOSTANDARD LVCMOS33 } [get_ports {gpio_in[7]}]
set_property -dict { PACKAGE_PIN V2  IOSTANDARD LVCMOS33 } [get_ports {gpio_in[8]}]
set_property -dict { PACKAGE_PIN T3  IOSTANDARD LVCMOS33 } [get_ports {gpio_in[9]}]
set_property -dict { PACKAGE_PIN T2  IOSTANDARD LVCMOS33 } [get_ports {gpio_in[10]}]
set_property -dict { PACKAGE_PIN R3  IOSTANDARD LVCMOS33 } [get_ports {gpio_in[11]}]
set_property -dict { PACKAGE_PIN W2  IOSTANDARD LVCMOS33 } [get_ports {gpio_in[12]}]
set_property -dict { PACKAGE_PIN U1  IOSTANDARD LVCMOS33 } [get_ports {gpio_in[13]}]
set_property -dict { PACKAGE_PIN T1  IOSTANDARD LVCMOS33 } [get_ports {gpio_in[14]}]
set_property -dict { PACKAGE_PIN R2  IOSTANDARD LVCMOS33 } [get_ports {gpio_in[15]}]

# =============================================================================
# Timing Constraints
# =============================================================================

# Input delays (relative to clock)
set_input_delay -clock [get_clocks sys_clk_pin] -min 0.000 [get_ports uart_rx]
set_input_delay -clock [get_clocks sys_clk_pin] -max 2.000 [get_ports uart_rx]
set_input_delay -clock [get_clocks sys_clk_pin] -min 0.000 [get_ports gpio_in[*]]
set_input_delay -clock [get_clocks sys_clk_pin] -max 2.000 [get_ports gpio_in[*]]

# Output delays (relative to clock)
set_output_delay -clock [get_clocks sys_clk_pin] -min 0.000 [get_ports uart_tx]
set_output_delay -clock [get_clocks sys_clk_pin] -max 2.000 [get_ports uart_tx]
set_output_delay -clock [get_clocks sys_clk_pin] -min 0.000 [get_ports gpio_out[*]]
set_output_delay -clock [get_clocks sys_clk_pin] -max 2.000 [get_ports gpio_out[*]]

# False paths for asynchronous inputs
set_false_path -from [get_ports rst]
set_false_path -from [get_ports gpio_in[*]]

# =============================================================================
# Configuration
# =============================================================================

# Configuration voltage
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]

# Bitstream settings
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 33 [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]

# =============================================================================
# Notes for Different Boards
# =============================================================================
# 
# BASYS3 (Artix-7):
#   - Clock: W5 (100 MHz)
#   - Use pin assignments above
#
# ARTY A7:
#   - Clock: E3 (100 MHz)
#   - Modify UART pins: D10 (TX), A9 (RX)
#
# NEXYS A7:
#   - Clock: E3 (100 MHz)
#   - Similar to Basys3 pinout
#
# ZYBO Z7:
#   - Clock: K17 (125 MHz) - adjust clock period to 8.000 ns
#   - Different GPIO/LED pins
#
# =============================================================================

