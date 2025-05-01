/*******************************************************************************
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
* Creat : 2025/04/22
* 
* Description : SPI Master
* 
*******************************************************************************/
/*
ex. CPOL = 1(idle high), CPHA = 1(even edge sample), data = 8'h5a = 8'b01011010
CPHA   ____o  v__o  v__o  v__o  v__o  v__o  v__o  v__o  v____
SCL        |__|  |__|  |__|  |__|  |__|  |__|  |__|  |__| 
(CPOL)
              0     1     0     1     1     0     1     0           
             MSB  _____       ___________       _____        
MOSI   XXXXX_____|     |_____|           |_____|     |______XXXXX

TODO: CPHA CPOL option
*/

module spi_master # (
    parameter MODE_16B = 'h0, // TODO: beware of total len > 16 * 8
    parameter CPOL = 'h1,
    parameter CPHA = 'h1
)(
    input   clk,
    input   rstn,

    input   [127:0] mst_wfifo,
    input   [7:0]   mst_ctrl,
    output  [127:0] mst_rfifo,
    output  [7:0]   mst_status,

    output  scl,
    output  ss,
    output  mosi,
    input   miso
);
    reg [3:0]   mst_fsm_n, mst_fsm, clk_div_cnt;
    reg [4:0]   pld_len_r, pld_cnt, bit_cnt;
    reg [127:0] data_wbuf, data_rbuf;
    reg         ena;
    wire        clk_div2, clk_div4, clk_div8, clk_div16;
    wire        scl_o, scl_o_rt, scl_o_ft;
    wire        busy, pld_rdy;
    wire [3:0]  pld_len;

    localparam  MIN_PLD = MODE_16B ? 16 : 8;
    localparam  IDLE    = 0,
                DATA    = 1;

    always @ (*) begin
        mst_fsm_n = mst_fsm;

        case (mst_fsm)
        IDLE: begin
            if (ena)
                mst_fsm_n = DATA;
        end
        DATA: begin
            if (!ena)
                mst_fsm_n = IDLE;
        end
        endcase
    end

    always @ (posedge clk or negedge rstn) begin
        if (!rstn) begin
            ena <= 'h0;
            pld_len_r <= 'h0;
        end else if (mst_fsm == IDLE && pld_rdy) begin
            ena <= 'h1;
            pld_len_r <= pld_len + 'h1;
        end else if (CPHA && bit_cnt >= MIN_PLD - 'h1 && clk_div_cnt >= 'hd)
            ena <= (pld_cnt == (pld_len_r - 'h1)) ? 'h0 : 'h1;
        else if (!CPHA && bit_cnt >= MIN_PLD - 'h1 && clk_div_cnt == 'h6)
            ena <= (pld_cnt == (pld_len_r - 'h1)) ? 'h0 : 'h1;
        else begin
            ena <= ena;
            pld_len_r <= pld_len_r;
        end
    end

    always @ (posedge clk or negedge rstn) begin
        if (!rstn || mst_fsm == IDLE)
            pld_cnt <= 'hff;
        else if (scl_o_rt && bit_cnt == 'h0)
            pld_cnt <= pld_cnt + 'h1;
        else
            pld_cnt <= pld_cnt;
    end

    always @ (posedge clk or negedge rstn) begin
        if (!rstn)
            mst_fsm <= IDLE;
        else
            mst_fsm <= mst_fsm_n;
    end

    always @ (posedge clk or negedge rstn) begin
        if (!rstn)
            clk_div_cnt <= 'h8;
        else if (mst_fsm == DATA)
            clk_div_cnt <= clk_div_cnt + 'h1;
        else
            clk_div_cnt <= 'h8;
    end

    always @ (posedge clk or negedge rstn) begin
        if (!rstn || mst_fsm == IDLE)
            bit_cnt <= 'h1f;
        else if (!CPHA && bit_cnt == 'h1f)
            bit_cnt <= 'h0;
        else if (!CPHA && scl_o_rt)
            bit_cnt <= (bit_cnt >= MIN_PLD - 'h1) ? 'h0 :bit_cnt + 'h1;
        else if (CPHA && scl_o_ft)
            bit_cnt <= (bit_cnt >= MIN_PLD - 'h1) ? 'h0 : bit_cnt + 'h1;
        else
            bit_cnt <= bit_cnt;
    end

    always @ (posedge clk or negedge rstn) begin
        if (!rstn)
            data_wbuf <= 'h0;
        else if (mst_fsm == DATA && bit_cnt == 'h1f)
            data_wbuf <= mst_wfifo;
        else if (CPHA && scl_o_ft)
            data_wbuf <= {data_wbuf[126:0], 1'h0};
        else if (!CPHA && scl_o_rt)
            data_wbuf <= {data_wbuf[126:0], 1'h0};
    end

    always @ (posedge clk or negedge rstn) begin
        if (!rstn)
            data_rbuf <= 'h0;
        else if (mst_fsm == DATA && bit_cnt == 'h1f)
            data_rbuf <= 'h0;
        else if (CPHA && scl_o_rt)
            data_rbuf <= {data_rbuf[126:0], miso};
        else if (!CPHA && scl_o_ft)
            data_rbuf <= {data_rbuf[126:0], miso};
    end

    assign {clk_div16, clk_div8, clk_div4, clk_div2} = clk_div_cnt;
    assign scl_o = clk_div16;
    assign scl_o_rt = clk_div_cnt == 'h7;
    assign scl_o_ft = mst_fsm == DATA && clk_div_cnt == 'h0;

    assign busy = mst_fsm != IDLE;
    assign mst_status = {busy, 7'h0};
    assign pld_rdy = mst_ctrl[7];
    assign pld_len = mst_ctrl[3:0];

    assign scl =  mst_fsm == DATA ? scl_o : CPOL;
    assign mosi = data_wbuf[127];
    assign ss = !ena;
    assign mst_rfifo = data_rbuf;

endmodule