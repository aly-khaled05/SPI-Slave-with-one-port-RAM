# SPI Slave with Single-Port RAM

A Verilog HDL implementation of an SPI slave interface backed by a single-port synchronous RAM, verified in QuestaSim and synthesized/implemented for a Basys3 (Xilinx 7-series) FPGA.

## Overview

This project implements a digital system that lets an SPI master read from and write to an on-chip RAM through a simple SPI slave interface. The design is organized into three modules:

- **`single_port_sync_ram`** — Stores 8-bit data across 256 memory locations, controlled by write/read commands issued from the SPI slave.
- **`SPI_slave`** — Shifts in serial data on `MOSI`, decodes commands with an FSM, and shifts data out on `MISO`.
- **`SPI_WRAPPER`** — Top-level module that instantiates and connects the RAM and SPI slave.

### Supported operations

1. Load a write address
2. Write data to RAM
3. Load a read address
4. Read data from RAM

## System Flow

When the SPI master asserts `SS_n` (active low), the slave begins a transaction. Serial bits on `MOSI` are shifted into a command/data register and interpreted according to a 2-bit opcode. On a read, the requested byte is pulled from RAM and shifted out on `MISO`.

## System Architecture

```
                 SPI SLAVE WITH SINGLE PORT RAM
              ┌───────────────────────────────────┐
   MOSI ─────▶│                                     │
              │                    rx_data     din  │
   MISO ◀────▶│   SPI Slave    ────[10]────▶   RAM  │
              │                    rx_valid rx_valid│
   SS_n ─────▶│                ────────────▶        │
              │                    tx_data    dout  │
              │                ◀────[8]─────        │
              │                    tx_valid tx_valid│
              │                ◀────────────        │
              └───────────────────────────────────┘
                     ▲                    ▲
   clk   ────────────┴────────────────────┘
   rst_n ─────────────────────────────────┘
```

**Key signals:**

| Signal     | Width | Direction (Slave → RAM unless noted) | Description                                      |
|------------|-------|---------------------------------------|---------------------------------------------------|
| `rx_data`  | 10    | SPI slave → RAM (`din`)                | Incoming command + address/data                   |
| `rx_valid` | 1     | SPI slave → RAM                        | Asserted when `rx_data` is ready to be processed   |
| `tx_data`  | 8     | RAM (`dout`) → SPI slave                | Byte read from RAM, to be sent to the master       |
| `tx_valid` | 1     | RAM → SPI slave                        | Asserted when `tx_data` is ready for transmission  |

### `rx_data` command encoding (`din[9:8]`)

| Code   | Operation          | `din[7:0]` meaning |
|--------|---------------------|---------------------|
| `2'b00`| Load write address  | Write address       |
| `2'b01`| Write data          | Data byte           |
| `2'b10`| Load read address   | Read address        |
| `2'b11`| Read data           | (triggers `dout <= mem[addr_rd]`) |

## State Diagram

The SPI slave FSM has five states:

- **IDLE** — waiting for `SS_n` to go low
- **CHECK_COMMAND** — reads the first `MOSI` bit(s) to decide the operation
- **WRITE** — shifting in a write address or write data (10 bits total)
- **READ_ADD** — shifting in a read address
- **READ_DATA** — read address latched; RAM data is fetched and shifted out on `MISO`

```
                         SS_n = 1
              ┌─────────────────────────────┐
              │                             │
              ▼                             │
   ┌────────────────┐   SS_n = 0    ┌───────────────┐
   │      IDLE       │ ────────────▶│  CHECK_COMMAND │
   └────────────────┘               └───────────────┘
        ▲   ▲   ▲                     │      │
        │   │   │  SS_n=0 & MOSI=0    │      │ SS_n=0 & MOSI=1
        │   │   └─────────────────────┘      │
        │   │                                ▼
        │   │                     add_or_data=0 ──▶ READ_ADD ──▶(self-loop while SS_n=0)
        │   │                     add_or_data=1 ──▶ READ_DATA ─▶(self-loop while SS_n=0)
        │   │
        │   └── WRITE (self-loop while SS_n=0) ── SS_n=1 ──▶ IDLE
        │
        └── READ_ADD / READ_DATA ── SS_n=1 ──▶ IDLE
```

*(See the source PDF for the fully rendered state diagram graphic.)*

## SPI Transaction Format

Each transaction is `SS_n` asserted for the duration of one command:

| Transaction        | Bit 1 (`MOSI`) | Bit 2 (`MOSI`) | Following bits              |
|---------------------|:--------------:|:--------------:|-------------------------------|
| Write address        | `0`            | `0`             | 8-bit address, MSB first      |
| Write data            | `0`            | `1`             | 8-bit data, MSB first          |
| Read address (setup)  | `1`            | `0`             | 8-bit address, MSB first      |
| Read data              | `1`            | `1`             | 8 don't-care bits; `MISO` returns the byte |

Internally, the slave shifts in a 10-bit `data` register (`{cmd[1:0], addr_or_data[7:0]}`) and asserts `rx_valid` once all 10 bits have been received (`counter == 10`).

## File Structure

```
.
├── spi1.v              # RTL: single_port_sync_ram, SPI_slave, SPI_WRAPPER
├── spitb.v             # Testbench: spi_wrapper_tb
├── mem.dat             # Memory preload file (read via $readmemh)
├── sim.do              # QuestaSim simulation script
└── constraints.xdc     # Basys3 pin constraints
```

