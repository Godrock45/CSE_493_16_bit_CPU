#!/bin/sh
# Gate-level vs RTL equivalence checks with Icarus Verilog.
# Usage:  cd gate_level && sh run_checks.sh
# If you changed the program in ../ROM.sv, run `python gen_rom.py` first.
set -e
cd "$(dirname "$0")"
mkdir -p build

NET="cells.v blocks.v alu16.v reg_file.v data_mem.v instr_rom.v instr_dec.v ctrl_unit.v pc_reg.v cpu_top.v"
RTL="../top.sv ../PC.sv ../ROM.sv ../decoder.sv ../control.sv ../registers.sv ../ALU.sv ../data_mem.sv"

# build <out.vvp> <sources...>  -- hides iverilog's harmless "sorry: constant
# selects in always_*" notes about the RTL files
build() {
  out=$1; shift
  if ! iverilog -g2012 -o "$out" "$@" 2> build/iverilog.log; then cat build/iverilog.log; exit 1; fi
  grep -v "sorry: constant selects" build/iverilog.log || true
}

build build/tb_units.vvp tb/tb_units.sv $NET $RTL
vvp -n build/tb_units.vvp | tee build/tb_units.log
echo
build build/tb_cpu.vvp tb/tb_cpu.sv $NET $RTL
vvp -n build/tb_cpu.vvp "$@" | tee build/tb_cpu.log

if grep -q "^FAIL" build/tb_units.log build/tb_cpu.log; then exit 1; fi
