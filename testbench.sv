`timescale 1ns / 1ps

`include "clk_gen.sv"
`include "gen_rgb.sv"   // tb_rgb_random 이 들어있는 파일

module testbench;


  logic r_rst_n;
  logic r_clk_en;
  logic w_pclk;

  // clock generation
  clk_gen  #(
    .FREQ   (10**9    ),
    .DUTY   (60       ),
    .PHASE  (0        )
  ) u_clk_gen (
    .i_clk_en (r_clk_en ),
    .o_clk    (w_pclk   )
  );
  

  parameter int VSYNC_POL = 0;  // 0: Active High, 1: Active Low
  parameter int HSYNC_POL = 0;  // 0: Active High, 1: Active Low

  parameter int VSW   = 1;   // Vertical Sync Width [line]
  parameter int VBP   = 1;   // Vertical Back Porch [line]
  parameter int VACT  = 4;   // Vertical Active [line]
  parameter int VFP   = 1;   // Vertical Front Porch [line]

  parameter int HSW   = 1;   // Horizontal Sync Width [clock]
  parameter int HBP   = 2;   // Horizontal Back Porch [clock]
  parameter int HACT  = 10;  // Horizontal Active [clock]
  parameter int HFP   = 2;   // Horizontal Front Porch [clock]

  parameter int VTOT  = VSW + VBP + VACT + VFP; // Vertical Total [line]
  parameter int HTOT  = HSW + HBP + HACT + HFP; // Horizontal Total [Clock]


  logic       tb_start;
  int         tb_frames;
  logic       tb_busy;
  logic       tb_done;

  logic       tb_vsync, tb_hsync, tb_de;
  logic [9:0] tb_r, tb_g, tb_b;

  // TB에서 FSM에 넣어줄 랜덤 RGB
  logic [9:0] gen_r, gen_g, gen_b;

  logic       w_vsync, w_hsync, w_de;
  logic [9:0] w_red, w_green, w_blue;

  //==========================================================
  // Video Timing Generator FSM 인스턴스
  //==========================================================
  video_timing_fsm #(
    .VSW       (VSW),
    .VBP       (VBP),
    .VACT      (VACT),
    .VFP       (VFP),

    .HSW       (HSW),
    .HBP       (HBP),
    .HACT      (HACT),
    .HFP       (HFP),

    .VSYNC_POL (VSYNC_POL),
    .HSYNC_POL (HSYNC_POL)
  ) u_video_timing_fsm (
    .pclk     (w_pclk),
    .rstn     (r_rst_n),

    .i_start  (tb_start),
    .i_frames (tb_frames),

    .o_busy   (tb_busy),
    .o_done   (tb_done),

    .i_r      (gen_r),
    .i_g      (gen_g),
    .i_b      (gen_b),

    .o_vsync  (tb_vsync),
    .o_hsync  (tb_hsync),
    .o_de     (tb_de),
    .o_r      (tb_r),
    .o_g      (tb_g),
    .o_b      (tb_b)
  );

  //==========================================================
  // TB용 Random RGB Generator 
  //  de == 1일 때 매 픽셀마다 랜덤 RGB 생성
  //==========================================================
  tb_rgb_random #(
    .WIDTH(10)
  ) u_tb_rgb_random (
    .pclk (w_pclk),
    .rstn (r_rst_n),

    .o_r  (gen_r),
    .o_g  (gen_g),
    .o_b  (gen_b)
  );


  
  line_buf_ctrl_top u_line_buf_ctrl_top(
    .clk        (w_pclk  ),
    .rstn       (r_rst_n ),

    .i_vsync    (tb_vsync),
    .i_hsync    (tb_hsync),
    .i_de       (tb_de   ),
    .i_r_data   (tb_r    ),
    .i_g_data   (tb_g    ),
    .i_b_data   (tb_b    ),

    .o_vsync    (w_vsync ),
    .o_hsync    (w_hsync ),
    .o_de       (w_de    ),
    .o_r_data   (w_red   ),
    .o_g_data   (w_green ),
    .o_b_data   (w_blue  )
  );
 

  //==========================================================
  // Test Sequence
  //==========================================================
  initial begin
    r_rst_n   <= 0;
    r_clk_en  <= 1;
    tb_start  <= 0;
    tb_frames <= 5;   // 원하는 프레임 수

    testbench.u_clk_gen.clk_disp();

    #(20ns)
    r_rst_n <= 1;

    repeat (10) @(posedge w_pclk);

    // FSM 시작
    tb_start <= 1;
    @(posedge w_pclk);
    tb_start <= 0;

    // 완료될 때까지 대기
    wait(tb_done);

    repeat (100) @(posedge w_pclk);
    $finish;
  end

  //==========================================================
  // waveform dump
  //==========================================================
  initial begin
    $dumpfile("dump.vcd");
    $dumpvars(0, testbench);
  end

endmodule