## Module Interfaces

### `single_port_sync_ram`

```verilog
module single_port_sync_ram (din, rx_valid, clk, rst_n, tx_valid, dout);
parameter MEM_DEPTH = 256;
parameter ADDR_SIZE = 8;
```

| Port       | Dir | Width | Description                          |
|------------|-----|-------|---------------------------------------|
| `din`      | in  | 10    | Command + address/data from SPI slave |
| `rx_valid` | in  | 1     | Latch `din` on this cycle             |
| `clk`      | in  | 1     | System clock                          |
| `rst_n`    | in  | 1     | Synchronous active-low reset          |
| `tx_valid` | out | 1     | `dout` is valid                       |
| `dout`     | out | 8     | Data read from `mem[addr_rd]`         |

### `SPI_slave`

```verilog
module SPI_slave (MOSI, SS_n, tx_data, tx_valid, clk, rst_n, MISO, rx_data, rx_valid);
```

| Port       | Dir | Width | Description                          |
|------------|-----|-------|---------------------------------------|
| `MOSI`     | in  | 1     | Master-out, slave-in serial line      |
| `SS_n`     | in  | 1     | Active-low slave select               |
| `tx_data`  | in  | 8     | Byte to transmit, from RAM            |
| `tx_valid` | in  | 1     | `tx_data` is valid                    |
| `clk`      | in  | 1     | System clock                          |
| `rst_n`    | in  | 1     | Synchronous active-low reset          |
| `MISO`     | out | 1     | Master-in, slave-out serial line      |
| `rx_data`  | out | 10    | Decoded command + address/data        |
| `rx_valid` | out | 1     | `rx_data` is valid                    |

### `SPI_WRAPPER`

```verilog
module SPI_WRAPPER (clk, rst_n, MOSI, SS_n, MISO);
```

Top-level module; instantiates `single_port_sync_ram` and `SPI_slave` and wires them together internally.

## Simulation

Simulated with **QuestaSim**. The testbench (`spi_wrapper_tb`) preloads RAM from `mem.dat`, applies reset, then drives four back-to-back transactions:

1. Write address
2. Write data
3. Read address
4. Read data (captures the returned byte on `MISO`)

### Running the simulation

```tcl
vlib work
vlog spi1.v spitb.v
vsim -voptargs=+acc spi_wrapper_tb
add wave sim:/spi_wrapper_tb/clk
add wave sim:/spi_wrapper_tb/rst_n
add wave sim:/spi_wrapper_tb/MOSI
add wave sim:/spi_wrapper_tb/SS_n
add wave sim:/spi_wrapper_tb/MISO
add wave sim:/spi_wrapper_tb/DUT/rx_data_to_din
add wave sim:/spi_wrapper_tb/DUT/rx_valid
add wave sim:/spi_wrapper_tb/DUT/tx_data_to_dout
add wave sim:/spi_wrapper_tb/DUT/tx_valid
add wave sim:/spi_wrapper_tb/DUT/ram/mem
run -all
```

(Save this as `sim.do` and run `do sim.do` from the QuestaSim console.)

Waveform inspection confirmed correct address loading, data storage, and data retrieval across all four transaction types.

## Synthesis & Implementation (Vivado, Basys3)

The design was linted, synthesized, and implemented targeting a **Basys3 (Artix-7)** board. Pin assignments live in the constraint file:

| Signal   | Package Pin | Standard  |
|----------|-------------|-----------|
| `clk`    | W5          | LVCMOS33  |
| `rst_n`  | V17         | LVCMOS33  |
| `SS_n`   | V16         | LVCMOS33  |
| `MOSI`   | W16         | LVCMOS33  |
| `MISO`   | U16         | LVCMOS33  |

Clock constraint: 10 ns period (100 MHz), `create_clock -period 10.000`.

### FSM encoding comparison

Three FSM encodings were synthesized and implemented for comparison: **one-hot**, **gray**, and **sequential** (binary).

| Encoding   | WNS after Synthesis | WNS after Implementation | Slice Registers (top) |
|------------|:--------------------:|:--------------------------:|:------------------------:|
| One-hot    | 6.443 ns             | 5.686 ns                   | 61                        |
| Gray       | 6.471 ns             | 5.246 ns                   | 57                        |
| Sequential | 6.471 ns             | 5.108 ns                   | 57                        |

**Conclusion:** Since this is an SPI controller, meeting timing is critical for reliable high-speed data transfer. One-hot encoding produced the largest Worst Negative Slack (WNS), giving the best timing margin, and was therefore selected for the final implementation — trading a small increase in register count for the fastest, most robust operation.

All three encodings met every user-specified timing constraint with zero failing endpoints.

## Resource Utilization (One-Hot, post-implementation)

| Module        | Slice LUTs | Slice Registers | Block RAM Tile | Bonded IOB |
|---------------|:----------:|:----------------:|:----------------:|:------------:|
| `SPI_WRAPPER` (top) | 30    | 61                | 0.5               | 5            |
| `ram`         | 1          | 17                | 0.5               | 0            |
| `spi`         | 29         | 44                | 0                 | 0            |

## Author

Prepared by Aly Khaled.
