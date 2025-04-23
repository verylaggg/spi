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

    integer     TEST_STEP = 0;
    integer     RDM_NUM1, RDM_NUM2, RDM_NUM3;

    reg [127:0] mst_wfifo = {16{8'h5a}};
    reg [7:0]   mst_ctrl = 8'h00;
    reg         miso_mdl = 1'h0;
    reg         USE_MODEL = 0;
    
    wire            miso;
    wire            clk, clk_20m, clk_50m, clk_100m, rstn;
    wire            scl, ss, mosi, miso_slv;
    wire [127:0]    mst_rfifo;
    wire [7:0]      mst_status;

    assign          miso = USE_MODEL ? miso_mdl : miso_slv;

    // -MAX_NUM < num1 < MAX_NUM
    //       0 <= num2 < MAX_NUM
    // MIN_NUM <= num3 <= MAX_NUM
    always@(posedge clk) begin
        RDM_NUM1 <= $random() % MAX_NUM;
        RDM_NUM2 <= {$random()} % MAX_NUM;
        RDM_NUM3 <= MIN_NUM + {$random()} % (MAX_NUM-MIN_NUM+1);
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

    spi_master spi_master_x (
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

    spi_slave spi_slave_x (
        .clk        (clk_100m   ),
        .rstn       (rstn       ),

        .scl        (scl        ),
        .ss         (ss || USE_MODEL),
        .mosi       (mosi       ),
        .miso       (miso_slv   )
    );

    initial begin
        TEST_STEP = 1;
        #123;

        TEST_STEP = 2;
        # RDM_NUM2 ENA_MST('hf, 1);
        SEND_MISO ({4{32'hDEAD_BEEF}}, mst_ctrl[3:0]);
        wait (!mst_status[7]);

        TEST_STEP = 3;
        # RDM_NUM2 ENA_MST('hf, 0);
        wait (!mst_status[7]);

        TEST_STEP = 4;
        # RDM_NUM2 ENA_MST('h5, 1);
        SEND_MISO ({4{32'hDEAD_BEEF}}, mst_ctrl[3:0]);
        wait (!mst_status[7]);

        TEST_STEP = 6;
        # RDM_NUM2 ENA_MST('hf7, 0);
        wait (!mst_status[7]);

        #2000;
        TEST_STEP = 5;
    end

    initial begin
        @ (posedge rstn) $display ("rstn end");
        wait (TEST_STEP == 'h1);
        $display("sim start");

        wait (TEST_STEP == 'h5);
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
        integer i;
    begin
        for (i = 0; i < 8*(len + 1); i = i + 1)
            @ (negedge scl) miso_mdl = in[127-i];
    end
    endtask

    task ENA_MST;
        input [3:0] len;
        input       ena_mdl;
    begin
        USE_MODEL = ena_mdl;
        mst_ctrl[7] = 'h1;
        mst_ctrl[3:0] = len;
        wait (mst_status[7]);
        mst_ctrl[7] = 'h0;
    end
    endtask

endmodule