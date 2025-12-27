# FPGA Deployment Guide

This directory contains everything needed to deploy the ARM7 Computer System to real FPGA hardware.

---

## 📋 **Supported Boards**

### **Tested/Recommended:**
- **Digilent Basys3** (Artix-7, xc7a35t) ⭐ Recommended
- **Digilent Arty A7** (Artix-7, xc7a35t/xc7a100t)
- **Digilent Nexys A7** (Artix-7, xc7a100t)
- **Digilent Zybo Z7** (Zynq-7000)

### **Should Work (may need pin changes):**
- Any Xilinx 7-Series FPGA board with:
  - At least 35T device (35,000 logic cells)
  - UART interface
  - 16+ LEDs and switches
  - 100 MHz clock

---

## 🚀 **Quick Start (Vivado)**

### **Step 1: Prerequisites**
```bash
# Install Xilinx Vivado (free WebPACK edition)
# Download from: https://www.xilinx.com/support/download.html
# Version: 2020.1 or later
```

### **Step 2: Modify for Your Board**

Edit `constraints.xdc` and change:
1. **Clock pin** (line 14): Set to your board's clock pin
2. **Device part** in `build.tcl` (line 16): Set to your FPGA part number

**Common boards:**
```tcl
# Basys3
set part "xc7a35tcpg236-1"

# Arty A7-35T
set part "xc7a35ticsg324-1L"

# Nexys A7-100T
set part "xc7a100tcsg324-1"

# Zybo Z7-20
set part "xc7z020clg400-1"
```

### **Step 3: Build**
```bash
cd fpga
vivado -mode batch -source build.tcl
```

This will:
- Create Vivado project
- Run synthesis
- Run implementation
- Generate bitstream: `arm7_computer.bit`

**Build time:** 10-20 minutes

### **Step 4: Program FPGA**

**Option A: Vivado GUI**
```bash
vivado vivado_project/arm7_computer.xpr
# Hardware Manager → Open Target → Auto Connect
# Program Device → arm7_computer.bit
```

**Option B: Command Line**
```bash
vivado -mode batch -source program.tcl
```

---

## 📁 **Files in This Directory**

| File | Description |
|------|-------------|
| `fpga_top.v` | Top-level wrapper for FPGA |
| `constraints.xdc` | Pin assignments and timing constraints |
| `build.tcl` | Automated Vivado build script |
| `program.tcl` | Automated programming script |
| `README.md` | This file |

---

## 🔌 **Hardware Connections**

### **After Programming:**

1. **Reset**: Press reset button to initialize CPU
2. **UART**: Connect USB cable (115200 baud, 8N1)
3. **GPIO**: 
   - **Switches [15:0]**: Input to CPU
   - **LEDs [15:0]**: Output from CPU

### **Testing:**

**Test 1: LED Blink**
```bash
# Upload blink program
python3 ../src/toolchain/assembler/assembler.py test_led.s -o test.bin
# Program via UART bootloader (if implemented)
```

**Test 2: UART Echo**
```bash
# Connect serial terminal
screen /dev/ttyUSB0 115200
# Or: minicom -D /dev/ttyUSB0 -b 115200

# Type characters - should echo back
```

**Test 3: Switch to LED**
```
# Flip switches - LEDs should mirror switch positions
```

---

## ⚙️ **Resource Utilization**

**Expected usage on Artix-7 35T:**

| Resource | Used | Available | Utilization |
|----------|------|-----------|-------------|
| LUTs | ~8,000 | 20,800 | ~38% |
| FFs | ~4,000 | 41,600 | ~10% |
| BRAM | ~20 | 50 | ~40% |
| DSPs | 0 | 90 | 0% |

**Note:** Actual usage depends on synthesis settings and optimizations.

---

## 🐛 **Troubleshooting**

### **Problem: Synthesis fails**
**Solution:**
```bash
# Check Vivado version (need 2020.1+)
vivado -version

# Check all source files exist
ls -la ../src/verilog/cpu/
ls -la ../src/verilog/memory/
```

### **Problem: Timing violations**
**Solution:**
```tcl
# In build.tcl, add optimization:
set_property STEPS.SYNTH_DESIGN.ARGS.DIRECTIVE AreaOptimized_high [get_runs synth_1]
set_property STEPS.PLACE_DESIGN.ARGS.DIRECTIVE Explore [get_runs impl_1]
set_property STEPS.ROUTE_DESIGN.ARGS.DIRECTIVE Explore [get_runs impl_1]
```

### **Problem: UART not working**
**Solution:**
1. Check baud rate: 115200
2. Check pin assignments in `constraints.xdc`
3. Verify USB-UART driver installed
4. Try different terminal: `screen`, `minicom`, `putty`

### **Problem: Wrong board**
**Solution:**
```bash
# Find your board's part number
# Look at board documentation or:
# Vivado → Tools → Auto Detect Part

# Update build.tcl line 16:
set part "xc7aXXXtXXXXXX-X"
```

---

## 📊 **Clock Frequencies**

| Board | Input Clock | CPU Clock | Notes |
|-------|-------------|-----------|-------|
| Basys3 | 100 MHz | 100 MHz | Direct |
| Arty A7 | 100 MHz | 100 MHz | Direct |
| Nexys A7 | 100 MHz | 100 MHz | Direct |
| Zybo Z7 | 125 MHz | 100 MHz | Need PLL |

**To add PLL (for Zybo Z7):**
```tcl
# In Vivado: IP Catalog → Clocking Wizard
# Input: 125 MHz
# Output: 100 MHz
```

---

## 🎯 **Next Steps After Programming**

1. **Verify basic operation:**
   - Reset button works
   - LEDs respond to switches
   - UART connection established

2. **Upload test program:**
   - Assemble test program
   - Load via UART (if bootloader implemented)
   - Or: Include in ROM during synthesis

3. **Run diagnostics:**
   - Test all GPIO pins
   - Test UART TX/RX
   - Verify CPU execution

4. **Develop applications:**
   - Write ARM7 assembly programs
   - Test on real hardware
   - Debug with LEDs/UART

---

## 📚 **Additional Resources**

- **Vivado User Guide**: UG893 (Vivado Design Suite User Guide)
- **Constraints Guide**: UG903 (Using Constraints)
- **Board Files**: Download from Digilent website
- **FPGA Datasheet**: Check Xilinx website for your device

---

## ✅ **Checklist Before Building**

- [ ] Vivado installed (2020.1+)
- [ ] Correct part number in `build.tcl`
- [ ] Pin assignments match your board in `constraints.xdc`
- [ ] All source files present in `../src/verilog/`
- [ ] FPGA board connected via USB

---

**Ready to deploy to real hardware!** 🚀

For questions or issues, check the main project documentation in `../docs/`.

