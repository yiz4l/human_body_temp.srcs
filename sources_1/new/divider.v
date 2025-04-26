`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/04/15 15:29:11
// Design Name: 
// Module Name: divider
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module divider(
    input clk,
    input rst_n,
    input en,
    output reg scl_clk
    );
    
parameter DIVIDER = 500;  // 50,000,000 / (100,000 * 2) = 250

reg [15:0] counter;       // 分频计数器

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        counter <= 0;
        scl_clk <= 1'b1;
    end else if (en) begin
        if (counter == DIVIDER - 1) begin
            counter <= 0;
            scl_clk <= ~scl_clk;  // 翻转时钟
        end else begin
            counter <= counter + 1;
        end
    end else begin
        counter <= 0;
        scl_clk <= 1'b1;// 禁用时保持高电平
    end
end
endmodule
