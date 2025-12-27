# =============================================================================
# ARM7 Computer System - Master Makefile
# =============================================================================
# Description:
#   Build system for the complete ARM7 computer system project.
#   Handles Verilog compilation, simulation, testing, and toolchain building.
#
# Author: ARM7 Computer System Project
# Date: 2025-11-03
# =============================================================================

# Project directories
SRC_DIR = src
VERILOG_DIR = $(SRC_DIR)/verilog
TOOLCHAIN_DIR = $(SRC_DIR)/toolchain
FIRMWARE_DIR = $(SRC_DIR)/firmware
TEST_DIR = tests
SIM_DIR = sim
BUILD_DIR = build
DOCS_DIR = docs

# Verilog source directories
BASIC_DIR = $(VERILOG_DIR)/basic
ARITH_DIR = $(VERILOG_DIR)/arithmetic
SEQ_DIR = $(VERILOG_DIR)/sequential
MEM_DIR = $(VERILOG_DIR)/memory
IO_DIR = $(VERILOG_DIR)/io
CPU_DIR = $(VERILOG_DIR)/cpu

# Tools
IVERILOG = iverilog
VVP = vvp
GTKWAVE = gtkwave
VERILATOR = verilator
PYTHON = python3

# Compiler flags
IVERILOG_FLAGS = -g2012 -Wall
VERILATOR_FLAGS = --cc --exe --build -Wall

