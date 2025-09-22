# SPI Slave with Single-Port RAM

This repository contains a Verilog implementation of an *SPI Slave integrated with Single-Port RAM* using *FSM-based encoding* for optimized timing and synchronized data transfers.

## Features
- *SPI Protocol Handling* – Fully compliant SPI Slave with serial-to-parallel conversion.
- *Single-Port RAM Interface* – 10-bit addresses, 8-bit data width.
- *Synchronized Data Transfers* – Handshaking signals rx_valid and tx_valid ensure accurate read/write.

## Files
- spi1.v – SPI Slave, RAM, and Wrapper modules.
- spitb.v – Testbench for simulation.
- mem.dat – Preloaded memory file for simulation.

## Tools & Workflow
- Simulated using *QuestaSim*.
- Synthesized and optimized using *Vivado*.
- Waveform analysis included for verification.

## Usage
1. Open the files in your Verilog simulator.
2. Run the testbench to simulate SPI read/write operations.
3. Modify mem.dat if custom memory initialization is needed.
