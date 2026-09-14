SPI Slave with Single-Port Synchronous RAM
A Verilog HDL implementation of a Serial Peripheral Interface (SPI) slave controller integrated with a 256×8-bit single-port synchronous RAM. The architecture allows an SPI master to write data to or read data from memory through a 10-bit serial frame protocol.  
PDF
+ 1

System Overview
The top-level wrapper module (SPI_WRAPPER) coordinates communication between the SPI Slave interface and the Single-Port Synchronous RAM.  
PDF

SPI Slave Controller: Deserializes 10-bit incoming data from MOSI, decodes commands via a Finite State Machine (FSM), and serializes RAM output data onto MISO.  
PDF

Single-Port Synchronous RAM: Stores 256 8-bit words with synchronous active-low reset and internal write/read address registers.  
PDF

System Architecture
                     +----------------------------------------+
                     |              SPI_WRAPPER               |
                     |                                        |
    MOSI  ----------->| +------------+        +-------------+ |
    SS_n  ----------->| |            |        |             | |
    clk   ----------->| | SPI_slave  |=======>| Synchronous | |
    rst_n ----------->| |            |<=======|    RAM      | |
    MISO  <-----------| +------------+        +-------------+ |
                     +----------------------------------------+
Module Specifications
Module Name	File	Description
SPI_WRAPPER	spi_wrapper.v	
Top-level module integrating the SPI Slave and synchronous RAM.  
PDF

SPI_slave	spi_slave.v	
FSM-based SPI slave handling serial-to-parallel deshirting & MISO transmission.  
PDF

single_port_sync_ram	single_port_sync_ram.v	
256×8-bit memory block decoding 10-bit control vectors.  
PDF

spi_wrapper_tb	spi_wrapper_tb.v	
Testbench verifying write address, write data, read address, and read data transactions.  
PDF

Control Protocol & Command Structure
Communication uses a 10-bit serial frame transmitted MSB-first over MOSI:  
PDF

Frame Vector=[din[9:8]∣din[7:0]]
din[9:8]: Operation command code.  
PDF

din[7:0]: 8-bit RAM address or write data payload.  
PDF

RAM Operation Decoding
din[9:8] Code	Operation Mode	Target Register / Action
2'b00	Write Address	
Stores din[7:0] into internal addr_wr register.  
PDF

2'b01	Write Data	
Writes din[7:0] into memory location mem[addr_wr].  
PDF

2'b10	Read Address	
Stores din[7:0] into internal addr_rd register.  
PDF

2'b11	Read Data	
Loads mem[addr_rd] to dout and asserts tx_valid.  
PDF

FSM State Description
The SPI Slave uses a 5-state FSM to decode commands and control data flow:  
PDF

IDLE (3'b000): Waits for SS_n to drop low (0).  
PDF

CHECK_COMMAND (3'b001): Samples MOSI to distinguish write operations from read operations.  
PDF

WRITE (3'b010): Deserializes 10 bits for Write Address (00) or Write Data (01) commands.  
PDF

READ_ADD (3'b011): Deserializes 10 bits for Read Address (10) command and sets add_or_data flag.  
PDF

READ_DATA (3'b100): Deserializes 10 bits for Read Data (11) command and shifts out target memory content over MISO.  
PDF

Synthesis & Implementation Results
The design was synthesized and targeted for the Xilinx Basys 3 FPGA (Artix-7). A comparison of FSM encoding strategies was evaluated to maximize timing performance:  
PDF
+ 1

FSM Encoding Scheme	Worst Negative Slack (WNS) - Synth	Worst Negative Slack (WNS) - Impl	Total LUTs	Total Registers
One-Hot	6.443 ns	5.686 ns	30	61
Gray	6.471 ns	—	30	57
Sequential	6.471 ns	—	30	57
Design Choice: One-Hot encoding was selected for the final implementation as it provided superior timing slack margins for high-speed operation.  
PDF

File Structure
Plaintext
.
├── rtl/
│   ├── single_port_sync_ram.v   # Synchronous RAM memory module
│   ├── SPI_slave.v              # FSM SPI Slave controller
│   └── SPI_WRAPPER.v            # Top-level integration module
├── testbench/
│   ├── spi_wrapper_tb.v         # Testbench file
│   └── mem.dat                  # Memory initialization payload
├── scripts/
│   └── run.do                   # QuestaSim / ModelSim execution script
├── constraints/
│   └── Basys3_Master.xdc        # Xilinx Vivado pin constraints
└── README.md
How to Run Simulation
Using QuestaSim / ModelSim
Run the provided macro script directly from the simulation command line:  
PDF

Bash
vsim -do scripts/run.do
run.do Script Content:

Tcl
vlib work
vlog rtl/single_port_sync_ram.v rtl/SPI_slave.v rtl/SPI_WRAPPER.v testbench/spi_wrapper_tb.v
vsim -voptargs=+acc spi_wrapper_tb
add wave sim:/spi_wrapper_tb/*
add wave sim:/spi_wrapper_tb/DUT/*
run -all
