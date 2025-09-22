module single_port_sync_ram (din,rx_valid,clk,rst_n,tx_valid,dout);
parameter MEM_DEPTH=256;
parameter ADDR_SIZE=8;
input [9:0] din;
input rx_valid;
input clk;
input rst_n;            //synchronous active-low reset.
output reg tx_valid;
output reg [7:0] dout;
reg [ADDR_SIZE-1:0] addr_wr;
reg [ADDR_SIZE-1:0] addr_rd;
reg [7:0] mem [MEM_DEPTH-1:0];
always @ (posedge clk) begin
if(~rst_n) begin
dout<=0;
tx_valid<=0;
addr_rd<=0;
addr_wr<=0;
end
else begin
if(rx_valid) begin
    case(din[9:8]) 
    2'b00:  begin
                addr_wr<=din[7:0];
                tx_valid<=0;
            end
    2'b01:  begin
                mem[addr_wr]<=din[7:0];
                tx_valid<=0;
            end
    2'b10:  begin 
                addr_rd<=din[7:0];
                tx_valid<=0;
            end
    2'b11:  begin
                dout<=mem[addr_rd];
                tx_valid<=1;
            end
    endcase
end
end
end
endmodule

module SPI_slave (MOSI,SS_n,tx_data,tx_valid,clk,rst_n,MISO,rx_data,rx_valid);
//parameters
parameter IDLE=3'b000;
parameter CHECK_COMMAND=3'b001;
parameter WRITE=3'b010;
parameter READ_ADD=3'b011;
parameter READ_DATA=3'b100;
//inputs
input MOSI;
input SS_n;
input clk;
input rst_n;                  //synchronous active-low reset.
input [7:0] tx_data;
input tx_valid;
//outputs
output reg rx_valid;
output reg [9:0] rx_data;
output reg MISO;
//internal signals
reg add_or_data;
reg [3:0] counter;
reg [9:0] data;
reg [7:0] read_data;
(* fsm_encoding = "gray" *)
reg [2:0] cs,ns;
//next state logic
always @(*) begin
    case (cs)
        IDLE: 
        if(!SS_n) begin
            ns=CHECK_COMMAND;
        end
        else begin 
            ns=IDLE;
        end
        CHECK_COMMAND: begin
            if (!SS_n) begin
                if (!MOSI) begin
                    ns=WRITE;
                end
                else begin
                    if (!add_or_data) begin
                        ns=READ_ADD;
                    end
                    else begin
                        ns=READ_DATA;
                    end
                end
            end
            else begin
                ns=IDLE;
            end
        end
        WRITE: 
        if (SS_n) begin
            ns=IDLE;
        end
        else begin
            ns=WRITE;
        end
        READ_ADD:
        if (SS_n) begin 
            ns=IDLE;
        end
        else begin 
            ns=READ_ADD;
        end
        READ_DATA:
        if (SS_n) begin 
            ns=IDLE;
        end
        else begin 
            ns=READ_DATA;
        end
    endcase
end
//state memory
always @(posedge clk) begin
    if (!rst_n) begin
        cs<=IDLE;
    end
    else begin
        cs<=ns;
    end
end
always @(posedge clk) begin
    if (!rst_n) begin
        MISO<=0;
        rx_valid<=0;
        rx_data<=0;
        counter<=0;
        data<=0;
        add_or_data<=0;
        read_data<=0;
    end
    else begin
        if (cs==IDLE) begin
            rx_valid<=0;
            counter<=0;
        end
        else if (cs==WRITE) begin
            if (counter==10) begin
                counter<=0;
                rx_valid<=1;
                rx_data<=data;
            end
            else begin
                counter<=counter+1;
                data<={data[8:0],MOSI};
            end
        end
        else if (cs==READ_ADD) begin
            if (counter==10) begin
                counter<=0;
                rx_valid<=1;
                rx_data<=data;
                add_or_data<=1;
            end
            else begin
                counter<=counter+1;
                data<={data[8:0],MOSI};
            end
        end
        else begin
            if (tx_valid) begin
                if (counter==0) begin
                    counter<=counter+1;
                end
                if (counter==1) begin
                    MISO<=tx_data[7];
                    read_data<=tx_data<<1;
                    counter<=counter+1;
                end
                else begin
                    MISO<=read_data[7];
                    read_data<=read_data<<1;
                end
            end
            else begin
                if (counter==10) begin
                    counter<=0;
                    rx_valid<=1;
                    rx_data<=data;
                end
                else begin
                    counter<=counter+1;
                    data<={data[8:0],MOSI};
                end
            end
        end
    end
end
endmodule

module SPI_WRAPPER (clk,rst_n,MOSI,SS_n,MISO);
//inputs
input clk;
input rst_n;
input MOSI;
input SS_n;
//outputs
output MISO;
//internal signal
wire [9:0] rx_data_to_din;
wire rx_valid;
wire [7:0] tx_data_to_dout;
wire tx_valid;
single_port_sync_ram ram (rx_data_to_din,rx_valid,clk,rst_n,tx_valid,tx_data_to_dout);
SPI_slave   spi (MOSI,SS_n,tx_data_to_dout,tx_valid,clk,rst_n,MISO,rx_data_to_din,rx_valid);
endmodule