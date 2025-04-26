`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/03/29 16:24:18
// Design Name: 
// Module Name: Temperature
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



module Temperature(
    input        clk,
    input        rst_n,
    input        en,
    
    input        wr_rd,       // 读写位，0写1读
    input  [6:0] slave_addr,  // 从机地址
    input  [7:0] reg_addr,    // 寄存器地址
    input  [7:0] data_wr,     // 待写数据
    output [15:0] data_rd,    // 读取数据
    
    output [7:0] state,
    
    output       scl,
    inout        sda
);

// 状态 state
parameter s_idle           = 8'd0;  // 空闲
parameter s_start          = 8'd1;  // 开始
parameter s_send_slaveAddr = 8'd2;  // 发送从机地址以及读写位
parameter s_receive_ack    = 8'd3;  // 接收ack
parameter s_send_regAddr   = 8'd4;  // 发送寄存器地址
parameter s_send_data      = 8'd5;  // 发送数据
parameter s_receive_data   = 8'd6;  // 接收数据
parameter s_send_ack       = 8'd7;  // 发送ack
parameter s_stop           = 8'd8;  // 停止
parameter write            = 8'd9;  // 写
parameter s_restart        = 8'd10; // 重新开始 (用于读操作后的重启)

reg       scl;
reg       sda_reg;

reg [15:0] data_rd;
reg [7:0] state;           // 当前所处状态
reg [7:0] state_pre;       // 记录上次写状态，用于接收到的ack
reg [7:0] shift_data;
reg [3:0] bit_cnt;         // 发送或接收的位数
reg [3:0] cnt;             // 计数
reg       flag;            // 是否由主机驱动sda
reg       state_already;   // 指定状态不会多次转移不伴随clk改变(保持一个clk持续稳定状态)
reg       cnt_state;       // 记录当前状态是否完成一个clk
reg       once;            // 确保只执行一次，避免重复，当使能改为0再改为1时再次执行
reg [1:0] byte_cnt;        // 字节计数器，用于接收两个字节的温度数据

// 三态门控制
assign sda = (flag) ? sda_reg : 1'bz;

always @ (posedge clk, negedge rst_n)
begin
    // 复位
    if(!rst_n)
    begin
        scl        <= 1'b1;
        sda_reg    <= 1'b1;
        state      <= s_idle;
        state_pre  <= s_idle;
        shift_data <= 8'd0;
        bit_cnt    <= 4'd0;
        cnt        <= 4'd0;
        byte_cnt   <= 2'd0;
        
        flag       <= 1'b0;
        once       <= 1'b0;
        data_rd    <= 16'd0;
    end
    else if(!en) begin
        once       <= 1'b0;
    end
    else
    begin
        case(state)
            // 空闲
            s_idle:
            begin
                scl        <= 1'b1;
                sda_reg    <= 1'b1;
                state      <= s_idle;
                state_pre  <= s_idle;
                shift_data <= 8'd0;
                bit_cnt    <= 4'd0;
                cnt        <= 4'd0;
                byte_cnt   <= 2'd0;
                
                if(en && !once) 
                begin
                    state <= s_start;
                    flag  <= 1'b1;
                    once  <= 1'b1;
                end
                if(!en) 
                    once  <= 1'b0;
            end
            
            // 开始
            s_start:
            begin
                case(cnt)
                    4'd0:
                    begin
                        scl     <= 1'b0;
                        sda_reg <= 1'b1;
                        cnt     <= cnt + 1'b1;
                    end
                    4'd1:
                    begin
                        scl     <= 1'b0;
                        sda_reg <= 1'b1;
                        flag    <= 1'b1;
                        cnt     <= cnt + 1'b1;
                    end
                    // 时钟线和数据线都高
                    4'd2:
                    begin
                        scl     <= 1'b1;
                        sda_reg <= 1'b1;
                        cnt     <= cnt + 1'b1;
                    end
                    // 时钟线维持高电平，数据线拉低，表示开始信号
                    4'd3:
                    begin
                        scl         <= 1'b1;
                        sda_reg     <= 1'b0;
                        state       <= write;
                        
                        // 如果是重启(用于读操作)，则发送从机地址+读位
                        if(state_pre == s_receive_ack && byte_cnt == 2'd0)
                        begin
                            state_pre  <= s_start;
                            shift_data <= {slave_addr[6:0], 1'b1}; // 读操作
                        end
                        // 写
                        else
                        begin
                            state_pre  <= s_send_slaveAddr;
                            shift_data <= {slave_addr[6:0], 1'b0}; // 写操作
                        end
                        cnt         <= 4'd0;
                    end
                    default: 
                    begin
                        state <= s_stop;
                    end
                endcase
            end
            
            // 写数据操作
            write:
            begin
                case(cnt)
                    // 时钟拉低，准备修改 sda_reg 值
                    4'd0:
                    begin
                        scl <= 1'b0;
                        cnt <= cnt + 1'b1;
                    end
                    // 时钟拉低，修改 sda_reg 值，从高位开始发送
                    4'd1:
                    begin
                        scl     <= 1'b0;
                        sda_reg <= shift_data[7 - bit_cnt];
                        flag    <= 1'b1;
                        bit_cnt <= bit_cnt + 1;
                        cnt     <= cnt + 1'b1;
                    end
                    // 时钟拉高，sda_reg 生效
                    4'd2:
                    begin
                        scl <= 1'b1;
                        cnt <= cnt + 1'b1;
                    end
                    4'd3:
                    begin
                        scl <= 1'b1;
                        cnt <= 4'd0;
                        // 8位发送完成
                        if(bit_cnt == 8) 
                        begin
                            state <= s_receive_ack;
                            bit_cnt <= 4'd0;
                        end
                    end
                    default: 
                    begin
                        state <= s_stop;
                    end
                endcase
            end
            
            // 接收 ack
            s_receive_ack:
            begin
                case(cnt)
                    4'd0:
                    begin
                        scl <= 1'b0;
                        cnt <= cnt + 1'b1;
                    end
                    4'd1:
                    begin
                        scl  <= 1'b0;
                        flag <= 1'b0; // 释放 SDA，让从设备控制
                        cnt  <= cnt + 1'b1;
                    end
                    4'd2:
                    begin
                        scl <= 1'b1;
                        cnt <= cnt + 1'b1;
                    end
                    4'd3:
                    begin
                        scl <= 1'b1;
                        cnt <= 4'd0;
                        // 接收到 ACK
                        if(sda == 1'b0)
                        begin
                            if(state_pre == s_send_slaveAddr)
                            begin
                                state <= write;
                                state_pre <= s_send_regAddr;
                                shift_data <= reg_addr;
                            end
                            else if(state_pre == s_send_regAddr)
                            begin
                                // 写操作
                                if(!wr_rd)
                                begin
                                    state <= write;
                                    state_pre  <= s_send_data;
                                    shift_data <= data_wr;
                                end
                                // 读操作 - 需要重启
                                else if(wr_rd)
                                begin
                                    state <= s_start; // 重新开始，准备读数据
                                    state_pre <= s_receive_ack;
                                end
                            end
                            else if(state_pre == s_send_data)
                            begin
                                // 写操作完成
                                state <= s_stop;
                            end
                            // 读操作 - 从设备地址发送完成
                            else if(state_pre == s_start)
                            begin
                                state <= s_receive_data; // 开始接收数据
                            end
                        end
                        // NACK
                        else 
                        begin
                            state <= s_stop;
                        end
                    end
                endcase
            end
            
            // 接收数据
            s_receive_data:
            begin
                case(cnt)
                    4'd0:
                    begin
                        scl <= 1'b0;
                        cnt <= cnt + 1'b1;
                    end
                    4'd1:
                    begin
                        scl  <= 1'b0;
                        flag <= 1'b0; // SDA 为高阻态，准备接收
                        cnt  <= cnt + 1'b1;
                    end
                    4'd2:
                    begin
                        scl <= 1'b1; // 时钟拉高，读取数据
                        cnt <= cnt + 1'b1;
                    end
                    4'd3:
                    begin
                        scl <= 1'b1;
                        
                        // 根据当前接收的字节，存储到高字节或低字节
                        if(byte_cnt == 2'd0)
                            data_rd[15 - bit_cnt] <= sda; // 第一个字节 (高位)
                        else
                            data_rd[7 - bit_cnt] <= sda;  // 第二个字节 (低位)
                            
                        bit_cnt <= bit_cnt + 1;
                        cnt     <= 4'd0;
                        
                        // 一个字节接收完成
                        if(bit_cnt == 4'd7)
                        begin
                            bit_cnt <= 4'd0;
                            
                            if(byte_cnt == 2'd0)
                            begin
                                // 第一个字节接收完成，发送 ACK 并继续接收第二个字节
                                state    <= s_send_ack;
                                byte_cnt <= byte_cnt + 1'b1;
                            end
                            else
                            begin
                                // 第二个字节接收完成，发送 NACK 并结束
                                state    <= s_send_ack;
                            end
                        end
                    end
                endcase
            end
            
            // 发送 ACK/NACK
            s_send_ack:
            begin
                case(cnt)
                    4'd0:
                    begin
                        scl <= 1'b0;
                        cnt <= cnt + 1'b1;
                    end
                    4'd1:
                    begin
                        scl <= 1'b0;
                        
                        // 如果是第一个字节，发送 ACK (拉低)；如果是第二个字节，发送 NACK (拉高)
                        if(byte_cnt == 2'd1 && bit_cnt == 4'd0)
                            sda_reg <= 1'b0; // ACK
                        else
                            sda_reg <= 1'b1; // NACK
                            
                        flag <= 1'b1;
                        cnt  <= cnt + 1'b1;
                    end
                    4'd2:
                    begin
                        scl <= 1'b1;
                        cnt <= cnt + 1'b1;
                    end
                    4'd3:
                    begin
                        scl <= 1'b1;
                        cnt <= 4'd0;
                        
                        // 如果是第一个字节的 ACK，继续接收第二个字节
                        if(byte_cnt == 2'd1 && bit_cnt == 4'd0)
                        begin
                            state  <= s_receive_data;
                            bit_cnt <= 4'd0;
                        end
                        // 如果是第二个字节的 NACK，结束传输
                        else
                        begin
                            state <= s_stop;
                            byte_cnt <= 2'd0;
                        end
                    end
                    default: 
                    begin
                        state <= s_stop;
                    end
                endcase
            end
            
            // 停止
            s_stop:
            begin
                case(cnt)
                    4'd0:
                    begin
                        scl     <= 1'b0;
                        sda_reg <= 1'b0; // 拉低数据线，准备发送停止信号
                        flag    <= 1'b1;
                        cnt     <= cnt + 1'b1;
                    end
                    // 时钟线拉高，数据线保持低
                    4'd1:
                    begin
                        scl     <= 1'b1;
                        sda_reg <= 1'b0;
                        cnt     <= cnt + 1'b1;
                    end
                    // 时钟线保持高，数据线拉高，表示停止信号
                    4'd2:
                    begin
                        scl     <= 1'b1;
                        sda_reg <= 1'b1;
                        cnt     <= cnt + 1'b1;
                    end
                    4'd3:
                    begin
                        state   <= s_idle;
                        scl     <= 1'b1;
                        sda_reg <= 1'b1;
                        cnt     <= 4'd0;
                        byte_cnt <= 2'd0;
                    end
                    default: 
                    begin
                        state <= s_stop;
                    end
                endcase
            end
        endcase
    end
end

endmodule