#!/bin/bash
# =============================================================================
# ARM7 Computer System - Test Runner Script
# =============================================================================
# Description:
#   Automated test runner for the ARM7 computer system.
#   Runs all testbenches and reports results.
#
# Usage:
#   ./scripts/run_tests.sh [category]
#
# Categories:
#   all       - Run all tests (default)
#   basic     - Basic logic tests
#   cpu       - CPU tests
#   memory    - Memory tests
#   io        - I/O peripheral tests
#   system    - System integration tests
#
# Author: Amal Satheesan
# Date: 2025-11-03
# =============================================================================

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Directories
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/build"
SRC_DIR="$PROJECT_ROOT/src/verilog"
TESTS_DIR="$PROJECT_ROOT/tests"

# Tools
IVERILOG="iverilog"
VVP="vvp"

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# =============================================================================
# Helper Functions
# =============================================================================

print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}→ $1${NC}"
}

# =============================================================================
# Test Runner Function
# =============================================================================

run_test() {
    local test_name=$1
    local dut_file=$2
    local tb_file=$3
    local extra_files=$4
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    print_info "Running: $test_name"
    
    # Create build directory
    mkdir -p "$BUILD_DIR/tests"
    
    # Compile
    local compile_cmd="$IVERILOG -o $BUILD_DIR/tests/${test_name}.vvp"
    
    if [ -n "$extra_files" ]; then
        compile_cmd="$compile_cmd $extra_files"
    fi
    
    compile_cmd="$compile_cmd $dut_file $tb_file"
    
    if $compile_cmd 2>&1 | tee "$BUILD_DIR/tests/${test_name}_compile.log" | grep -i "error" > /dev/null; then
        print_error "$test_name - Compilation failed"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi
    
    # Run simulation
    if $VVP "$BUILD_DIR/tests/${test_name}.vvp" > "$BUILD_DIR/tests/${test_name}_run.log" 2>&1; then
        # Check for test failures in output
        if grep -i "fail\|error" "$BUILD_DIR/tests/${test_name}_run.log" > /dev/null; then
            print_error "$test_name - Test failed"
            FAILED_TESTS=$((FAILED_TESTS + 1))
            cat "$BUILD_DIR/tests/${test_name}_run.log"
            return 1
        else
            print_success "$test_name - Passed"
            PASSED_TESTS=$((PASSED_TESTS + 1))
            return 0
        fi
    else
        print_error "$test_name - Simulation error"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi
}

# =============================================================================
# Test Categories
# =============================================================================

test_basic() {
    print_header "Testing Basic Logic Components"
    
    # Test ALU
    if [ -f "$SRC_DIR/cpu/alu.v" ] && [ -f "$SRC_DIR/cpu/alu_tb.v" ]; then
        run_test "alu" \
            "$SRC_DIR/cpu/alu.v" \
            "$SRC_DIR/cpu/alu_tb.v" \
            ""
    fi
    
    # Test Barrel Shifter
    if [ -f "$SRC_DIR/cpu/barrel_shifter.v" ]; then
        # Note: barrel_shifter_tb.v might not exist yet
        print_info "Barrel shifter test not available"
    fi
}

test_cpu() {
    print_header "Testing CPU Components"
    
    # Test ALU
    if [ -f "$SRC_DIR/cpu/alu.v" ] && [ -f "$SRC_DIR/cpu/alu_tb.v" ]; then
        run_test "cpu_alu" \
            "$SRC_DIR/cpu/alu.v" \
            "$SRC_DIR/cpu/alu_tb.v" \
            ""
    fi
    
    # Test CPU Top
    if [ -f "$SRC_DIR/cpu/cpu_top.v" ] && [ -f "$SRC_DIR/cpu/cpu_tb.v" ]; then
        # Collect all CPU dependencies
        local cpu_files=$(find "$SRC_DIR/cpu" -name "*.v" ! -name "*_tb.v" | tr '\n' ' ')
        local mem_files=$(find "$SRC_DIR/memory" -name "*.v" ! -name "*_tb.v" | tr '\n' ' ')
        
        run_test "cpu_top" \
            "$SRC_DIR/cpu/cpu_top.v" \
            "$SRC_DIR/cpu/cpu_tb.v" \
            "$cpu_files $mem_files"
    fi
}

