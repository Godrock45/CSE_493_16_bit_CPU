# Gate-level netlist (for drawing in Cadence Virtuoso)

This is a hand-structured gate-level version of the CPU in the root folder's `top.sv`: the **16-bit core** (4-bit opcode, 16 × 16-bit registers, word-addressed PC). It is *not* the 32-bit RV32I core that the root `README.md` describes; that README, `RV32I_ISA_SPEC.txt` and `test/` are left over from the older version.

The netlist is laid out for drawing by hand, not dumped from a synthesis tool:

- **Only 8 leaf cells** (`cells.v`). Each one becomes one transistor-level schematic.
- **Everything else is hierarchy.** Each `.v` module becomes one schematic plus a symbol, built only from cells and modules defined before it.
- **Readable net names.** Names follow the RTL (`PC_loc`, `rd1_loc`, `AluCtrl_loc`, …), every module has a header that explains it, and the larger ones include ASCII diagrams.
- **Repeated structure is explicit.** For example, `mux2_16` is 16 identical MUX2s, which you draw as one iterated instance.

It matches the RTL cycle for cycle (see [Checking](#checking)).

---

## Draw order

Draw the cells and blocks from top to bottom. Each one only uses things above it. *Gates* means leaf-cell instances once everything below it is flattened.

| # | cell / block | file | built from | gates |
|---|---|---|---|---|
| 0 | `INV` `NAND2` `NOR2` `AND2` `OR2` `XOR2` `MUX2` `DFF` | cells.v | transistors | 1 each |
| 1 | `half_adder` | blocks.v | XOR2, AND2 | 2 |
| 2 | `full_adder` | blocks.v | 2 XOR2, 3 NAND2 | 5 |
| 3 | `reg_bit` (enable) | blocks.v | MUX2, DFF | 2 |
| 4 | `reg_bit_r` (enable + sync reset) | blocks.v | MUX2, AND2, DFF | 3 |
| 5 | `reg16` | blocks.v | 16 reg_bit | 32 |
| 6 | `reg16_r` | blocks.v | INV, 16 reg_bit_r | 49 |
| 7 | `mux2_16` | blocks.v | 16 MUX2 | 16 |
| 8 | `mux8_16` | blocks.v | 7 mux2_16 | 112 |
| 9 | `mux16_16` | blocks.v | 2 mux8_16, 1 mux2_16 | 240 |
| 10 | `dec2to4` | blocks.v | 2 INV, 4 AND2 | 6 |
| 11 | `dec3to8_en` | blocks.v | dec2to4, INV, 10 AND2 | 17 |
| 12 | `dec4to16_en` | blocks.v | 2 dec2to4, 20 AND2 | 32 |
| 13 | `add16` | blocks.v | 16 full_adder (ripple) | 80 |
| 14 | `inc16` | blocks.v | 16 half_adder | 32 |
| 15 | `zero16` | blocks.v | 14 OR2, NOR2 | 15 |
| 16 | `eq16` | blocks.v | 16 XOR2, zero16 | 31 |
| 17 | `alu_slice` | alu16.v | full_adder, 2 XOR2, 2 AND2, OR2, 6 MUX2 | 16 |
| 18 | `shl16` / `shr16` | alu16.v | 64 / 80 MUX2 (barrel shifters) | 64 / 80 |
| 19 | `alu16` | alu16.v | 16 alu_slice, shl16, shr16, 10 decode gates, SLT (2) | 412 |
| 20 | `pc_reg` | pc_reg.v | reg16_r | 49 |
| 21 | `instr_rom` | instr_rom.v | dec4to16_en, dec3to8_en, 21 AND2, 95 OR2 | 165 |
| 22 | `instr_dec` | instr_dec.v | 38 gates | 38 |
| 23 | `ctrl_unit` | ctrl_unit.v | 2 dec2to4, 23 gates | 35 |
| 24 | `reg_file` | reg_file.v | dec4to16_en, 15 reg16_r, 2 mux16_16 | 1 247 |
| 25 | `mem_bank16` | data_mem.v | dec4to16_en, 16 reg16, mux16_16 | 784 |
| 26 | `data_mem` (128 words) *or* `data_mem_16w` | data_mem.v | 8 mem_bank16, dec3to8_en, mux8_16 / 1 mem_bank16 | 6 401 / 784 |
| 27 | `cpu_top` | cpu_top.v | all units, plus inc16, add16, zero16, eq16, 6 mux2_16 | **8 603** |

That's 28 schematics in total. Most are small, and the 16-bit ones are a single iterated instance.

## Where the gates go

| unit in `cpu_top` | gates | DFFs | share |
|---|---|---|---|
| `data_mem` (128 × 16) | 6 401 | 2 048 | **74 %** |
| `reg_file` | 1 247 | 240 | 14 % |
| `alu16` | 412 | — | 5 % |
| `instr_rom` | 165 | — | 2 % |
| glue (PC+1, branch adder, muxes, zero, halt) | 256 | — | 3 % |
| `pc_reg`, `instr_dec`, `ctrl_unit` | 122 | 16 | 1 % |
| **total** | **8 603** | **2 304** | about 124 k transistors |

**Decide on memory size first.** The full 128-word memory is three quarters of the design. It also makes transistor-level simulation slow. `data_mem_16w` has the same ports but only 16 words, and addresses wrap every 16 words. With it the whole CPU is **2 986 gates (about 37 k transistors)**, and the demo program in `ROM.sv` still runs correctly (checked). To switch, change `data_mem` to `data_mem_16w` on the `u_dmem` line of `cpu_top.v`.

The transistor estimates assume static CMOS with INV 2T, NAND2/NOR2 4T, AND2/OR2 6T, XOR2 12T, MUX2 12T and DFF 24T. A transmission-gate XOR, MUX or DFF brings the total down.

---

## The 8 leaf cells

| cell | pins | function | suggested circuit |
|---|---|---|---|
| `INV` | A → Y | Y = ¬A | 2T |
| `NAND2` | A, B → Y | Y = ¬(A·B) | 4T |
| `NOR2` | A, B → Y | Y = ¬(A+B) | 4T |
| `AND2` | A, B → Y | Y = A·B | NAND2 + INV (6T) |
| `OR2` | A, B → Y | Y = A+B | NOR2 + INV (6T) |
| `XOR2` | A, B → Y | Y = A⊕B | 12T static, or 6–8T TG |
| `MUX2` | I0, I1, S → Y | Y = S ? I1 : I0 | 2 TGs + select INV + output buffer |
| `DFF` | D, CLK → Q | Q ← D on rising CLK | TG master–slave with local CLK/CLKB inverters |

The DFF has **no reset pin**. Reset is synchronous and done with logic in front of D (`reg_bit_r` = MUX2 → AND2 with `rstn` → DFF). That matches the RTL, where every `always_ff` uses `if (rst)` inside `@(posedge clk)`.

The behavioural code in `cells.v` exists only for simulation. Draw the transistor circuit, not that code.

## Conventions in the netlist

- **Cells are UPPERCASE** (pins A/B/Y, I0/I1/S, D/CLK/Q). **Blocks are lowercase.** Instances are named `u_*`.
- **`1'b0` means connect to `gnd!`. `1'b1` means connect to `vdd!`.**
- **`assign` never contains logic.** It only renames a wire, ties to GND/VDD, or regroups bus bits, as in the branch-offset sign extension in `cpu_top.v`. Draw it as a wire or net label.
- **A bus `[15:0]` becomes the Virtuoso bus `<15:0>`.** 16 identical instances with bit `i` wired to bit `i` (`mux2_16`, `reg16`, `add16`, `shl16` rows, the 16 `alu_slice`s, …) can be drawn as one **iterated instance**, e.g. `I0<15:0>`.
- **Unused outputs are left open.** Examples are `.cout()` on the branch adder, `wsel[0]` in the register file, and the unused decoder lines in the ROM and control unit.

**Possible shortcut:** Virtuoso's *File → Import → Verilog* (Verilog In) can generate schematics and symbols from a structural netlist like this one. Import every `.v` file except `cells.v`, with your 8 transistor-level cells in the reference library under the same cell and pin names. I haven't tried this on these files, so check the result. Even if you draw everything by hand, it's a quick way to check your drawing against the netlist.

---

## Notes per unit

- **`alu16`**
  - Each `alu_slice` holds one adder bit, the AND, OR and XOR, and a 6-MUX2 result tree that selects on `ALUCtrl`; the full table is in the file header.
  - Subtraction is `a + ~b + 1`: the `b ^ sub` XOR2 inverts b, and `sub` is the carry-in of slice 0.
  - SLT is `(OpA[15]^OpB[15]) ? OpA[15] : diff[15]`, a single MUX2.
  - SRA is `shr16` with `fill = OpA[15]`.
  - The carry ripples through 16 slices, which is the longest path in the CPU.
- **`reg_file`**
  - x0 isn't a register; it's wired to GND.
  - The second read port is addressed by `rd`, as in `top.sv`. The ISA has two operands, so rd is also the second source.
- **`instr_rom`**
  - **Generated** from `ROM.sv` by `gen_rom.py`. Re-run `python gen_rom.py` after changing the program.
  - It's an address decoder plus an OR plane. The file header has the bit matrix, so you can draw it as a NOR-ROM transistor array instead of OR gates.
  - Uninitialised addresses read `0x0000`, which acts as a no-op.
- **`ctrl_unit` / `instr_dec`**
  - Built as "decode the opcode to one line per instruction, then OR the lines". The truth tables are in the file headers.
  - `AluSrcA` is always 0, so it's tied to GND.

## Differences from the RTL

1. **x15 now resets.** In `registers.sv` the reset loop is `for (i=0; i<15; ...)`, so x15 never resets and reads `xxxx` until it is first written. In `reg_file` all of x1..x15 reset. To make the RTL match, change `i<15` to `i<16` in `registers.sv`.
2. **ROM words that `ROM.sv` doesn't set read 0** (a no-op) instead of X.

Other repo notes:
- `ripple.sv` doesn't compile and nothing uses it.
- `cmp.sv` is also unused. `top.sv` does branches with the ALU zero flag instead.

## Checking

```sh
cd gate_level && sh run_checks.sh          # about 1 minute
sh run_checks.sh +vcd                       # also writes cpu_gl.vcd
```

`run_checks.sh` runs two tests:
- **Unit test.** Each gate-level block runs against its RTL module: exhaustively for control, decoder and ROM, and with corner-case plus random vectors for the ALU, PC, register file and memory.
- **Whole-CPU test.** `cpu_top` and `top_wire` run the `ROM.sv` program in lockstep, compared on every cycle.

Both pass with 0 mismatches. `cpu_gl.vcd` gives you reference waveforms to compare against a Virtuoso transient simulation.