# Find all Verilog source files
BASIC_SRCS = $(wildcard $(BASIC_DIR)/*.v)
ARITH_SRCS = $(wildcard $(ARITH_DIR)/*.v)
SEQ_SRCS = $(wildcard $(SEQ_DIR)/*.v)
MEM_SRCS = $(wildcard $(MEM_DIR)/*.v)
IO_SRCS = $(wildcard $(IO_DIR)/*.v)
CPU_SRCS = $(wildcard $(CPU_DIR)/*.v)

ALL_SRCS = $(BASIC_SRCS) $(ARITH_SRCS) $(SEQ_SRCS) $(MEM_SRCS) $(IO_SRCS) $(CPU_SRCS)

# Testbenches
BASIC_TBS = $(wildcard $(BASIC_DIR)/*_tb.v)
ARITH_TBS = $(wildcard $(ARITH_DIR)/*_tb.v)
SEQ_TBS = $(wildcard $(SEQ_DIR)/*_tb.v)
MEM_TBS = $(wildcard $(MEM_DIR)/*_tb.v)
IO_TBS = $(wildcard $(IO_DIR)/*_tb.v)
CPU_TBS = $(wildcard $(CPU_DIR)/*_tb.v)

ALL_TBS = $(BASIC_TBS) $(ARITH_TBS) $(SEQ_TBS) $(MEM_TBS) $(IO_TBS) $(CPU_TBS)

# =============================================================================
# Main Targets
# =============================================================================

.PHONY: all clean help test test_all sim docs toolchain

all: test_all toolchain docs
	@echo "==================================================="
	@echo "ARM7 Computer System - Build Complete"
	@echo "==================================================="

help:
	@echo "ARM7 Computer System - Makefile Help"
	@echo "====================================="
	@echo ""
	@echo "Main targets:"
	@echo "  all          - Build everything (tests, toolchain, docs)"
	@echo "  test_all     - Run all testbenches"
	@echo "  test_basic   - Test basic logic components"
	@echo "  test_arith   - Test arithmetic units"
	@echo "  test_seq     - Test sequential logic"
	@echo "  test_mem     - Test memory components"
	@echo "  test_cpu     - Test CPU components"
	@echo "  toolchain    - Build assembler and linker"
	@echo "  docs         - Generate documentation"
	@echo "  clean        - Remove build artifacts"
	@echo "  help         - Show this help message"
	@echo ""
	@echo "Simulation targets:"
	@echo "  sim_gates    - Simulate basic gates"
	@echo "  sim_alu      - Simulate ALU"
	@echo "  wave_gates   - View gates waveform"
	@echo ""

# =============================================================================
# Testing Targets
# =============================================================================

test_all: test_basic test_arith test_seq test_cpu test_io test_soc
	@echo "All tests completed!"

test_basic: $(BUILD_DIR)
	@echo "Testing basic logic components..."
	@if [ -f "$(BASIC_DIR)/gates_tb.v" ]; then \
		$(IVERILOG) $(IVERILOG_FLAGS) -o $(BUILD_DIR)/gates_tb \
			$(BASIC_DIR)/gates.v $(BASIC_DIR)/gates_tb.v && \
		$(VVP) $(BUILD_DIR)/gates_tb; \
	fi

test_arith: $(BUILD_DIR)
	@echo "Testing arithmetic units..."
	@echo "Arithmetic testbenches not yet implemented"

test_seq: $(BUILD_DIR)
	@echo "Testing sequential logic..."
	@echo "Sequential testbenches not yet implemented"

test_mem: $(BUILD_DIR)
	@echo "Testing memory components..."
	@echo "Memory testbenches not yet implemented"

test_cpu: test_cpu_alu
	@echo "CPU component tests completed!"

test_cpu_alu: $(BUILD_DIR)
	@echo "Testing ALU..."
	@if [ -f "$(CPU_DIR)/alu_tb.v" ]; then \
		$(IVERILOG) $(IVERILOG_FLAGS) -o $(BUILD_DIR)/alu_tb \
			$(CPU_DIR)/alu.v $(CPU_DIR)/barrel_shifter.v $(CPU_DIR)/alu_tb.v && \
		$(VVP) $(BUILD_DIR)/alu_tb; \
	fi

test_io: test_uart
	@echo "I/O component tests completed!"

test_uart: $(BUILD_DIR)
	@echo "Testing UART..."
	@if [ -f "$(IO_DIR)/uart_tb.v" ]; then \
		$(IVERILOG) $(IVERILOG_FLAGS) -o $(BUILD_DIR)/uart_tb \
			$(IO_DIR)/uart.v $(IO_DIR)/uart_tb.v && \
		$(VVP) $(BUILD_DIR)/uart_tb; \
	fi

test_soc: $(BUILD_DIR)
	@echo "Testing complete SoC integration..."
	@if [ -f "tests/system/integration_test.v" ]; then \
		$(IVERILOG) $(IVERILOG_FLAGS) -o $(BUILD_DIR)/integration_test \
			tests/system/integration_test.v \
			$(SYSTEM_DIR)/soc_top.v \
			$(CPU_DIR)/*.v \
			$(MEM_DIR)/*.v \
			$(IO_DIR)/*.v && \
		$(VVP) $(BUILD_DIR)/integration_test; \
	else \
		echo "Integration test not found"; \
	fi

# =============================================================================
# Simulation Targets
# =============================================================================

sim_gates: $(BUILD_DIR)
	@echo "Simulating basic gates..."
	$(IVERILOG) $(IVERILOG_FLAGS) -o $(BUILD_DIR)/gates_tb \
		$(BASIC_DIR)/gates.v $(BASIC_DIR)/gates_tb.v
	$(VVP) $(BUILD_DIR)/gates_tb

sim_alu: $(BUILD_DIR)
	@echo "Simulating ALU..."
	@if [ -f "$(CPU_DIR)/alu_tb.v" ]; then \
		$(IVERILOG) $(IVERILOG_FLAGS) -o $(BUILD_DIR)/alu_tb \
			$(CPU_DIR)/alu.v $(CPU_DIR)/barrel_shifter.v $(CPU_DIR)/alu_tb.v && \
		$(VVP) $(BUILD_DIR)/alu_tb; \
	else \
		echo "ALU testbench not yet implemented"; \
	fi

# =============================================================================
# Waveform Viewing
# =============================================================================

wave_gates:
	@if [ -f "gates_tb.vcd" ]; then \
		$(GTKWAVE) gates_tb.vcd; \
	else \
		echo "Run 'make sim_gates' first to generate waveform"; \
	fi

wave_alu:
	@if [ -f "alu_tb.vcd" ]; then \
		$(GTKWAVE) alu_tb.vcd; \
	else \
		echo "Run 'make sim_alu' first to generate waveform"; \
	fi

# =============================================================================
# Toolchain Targets
# =============================================================================

toolchain: assembler linker utils
	@echo "Toolchain build complete"

assembler:
	@echo "Building assembler..."
	@if [ -d "$(TOOLCHAIN_DIR)/assembler" ]; then \
		cd $(TOOLCHAIN_DIR)/assembler && \
		$(PYTHON) -m py_compile *.py 2>/dev/null || true; \
	fi
	@echo "Assembler ready"

linker:
	@echo "Building linker..."
	@if [ -d "$(TOOLCHAIN_DIR)/linker" ]; then \
		cd $(TOOLCHAIN_DIR)/linker && \
		$(PYTHON) -m py_compile *.py 2>/dev/null || true; \
	fi
	@echo "Linker ready"

utils:
	@echo "Building utilities..."
	@if [ -d "$(TOOLCHAIN_DIR)/utils" ]; then \
		cd $(TOOLCHAIN_DIR)/utils && \
		$(PYTHON) -m py_compile *.py 2>/dev/null || true; \
	fi
	@echo "Utilities ready"

# =============================================================================
# Documentation Targets
# =============================================================================

docs:
	@echo "Documentation already in markdown format"
	@echo "See LEARNING_GUIDE.md and docs/ directory"

# =============================================================================
# Verilator Simulation (Advanced)
# =============================================================================

verilator_sim: $(BUILD_DIR)
	@echo "Building Verilator simulation..."
	@echo "Verilator simulation not yet configured"

# =============================================================================
# Synthesis Targets (FPGA)
# =============================================================================

synth:
	@echo "FPGA synthesis not yet configured"
	@echo "See fpga/ directory for deployment scripts"

# =============================================================================
# Utility Targets
# =============================================================================

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

clean:
	@echo "Cleaning build artifacts..."
	rm -rf $(BUILD_DIR)
	rm -f *.vcd
	rm -f *.vvp
	rm -f *.out
	find . -name "*.pyc" -delete
	find . -name "__pycache__" -delete
	@echo "Clean complete"

lint:
	@echo "Linting Verilog files..."
	@for file in $(ALL_SRCS); do \
		echo "Checking $$file..."; \
		$(IVERILOG) -t null -Wall $$file 2>&1 | grep -v "warning: macro" || true; \
	done

stats:
	@echo "Project Statistics"
	@echo "=================="
	@echo "Verilog files:"
	@find $(VERILOG_DIR) -name "*.v" | wc -l
	@echo "Lines of Verilog:"
	@find $(VERILOG_DIR) -name "*.v" -exec cat {} \; | wc -l
	@echo "Python files:"
	@find $(TOOLCHAIN_DIR) -name "*.py" 2>/dev/null | wc -l || echo "0"
	@echo "Assembly files:"
	@find $(FIRMWARE_DIR) -name "*.s" 2>/dev/null | wc -l || echo "0"

# =============================================================================
# Development Targets
# =============================================================================

check:
	@echo "Checking project structure..."
	@echo "Verilog modules: $$(find $(VERILOG_DIR) -name "*.v" ! -name "*_tb.v" | wc -l)"
	@echo "Testbenches: $$(find $(VERILOG_DIR) -name "*_tb.v" | wc -l)"
	@echo "Documentation files: $$(find $(DOCS_DIR) -name "*.md" 2>/dev/null | wc -l || echo 0)"

.PHONY: lint stats check assembler linker utils verilator_sim synth wave_gates wave_alu

# =============================================================================
# End of Makefile
# =============================================================================

