module spi_wrapper_tb();
    reg clk;
    reg rst_n;
    reg MOSI;
    reg SS_n;
    wire MISO;

    reg [7:0] address;
    reg [7:0] data;
    reg [7:0] dummy_data;

    // Instantiate DUT
    SPI_WRAPPER DUT (clk,rst_n,MOSI,SS_n,MISO);

    // Clock generation
    initial begin
        clk = 0;
        forever #1 clk = ~clk;
    end

    // Test values
    initial begin
        address     = 8'd254;   // 11111110
        data        = 8'hAA;    // 10101010
        dummy_data  = 8'hF0;    // 11110000
    end

    integer j;
    initial begin
        // preload memory
        $readmemh("mem.dat", DUT.ram.mem);

        // reset
        rst_n = 0;
        MOSI  = 1; 
        SS_n  = 1;
        repeat(3) @(negedge clk);
        rst_n = 1;

        // Write Address Test
        SS_n = 0;
        @(negedge clk);
        MOSI = 0; @(negedge clk); 
        MOSI = 0; @(negedge clk);
        MOSI = 0; @(negedge clk); 
        for (j = 0; j < 8; j = j + 1) begin
            MOSI = address[7-j];
            @(negedge clk);
        end
        SS_n = 1; @(negedge clk);

        // Write Data Test
        SS_n = 0;
        @(negedge clk);
        MOSI = 0; @(negedge clk); 
        MOSI = 0; @(negedge clk);
        MOSI = 1; @(negedge clk); 
        for (j = 0; j < 8; j = j + 1) begin
            MOSI = data[7-j];
            @(negedge clk);
        end
        SS_n = 1; @(negedge clk);

        // Read Address Test
        SS_n = 0;
        @(negedge clk);
        MOSI = 1; @(negedge clk); 
        MOSI = 0; @(negedge clk); 
        for (j = 0; j < 8; j = j + 1) begin
            MOSI = address[7-j];
            @(negedge clk);
        end
        SS_n = 1; @(negedge clk);

        //Read Data Test
        SS_n = 0;
        @(negedge clk);
        MOSI = 1; @(negedge clk); 
        MOSI = 1; @(negedge clk); 
        for (j = 0; j < 8; j = j + 1) begin
            MOSI = dummy_data[7-j]; 
            @(negedge clk);
        end

        // wait for data on MISO
        repeat(12) @(negedge clk);

        $stop;
    end
endmodule