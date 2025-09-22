vlib work
vlog spi1.v spitb.v
vsim -voptargs=+acc spi_wrapper_tb
# Add only useful signals instead of everything (*)
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