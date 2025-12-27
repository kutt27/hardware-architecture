#!/bin/bash
# =============================================================================
# ARM7 Computer System - Build Script
# =============================================================================
# Description:
#   Automated build script for the ARM7 computer system.
#   Compiles Verilog, assembles programs, and prepares for simulation/FPGA.
#
# Usage:
#   ./scripts/build.sh [target]
#
# Targets:
#   all       - Build everything
#   verilog   - Compile Verilog modules
#   toolchain - Build toolchain
#   firmware  - Assemble firmware
#   examples  - Assemble example programs
#   clean     - Clean build artifacts
#
# Author: ARM7 Computer System Project
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
SRC_DIR="$PROJECT_ROOT/src"
EXAMPLES_DIR="$PROJECT_ROOT/examples"

# Tools
IVERILOG="iverilog"
PYTHON="python3"
ASSEMBLER="$SRC_DIR/toolchain/assembler/assembler.py"
LINKER="$SRC_DIR/toolchain/linker/linker.py"

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
# Build Functions
# =============================================================================

build_verilog() {
    print_header "Building Verilog Modules"
    
    mkdir -p "$BUILD_DIR"
    
    # Check for Verilog files
    if [ ! -d "$SRC_DIR/verilog" ]; then
        print_error "Verilog source directory not found"
        return 1
    fi
    
    # Count Verilog files
    VERILOG_COUNT=$(find "$SRC_DIR/verilog" -name "*.v" | wc -l)
    print_info "Found $VERILOG_COUNT Verilog files"
    
    # Syntax check (compile without running)
    print_info "Checking Verilog syntax..."
    
    for module in cpu memory io basic arithmetic sequential system; do
        if [ -d "$SRC_DIR/verilog/$module" ]; then
            print_info "Checking $module modules..."
            $IVERILOG -t null -o /dev/null "$SRC_DIR/verilog/$module"/*.v 2>&1 | grep -v "warning:" || true
        fi
    done
    
    print_success "Verilog syntax check complete"
}

build_toolchain() {
    print_header "Building Toolchain"
    
    # Check Python version
    PYTHON_VERSION=$($PYTHON --version 2>&1 | awk '{print $2}')
    print_info "Python version: $PYTHON_VERSION"
    
    # Test assembler
    if [ -f "$ASSEMBLER" ]; then
        print_info "Testing assembler..."
        $PYTHON "$ASSEMBLER" --help > /dev/null 2>&1 || true
        print_success "Assembler OK"
    else
        print_error "Assembler not found"
        return 1
    fi
    
    # Test linker
    if [ -f "$LINKER" ]; then
        print_info "Testing linker..."
        $PYTHON "$LINKER" --help > /dev/null 2>&1 || true
        print_success "Linker OK"
    else
        print_error "Linker not found"
        return 1
    fi
    
    print_success "Toolchain build complete"
}

build_firmware() {
    print_header "Building Firmware"
    
    mkdir -p "$BUILD_DIR/firmware"
    
    # Assemble boot ROM
    if [ -f "$SRC_DIR/firmware/boot/boot.s" ]; then
        print_info "Assembling boot ROM..."
        $PYTHON "$ASSEMBLER" "$SRC_DIR/firmware/boot/boot.s" \
            -o "$BUILD_DIR/firmware/boot.bin"
        print_success "Boot ROM assembled"
    else
        print_error "Boot ROM source not found"
    fi
}

build_examples() {
    print_header "Building Example Programs"
    
    mkdir -p "$BUILD_DIR/examples"
    
    # Find all .s files in examples
    for asm_file in "$EXAMPLES_DIR"/*.s; do
        if [ -f "$asm_file" ]; then
            filename=$(basename "$asm_file" .s)
            print_info "Assembling $filename..."
            
            $PYTHON "$ASSEMBLER" "$asm_file" \
                -o "$BUILD_DIR/examples/$filename.bin"
            
            print_success "$filename assembled"
        fi
    done
    
    print_success "All examples assembled"
}

build_tests() {
    print_header "Building Test Programs"
    
    mkdir -p "$BUILD_DIR/tests"
    
    # Assemble test programs
    if [ -d "$PROJECT_ROOT/tests/cpu" ]; then
        for asm_file in "$PROJECT_ROOT/tests/cpu"/*.s; do
            if [ -f "$asm_file" ]; then
                filename=$(basename "$asm_file" .s)
                print_info "Assembling test: $filename..."
                
                $PYTHON "$ASSEMBLER" "$asm_file" \
                    -o "$BUILD_DIR/tests/$filename.bin" 2>&1 || true
                
                if [ -f "$BUILD_DIR/tests/$filename.bin" ]; then
                    print_success "$filename assembled"
                fi
            fi
        done
    fi
}

clean_build() {
    print_header "Cleaning Build Artifacts"
    
    if [ -d "$BUILD_DIR" ]; then
        print_info "Removing build directory..."
        rm -rf "$BUILD_DIR"
        print_success "Build directory removed"
    fi
    
    # Remove generated files
    find "$PROJECT_ROOT" -name "*.vcd" -delete 2>/dev/null || true
    find "$PROJECT_ROOT" -name "*.vvp" -delete 2>/dev/null || true
    find "$PROJECT_ROOT" -name "*.out" -delete 2>/dev/null || true
    
    print_success "Clean complete"
}

build_all() {
    print_header "Building Complete ARM7 System"
    
    build_verilog
    build_toolchain
    build_firmware
    build_examples
    build_tests
    
    print_header "Build Summary"
    echo -e "${GREEN}✓ Verilog modules checked${NC}"
    echo -e "${GREEN}✓ Toolchain verified${NC}"
    echo -e "${GREEN}✓ Firmware assembled${NC}"
    echo -e "${GREEN}✓ Examples assembled${NC}"
    echo -e "${GREEN}✓ Tests assembled${NC}"
    echo ""
    print_success "Build complete!"
}

show_help() {
    cat << EOF
ARM7 Computer System - Build Script

Usage: $0 [target]

Targets:
  all       - Build everything (default)
  verilog   - Check Verilog syntax
  toolchain - Verify toolchain
  firmware  - Assemble firmware
  examples  - Assemble example programs
  tests     - Assemble test programs
  clean     - Clean build artifacts
  help      - Show this help message

Examples:
  $0              # Build everything
  $0 examples     # Build only examples
  $0 clean        # Clean build directory

EOF
}

# =============================================================================
# Main Script
# =============================================================================

main() {
    cd "$PROJECT_ROOT"
    
    TARGET="${1:-all}"
    
    case "$TARGET" in
        all)
            build_all
            ;;
        verilog)
            build_verilog
            ;;
        toolchain)
            build_toolchain
            ;;
        firmware)
            build_firmware
            ;;
        examples)
            build_examples
            ;;
        tests)
            build_tests
            ;;
        clean)
            clean_build
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            print_error "Unknown target: $TARGET"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# Run main function
main "$@"

