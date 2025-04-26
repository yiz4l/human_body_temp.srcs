`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/04/15 15:50:18
// Design Name: 
// Module Name: top
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


module top(
input        clk,
    input   rst_n,       // 复位信号（低有效）
    input   start,       // 启动温度读取
    input   en; //     begin
    input  [6:0] slave_addr, // 从设备地址
    input  [7:0] reg_addr,   // 寄存器地址
    input  [7:0] data_wr,     // 写入数据
    output [15:0] data_rd,  // 读取的温度值
    output [7:0]  status,
    inout        sda
);

wire scl;              // I2C时钟线
wire scl_clk;          // 分频后的SCL时钟
// wire en_i2c = start;   // I2C使能信号

// 分频器
Divider u_Divider(
    .clk     (clk),
    .rst_n   (rst_n),
    .en      (en),
    .scl_clk (scl_clk)
);

// I2C控制器
Temperature u_Temperature(
    .clk        (clk),          // 系统时钟
    .rst_n      (rst_n),
    .en         (en),
    .wr_rd      (wr_rd),         // 固定为读模式
    .slave_addr (slave_addr),        // MAX30205默认地址
    .reg_addr   (reg_addr),        // 温度寄存器地址
    .data_wr    (data_wr),        // 无需写数据
    .data_rd    (data_rd),    // 温度输出
    .state      (status),       // 状态输出
    .scl        (scl),          // 连接到分频器的SCL
    .sda        (sda)
);

// SCL信号连接
assign scl = scl_clk;
endmodule
