/******************************************************************************
* |----------------------------------------------------------------------------|
* |                      Copyright (C) 2024-2025 VeryLag.                      |
* |                                                                            |
* | THIS SOURCE CODE IS FOR PERSONAL DEVELOPEMENT; OPEN FOR ALL USES BY ANYONE.|
* |                                                                            |
* |   Feel free to modify and use this code, but attribution is appreciated.   |
* |                                                                            |
* |----------------------------------------------------------------------------|
*
* Author : VeryLag (verylag0401@gmail.com)
* 
* Creat : 2025/04/02
* 
* Description : system clk/reset model
* 
******************************************************************************/

`timescale 1ns/1ns
module clk_rst_model # (
    parameter period = 100  // 10 MHz
) (
    output  reg clk ,
    output  reg clk_20m ,
    output  reg clk_50m ,
    output  reg clk_100m ,
    output  reg rstn
);

initial begin
    clk      = 1'b1;
    clk_20m  = 1'b1;
    clk_50m  = 1'b1;
    clk_100m = 1'b1;
    fork
        forever  clk      = #(period/2) ~clk  ; // half = 50
        forever  clk_20m  = #(25) ~clk_20m  ; 
        forever  clk_50m  = #(10) ~clk_50m  ; 
        forever  clk_100m = #(5) ~clk_100m  ; 
    join
end

initial begin
    rstn = 1;

    #5 rstn = 0;
    #50 rstn = 1;
end

endmodule
