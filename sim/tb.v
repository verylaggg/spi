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
* Creat : 2025/04/03
* 
* Description : testbench
* 
******************************************************************************/
`timescale 1ns/1ns
module tb();

    parameter MAX_NUM = 10000;
    parameter MIN_NUM = 256;
    parameter USE_MODE_16B = 0;
    parameter CPHA = 0;
    parameter CPOL = 1;

    integer     SEED = 2;
    integer     TEST_STEP = 0;
    integer     RDM_NUM1, RDM_NUM2, RDM_NUM3;
    integer     USE_MODEL = 0; // run time change

    reg [127:0] mst_wfifo = {16{8'h5a}};
    reg [7:0]   mst_ctrl = 8'h00;
    reg         miso_mdl = 1'h0;

    wire            miso;
    wire            clk, clk_20m, clk_50m, clk_100m, rstn;
    wire            scl, ss, mosi, miso_slv;
    wire [127:0]    mst_rfifo;
    wire [7:0]      mst_status;

    assign          miso = USE_MODEL ? miso_mdl : miso_slv;

    // -MAX_NUM < num1 < MAX_NUM
    //       0 <= num2 < MAX_NUM
    // MIN_NUM <= num3 <= MAX_NUM
    initial begin
        fork
            forever #10 RDM_NUM1 = $random(SEED) % MAX_NUM;
            forever #10 RDM_NUM2 = {$random(SEED)} % MAX_NUM;
            forever #10 RDM_NUM3 = MIN_NUM + {$random(SEED)} % (MAX_NUM-MIN_NUM+1);
        join
    end

    clk_rst_model # (
        .period     (100        )
    ) clk_rst_m (
        .clk        (clk        ),
        .clk_20m    (clk_20m    ),
        .clk_50m    (clk_50m    ),
        .clk_100m   (clk_100m   ),
        .rstn       (rstn       )
    );

    spi_master # (
        .MODE_16B   (USE_MODE_16B),
        .CPOL       (CPOL       ),
        .CPHA       (CPHA       )
    ) spi_master_x (
        .clk        (clk_100m   ),
        .rstn       (rstn       ),
        .mst_wfifo  (mst_wfifo  ),
        .mst_ctrl   (mst_ctrl   ),
        .mst_rfifo  (mst_rfifo  ),
        .mst_status (mst_status ),

        .scl        (scl        ),
        .ss         (ss         ),
        .mosi       (mosi       ),
        .miso       (miso       )
    );

    spi_slave # (
        .CPOL       (CPOL       ),
        .CPHA       (CPHA       )
    ) spi_slave_x (
        .clk        (clk_100m   ),
        .rstn       (rstn       ),

        .scl        (scl        ),
        .ss         (ss || USE_MODEL),
        .mosi       (mosi       ),
        .miso       (miso_slv   )
    );

    initial begin
        @ (posedge rstn) $display ("rstn end");
        TEST_STEP = 1;
        #123;

        TEST_STEP = 2;
        ENA_MST('h0, 1); // (len, use_model)
        SEND_MISO ({4{32'hCAFE_EFAB}}, mst_ctrl[3:0], USE_MODE_16B, CPOL, CPHA);
        wait (!mst_status[7]);

        TEST_STEP = 4;
        ENA_MST('h7, 1);
        SEND_MISO ({4{32'hBABE_FACE}}, mst_ctrl[3:0], USE_MODE_16B, CPOL, CPHA);
        wait (!mst_status[7]);

        TEST_STEP = 3;
        ENA_MST('h0, 0);
        wait (!mst_status[7]);

        TEST_STEP = 7;
        ENA_MST('h7, 0);
        wait (!mst_status[7]);

        #2000;
        TEST_STEP = 88;
    end

    initial begin
        wait (TEST_STEP == 'd1);
        $display("sim start");

        wait (TEST_STEP == 'd88);
        $display("sim end");
        $finish;
    end

    initial begin
        $dumpfile("tb.vcd");
        $dumpvars(0, tb);
    end

    task SEND_MISO;
        input [127:0] in;
        input [3:0] len;
        input       mode_16b;
        input       CPOL;
        input       CHPA;
        reg [127:0]     slv_mdl_dbuf;
    begin
        slv_mdl_dbuf = 'h0;
        if (mode_16b && len > 'h7)
            $display ("[WARNING] %0t ns SPI SLV MODEL: exceed designed fifo len > 128b, which may send x", $realtime);
        fork
            // tx
            if (CPOL && !CPHA) begin
                if (mode_16b) begin
                    miso_mdl = in[127];
                    for (integer i = 0; i < (16 * len + 15); i = i + 1)
                        @ (posedge scl) miso_mdl = in[126-i];
                end else begin
                    miso_mdl = in[127];
                    for (integer i = 0; i < (8 * len + 7); i = i + 1)
                        @ (posedge scl) miso_mdl = in[126-i];
                end
            end else if (!CPOL && CPHA) begin
                if (mode_16b) begin
                    for (integer i = 0; i < (16 * len + 16); i = i + 1)
                        @ (posedge scl) miso_mdl = in[127-i];
                end else begin
                    for (integer i = 0; i < (8 * len + 8); i = i + 1)
                        @ (posedge scl) miso_mdl = in[127-i];
                end
            end else if (CPOL && CPHA) begin
                if (mode_16b) begin
                    for (integer i = 0; i < (16 * len + 16); i = i + 1)
                        @ (negedge scl) miso_mdl = in[127-i];
                end else begin
                    for (integer i = 0; i < (8 * len + 8); i = i + 1)
                        @ (negedge scl) miso_mdl = in[127-i];
                end
            end if (!CPOL && !CPHA) begin
                if (mode_16b) begin
                    miso_mdl = in[127];
                    for (integer i = 0; i < (16 * len + 15); i = i + 1)
                        @ (negedge scl) miso_mdl = in[126-i];
                end else begin
                    miso_mdl = in[127];
                    for (integer i = 0; i < (8 * len + 7); i = i + 1)
                        @ (negedge scl) miso_mdl = in[126-i];
                end
            end

            // rx
            if (CPOL != CPHA) begin
                if (mode_16b) begin
                    for (integer i = 0; i < (16 * len + 16); i = i + 1)
                        @ (negedge scl) slv_mdl_dbuf[127-i] = mosi;
                end else begin
                    for (integer i = 0; i < (8 * len + 8); i = i + 1)
                        @ (negedge scl) slv_mdl_dbuf[127-i] = mosi;
                end
            end else begin
                if (mode_16b) begin
                    for (integer i = 0; i < (16 * len + 16); i = i + 1)
                        @ (posedge scl) slv_mdl_dbuf[127-i] = mosi;
                end else begin
                    for (integer i = 0; i < (8 * len + 8); i = i + 1)
                        @ (posedge scl) slv_mdl_dbuf[127-i] = mosi;
                end
            end
        join
        $display ("%0t ns SLV MODEL: get %0h in buffer", $realtime, slv_mdl_dbuf);
    end
    endtask

    task ENA_MST;
        input [3:0] len;
        input       ena_mdl;
    begin
        # RDM_NUM2;
        USE_MODEL = ena_mdl;
        mst_ctrl[7] = 'h1;
        mst_ctrl[3:0] = len;
        wait (mst_status[7]);
        mst_ctrl[7] = 'h0;
    end
    endtask

endmodule