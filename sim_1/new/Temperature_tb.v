`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module: Temperature_tb
// Description: Testbench for MAX30205 temperature sensor I2C interface
// Based on I2C_Master testbench from chance189/I2C_Master
//////////////////////////////////////////////////////////////////////////////////

module Temperature_tb();
    // Interface signals to Temperature module
    reg clk;                // Clock signal
    reg rst_n;              // Reset signal (active low)
    reg en;                 // Enable signal
    reg wr_rd;              // Read/Write control (1 for read, 0 for write)
    reg [6:0] slave_addr;   // Slave address
    reg [7:0] reg_addr;     // Register address
    reg [7:0] data_wr;      // Data to write
    wire [15:0] data_rd;    // Data read from sensor
    wire [7:0] state;       // State output from module
    wire scl;               // I2C clock line
    wire sda;               // I2C data line (tristate)

    // Internal testbench signals
    reg en_sda;             // Enable SDA control from testbench
    reg test_sda;           // Test SDA value when controlling the line
    reg test_sda_prev;      // Previous SDA value for edge detection
    reg start_ind, stop_ind;// Start/stop indicators
    reg [7:0] test_data_in; // Buffer for received data in testbench
    reg [7:0] temp_msb;     // MSB of temperature data
    reg [7:0] temp_lsb;     // LSB of temperature data
    
    // Test parameters
    localparam [6:0] MAX30205_ADDR = 7'h48; // MAX30205 default address
    localparam [7:0] TEMP_REG = 8'h9E;      // Temperature register address

    // Device under test instantiation
    Temperature u_Temperature (
        .clk(clk),
        .rst_n(rst_n),
        .en(en),
        .wr_rd(wr_rd),
        .slave_addr(slave_addr),
        .reg_addr(reg_addr),
        .data_wr(data_wr),
        .data_rd(data_rd),
        .state(state),
        .scl(scl),
        .sda(sda)
    );

    // Tristate control for SDA line
    assign sda = en_sda ? test_sda : 1'bz;

    // Clock generation (100MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;  // 10ns period (100MHz)
    end

    // Edge detection for SDA
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            {start_ind, stop_ind, test_sda_prev} <= 0;
        end
        else begin
            test_sda_prev <= sda;
            start_ind <= test_sda_prev & !sda & scl;  // Start: high to low on SDA while SCL is high
            stop_ind <= !test_sda_prev & sda & scl;   // Stop: low to high on SDA while SCL is high
        end
    end

    // Counter for ACK bit counting
    integer i;
    
    // Test sequence
    initial begin
        // Initialize signals
        en_sda = 0;
        rst_n = 0;
        en = 0;
        wr_rd = 1;                // Read mode
        slave_addr = MAX30205_ADDR;
        reg_addr = TEMP_REG;      // Temperature register
        data_wr = 8'h00;          // Not used for read operation
        temp_msb = 8'h19;         // +25°C (0x1900 = 25.0°C)
        temp_lsb = 8'h00;
        
        // Reset sequence
        #20;
        rst_n = 1;
        #30;
        
        // Start I2C transaction
        en = 1;
        
        // Step 1: Wait for start condition
        @(posedge start_ind);
        $display("%t: START condition detected", $time);
        
        // Step 2: Receive slave address + write bit (for register addressing)
        for(i = 7; i >= 0; i = i - 1) begin
            @(posedge scl);
            #1;
            test_data_in[i] = sda;
        end
        $display("%t: Received slave address: %b, Write bit: %b", $time, test_data_in[7:1], test_data_in[0]);
        
        // Step 3: Send ACK (pull SDA low)
        @(negedge scl);
        #2;
        en_sda = 1;
        test_sda = 1'b0;  // ACK
        @(negedge scl);
        #2;
        en_sda = 0;       // Release SDA
        
        // Step 4: Receive register address
        for(i = 7; i >= 0; i = i - 1) begin
            @(posedge scl);
            #1;
            test_data_in[i] = sda;
        end
        $display("%t: Received register address: %02Xh", $time, test_data_in);
        
        // Step 5: Send ACK
        @(negedge scl);
        #2;
        en_sda = 1;
        test_sda = 1'b0;  // ACK
        @(negedge scl);
        #2;
        en_sda = 0;       // Release SDA
        
        // Step 6: Wait for repeated start condition
        @(posedge start_ind);
        $display("%t: REPEATED START condition detected", $time);
        
        // Step 7: Receive slave address + read bit
        for(i = 7; i >= 0; i = i - 1) begin
            @(posedge scl);
            #1;
            test_data_in[i] = sda;
        end
        $display("%t: Received slave address: %b, Read bit: %b", $time, test_data_in[7:1], test_data_in[0]);
        
        // Step 8: Send ACK
        @(negedge scl);
        #2;
        en_sda = 1;
        test_sda = 1'b0;  // ACK
        @(negedge scl);
        #2;
        en_sda = 0;       // Release SDA
        
        // Step 9: Send temperature MSB (first byte of data)
        en_sda = 1;
        for(i = 7; i >= 0; i = i - 1) begin
            @(posedge scl);
            #2;
            test_sda = temp_msb[i];
        end
        @(negedge scl);
        en_sda = 0;  // Release SDA for ACK from master
        
        // Step 10: Wait for ACK from master
        @(posedge scl);
        $display("%t: Master ACK for first byte: %s", $time, sda ? "NACK" : "ACK");
        
        // Step 11: Send temperature LSB (second byte of data)
        en_sda = 1;
        for(i = 7; i >= 0; i = i - 1) begin
            @(posedge scl);
            #2;
            test_sda = temp_lsb[i];
        end
        @(negedge scl);
        en_sda = 0;  // Release SDA for NACK from master
        
        // Step 12: Wait for NACK from master (last byte)
        @(posedge scl);
        $display("%t: Master response for second byte: %s", $time, sda ? "NACK" : "ACK");
        
        // Step 13: Wait for STOP condition
        @(posedge stop_ind);
        $display("%t: STOP condition detected", $time);
        $display("%t: Temperature data sent: 0x%02X%02X = %0.1f°C", $time, temp_msb, temp_lsb, $itor(temp_msb) + $itor(temp_lsb)/256);
        
        // Step 14: End of test
        #100;
        $display("%t: Test completed", $time);
        
        // Wait a bit longer to see the data_rd output
        #200;
        $display("%t: Final data_rd output: 0x%04X", $time, data_rd);
        
        // End simulation
        #500;
        $finish;
    end
    
    // Debug: monitor important signals
    initial begin
        $monitor("%t: en=%b, wr_rd=%b, state=0x%X, scl=%b, sda=%b, data_rd=0x%04X", 
                 $time, en, wr_rd, state, scl, sda, data_rd);
    end

endmodule