test_memory() {
    print_header "Testing Memory Components"
    
    # Test Single-Port RAM
    if [ -f "$SRC_DIR/memory/sp_ram.v" ]; then
        print_info "Single-port RAM test not available"
    fi
    
    # Test Dual-Port RAM
    if [ -f "$SRC_DIR/memory/dp_ram.v" ]; then
        print_info "Dual-port RAM test not available"
    fi
    
    # Test ROM
    if [ -f "$SRC_DIR/memory/rom.v" ]; then
        print_info "ROM test not available"
    fi
}

test_io() {
    print_header "Testing I/O Peripherals"
    
    # Test UART
    if [ -f "$SRC_DIR/io/uart.v" ] && [ -f "$SRC_DIR/io/uart_tb.v" ]; then
        run_test "uart" \
            "$SRC_DIR/io/uart.v" \
            "$SRC_DIR/io/uart_tb.v" \
            ""
    fi
    
    # Test GPIO
    if [ -f "$SRC_DIR/io/gpio.v" ]; then
        print_info "GPIO test not available"
    fi
}

test_system() {
    print_header "Testing System Integration"
    
    # Test SoC Integration
    if [ -f "$SRC_DIR/system/soc_top.v" ] && [ -f "$TESTS_DIR/system/integration_test.v" ]; then
        # Collect all dependencies
        local all_files=$(find "$SRC_DIR" -name "*.v" ! -name "*_tb.v" | tr '\n' ' ')
        
        run_test "soc_integration" \
            "$SRC_DIR/system/soc_top.v" \
            "$TESTS_DIR/system/integration_test.v" \
            "$all_files"
    fi
}

test_all() {
    print_header "Running All Tests"
    
    test_basic
    test_cpu
    test_memory
    test_io
    test_system
}

# =============================================================================
# Test Summary
# =============================================================================

print_summary() {
    print_header "Test Summary"
    
    echo -e "Total Tests:  ${BLUE}$TOTAL_TESTS${NC}"
    echo -e "Passed:       ${GREEN}$PASSED_TESTS${NC}"
    echo -e "Failed:       ${RED}$FAILED_TESTS${NC}"
    echo ""
    
    if [ $FAILED_TESTS -eq 0 ]; then
        echo -e "${GREEN}✓✓✓ ALL TESTS PASSED ✓✓✓${NC}"
        return 0
    else
        echo -e "${RED}✗✗✗ SOME TESTS FAILED ✗✗✗${NC}"
        return 1
    fi
}

# =============================================================================
# Help
# =============================================================================

show_help() {
    cat << EOF
ARM7 Computer System - Test Runner

Usage: $0 [category]

Categories:
  all       - Run all tests (default)
  basic     - Basic logic tests
  cpu       - CPU tests
  memory    - Memory tests
  io        - I/O peripheral tests
  system    - System integration tests

Examples:
  $0              # Run all tests
  $0 cpu          # Run only CPU tests
  $0 system       # Run only system tests

EOF
}

# =============================================================================
# Main Script
# =============================================================================

main() {
    cd "$PROJECT_ROOT"
    
    CATEGORY="${1:-all}"
    
    # Check for required tools
    if ! command -v $IVERILOG &> /dev/null; then
        print_error "iverilog not found. Please install Icarus Verilog."
        exit 1
    fi
    
    case "$CATEGORY" in
        all)
            test_all
            ;;
        basic)
            test_basic
            ;;
        cpu)
            test_cpu
            ;;
        memory)
            test_memory
            ;;
        io)
            test_io
            ;;
        system)
            test_system
            ;;
        help|--help|-h)
            show_help
            exit 0
            ;;
        *)
            print_error "Unknown category: $CATEGORY"
            echo ""
            show_help
            exit 1
            ;;
    esac
    
    echo ""
    print_summary
}

# Run main function
main "$@"

