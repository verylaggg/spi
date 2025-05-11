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
* Description : SPI Slave
* 
*******************************************************************************/
/*
ex. CPOL = 1(idle high), CPHA = 1(even edge sample), data = 8'h5a = 8'b01011010
CPHA   ____   v__   v__   v__   v__   v__   v__   v__   v____
SCL        |__|  |__|  |__|  |__|  |__|  |__|  |__|  |__| 
(CPOL)
              0     1     0     1     1     0     1     0           
             MSB  _____       ___________       _____        
MOSI   XXXXX_____|     |_____|           |_____|     |______XXXXX

*/

module spi_slave # (
    parameter CPOL = 'h1,
    parameter CPHA = 'h1
)(
    input   clk,
    input   rstn,

    input   scl,
    input   ss,
    input   mosi,
    output  miso
);
    localparam  IDLE    = 0,
                DATA    = 1;
    localparam INIT = {4{32'hDEAD_BEEF}};

    reg [127:0] data_wbuf, data_rbuf;
    reg [3:0]   slv_fsm_n, slv_fsm;
    reg         scl_d1;
    wire        scl_rp, scl_fp;

    always @ (*) begin
        slv_fsm_n = slv_fsm;

        case (slv_fsm)
        IDLE: begin
            if (!ss && scl_fp)
                slv_fsm_n = DATA;
        end
        DATA: begin
            if (ss)
                slv_fsm_n =IDLE;
        end
        endcase
    end

    always @ (posedge clk or negedge rstn) begin
        if (!rstn) begin
            slv_fsm <= IDLE;
            scl_d1 <= 'h0;
        end else begin
            slv_fsm <= slv_fsm_n;
            scl_d1 <= scl;
        end
    end

    always @ (posedge clk or negedge rstn) begin
        if (!rstn)
            data_wbuf <= INIT;
        else if (!CPOL && !CPHA && scl_fp) // TODO: temp fix for CPHA/OL = 0
            data_wbuf <= {data_wbuf[126:0], 1'h0};
        else if (slv_fsm == IDLE)
            data_wbuf <= INIT;
        else if (CPHA == CPOL && scl_fp)
            data_wbuf <= {data_wbuf[126:0], 1'h0};
        else if ((CPHA ^ CPOL) && scl_rp)
            data_wbuf <= {data_wbuf[126:0], 1'h0};
        else
            data_wbuf <= data_wbuf;
    end

    always @ (posedge clk or negedge rstn) begin
        if (!rstn)
            data_rbuf <= 'h0;
        else if (CPHA == CPOL && scl_rp)
            data_rbuf <= (slv_fsm == IDLE) ? 'h0 : {data_rbuf[126:0], mosi};
        else if ((CPHA ^ CPOL) && scl_fp)
            data_rbuf <= (slv_fsm == IDLE) ? 'h0 : {data_rbuf[126:0], mosi};
        else
            data_rbuf <= data_rbuf;
    end

    assign scl_rp = !scl_d1 && scl;
    assign scl_fp = scl_d1 && !scl;
    assign miso = data_wbuf[127];

endmodule