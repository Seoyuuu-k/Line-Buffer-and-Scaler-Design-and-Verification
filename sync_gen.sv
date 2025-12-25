// 트리구조의 계층형 task구성!


//------------------------------------------------
// Sync Generator TB Common
//------------------------------------------------

typedef enum int {
    ST_IDLE = 0,
    ST_SW   = 1,
    ST_BP   = 2,
    ST_ACT  = 3,
    ST_FP   = 4,
    ST_END  = 5
} state_t;

//------------------------------------------------
// 상태/신호/카운트
//------------------------------------------------
reg [2:0] r_vstate    = ST_IDLE; 
reg [2:0] r_hstate    = ST_IDLE; 

reg       r_vsync     = 0;
reg       r_hsync     = 0;
reg       r_de        = 0;
reg [9:0] r_red       = 0;
reg [9:0] r_green     = 0;
reg [9:0] r_blue      = 0;

int r_frame_cnt     = 0;
int r_vstate_cnt    = 0;
int r_hstate_cnt    = 0;

int r_hsw_cnt       = 0;
int r_hbp_cnt       = 0;
int r_hfp_cnt       = 0;
int r_hact_cnt      = 0;

int r_vsw_cnt       = 0;
int r_vbp_cnt       = 0;
int r_vfp_cnt       = 0;
int r_vact_cnt      = 0;
state_t cur_vstate;
state_t cur_hstate;



//------------------------------------------------
// Polarity → 패널 기준 레벨 정의
//   VSYNC_POL == 0 : Active High
//   VSYNC_POL == 1 : Active Low
//------------------------------------------------

localparam bit VSYNC_LEVEL_PULSE = (VSYNC_POL == 0) ? 1'b1 : 1'b0; 
localparam bit VSYNC_LEVEL_IDLE  = ~VSYNC_LEVEL_PULSE;

localparam bit HSYNC_LEVEL_PULSE = (HSYNC_POL == 0) ? 1'b1 : 1'b0;
localparam bit HSYNC_LEVEL_IDLE  = ~HSYNC_LEVEL_PULSE;

//------------------------------------------------
// Initialization (처음엔 idle 레벨로)
//------------------------------------------------
initial begin
    r_vsync = VSYNC_LEVEL_IDLE;
    r_hsync = HSYNC_LEVEL_IDLE;
    r_de    = 1'b0;
    r_red   = '0;
    r_green = '0;
    r_blue  = '0;
end

//------------------------------------------------
// [Core Task] Signal Drive and Counter Management
//------------------------------------------------
task task_drive_pixel(
    input bit          i_vsync,
    input bit          i_hsync,
    input bit          i_de,
    input logic [9:0]  i_r,
    input logic [9:0]  i_g,
    input logic [9:0]  i_b
);
    @(posedge w_pclk);

    // 패널 기준 레벨 그대로 내보냄
    r_vsync     <= i_vsync;
    r_hsync     <= i_hsync;
    r_de        <= i_de;
    r_red       <= i_r;
    r_green     <= i_g;
    r_blue      <= i_b;

    // 상태 기록
    r_vstate    <= cur_vstate;
    r_hstate    <= cur_hstate;
  
  	//디버깅용 카운트
    if (cur_hstate == ST_SW)       r_hsw_cnt++;
    else if (cur_hstate == ST_BP)  r_hbp_cnt++;
    else if (cur_hstate == ST_ACT) r_hact_cnt++;
    else if (cur_hstate == ST_FP)  r_hfp_cnt++;

    if (cur_vstate == ST_SW)       r_vsw_cnt++;
    else if (cur_vstate == ST_BP)  r_vbp_cnt++;
    else if (cur_vstate == ST_ACT) r_vact_cnt++;
    else if (cur_vstate == ST_FP)  r_vfp_cnt++;
    
    r_hstate_cnt++; 
    r_vstate_cnt++; 

endtask


//------------------------------------------------
// [Reset Task] Reset Horizontal Counters
//------------------------------------------------
task task_h_reset();
    r_hsw_cnt    = 0;
    r_hbp_cnt    = 0;
    r_hfp_cnt    = 0;
    r_hact_cnt   = 0;
    r_hstate_cnt = 0;
endtask

//------------------------------------------------
// [Reset Task] Reset Vertical Counters
//------------------------------------------------
task task_v_reset();
    r_vsw_cnt    = 0;
    r_vbp_cnt    = 0;
    r_vfp_cnt    = 0;
    r_vact_cnt   = 0;
    r_vstate_cnt = 0;
endtask

//------------------------------------------------

//------------------------------------------------
// [RGB Pattern Task] Generate RGB Pattern
//------------------------------------------------
task task_gen_rgb(
    output logic [9:0] o_r,
    output logic [9:0] o_g,
    output logic [9:0] o_b
);
    o_r = $urandom_range(0, 1023);
    o_g = $urandom_range(0, 1023);
    o_b = $urandom_range(0, 1023);
endtask

//------------------------------------------------
// [Line Task] Generate 1 Horizontal Line
//------------------------------------------------
task task_run_one_line(
    input state_t v_mode
);
    int   i;
    bit   v_active;
    bit   drv_vsync, drv_hsync, drv_de;
    logic [9:0] drv_r, drv_g, drv_b;

    // 수직 상태 설정
    cur_vstate = v_mode;

    // VSYNC : ST_SW 구간에는 펄스, 나머지는 idle
    if (v_mode == ST_SW)
        drv_vsync = VSYNC_LEVEL_PULSE;
    else
        drv_vsync = VSYNC_LEVEL_IDLE;

    v_active = (v_mode == ST_ACT);
  	task_h_reset(); 


    // ---------------------------
    // HSW 구간 (수평 Sync 펄스)
    // ---------------------------
    cur_hstate = ST_SW;
    drv_hsync  = HSYNC_LEVEL_PULSE;
    drv_de     = 1'b0;
    drv_r = 0; drv_g = 0; drv_b = 0;
    for(i=0; i<HSW; i++) begin
        task_drive_pixel(drv_vsync, drv_hsync, drv_de,
                          drv_r, drv_g, drv_b);
    end

    // ---------------------------
    // HBP 구간 (Idle)
    // ---------------------------
    cur_hstate = ST_BP;
    drv_hsync  = HSYNC_LEVEL_IDLE;
    drv_de     = 1'b0;
    drv_r = 0; drv_g = 0; drv_b = 0;
    for(i=0; i<HBP; i++) begin
        task_drive_pixel(drv_vsync, drv_hsync, drv_de,
                          drv_r, drv_g, drv_b);
    end

    // ---------------------------
    // HACT (Active Pixel)
// ---------------------------
    cur_hstate = ST_ACT;
    drv_hsync  = HSYNC_LEVEL_IDLE;   
    for(i=0; i<HACT; i++) begin
        if (v_active) begin
            drv_de = 1'b1;
            task_gen_rgb(drv_r, drv_g, drv_b);
        end else begin
            drv_de = 1'b0;
            drv_r  = 0;
            drv_g  = 0;
            drv_b  = 0;
        end
        task_drive_pixel(drv_vsync, drv_hsync, drv_de,
                          drv_r, drv_g, drv_b);
    end

    // ---------------------------
    // HFP 
    // ---------------------------
    cur_hstate = ST_FP;
    drv_hsync  = HSYNC_LEVEL_IDLE;
    drv_de     = 1'b0;
    drv_r = 0; drv_g = 0; drv_b = 0;
    for(i=0; i<HFP; i++) begin
        task_drive_pixel(drv_vsync, drv_hsync, drv_de,
                          drv_r, drv_g, drv_b);
    end
endtask

//------------------------------------------------
// [Frame Task] Generate ONE Frame
//------------------------------------------------
task task_run_one_frame();
  int line;
  task_v_reset();
      
  for(line=0; line<VSW;  line++) task_run_one_line(ST_SW);
  for(line=0; line<VBP;  line++) task_run_one_line(ST_BP);
  for(line=0; line<VACT; line++) task_run_one_line(ST_ACT);
  for(line=0; line<VFP;  line++) task_run_one_line(ST_FP);
endtask


//------------------------------------------------
// [N-Frame Task] Generate N Frames
//------------------------------------------------
task task_video_timing_gen(input int i_frames);
    int f;
  	r_frame_cnt = 0;
    cur_vstate    = ST_IDLE;
    cur_hstate    = ST_IDLE;
    

    // 1) 시작할 때 idle 상태 한 번 출력
    task_drive_pixel(VSYNC_LEVEL_IDLE, HSYNC_LEVEL_IDLE, 1'b0,
                      10'd0, 10'd0, 10'd0);

    // 2) N 프레임 생성
    for(f=0; f < i_frames; f++) begin
     	 r_frame_cnt++;
        task_run_one_frame();   // 프레임 단위 Task 호출
    end

    // 3) 끝 상태 & 카운터 정리
    cur_vstate    = ST_END;
    cur_hstate    = ST_END;
  
 	r_vstate_cnt = 0;
    r_hstate_cnt = 0;
    
    
    // 4) 마지막도 idle 상태로 정리
    task_drive_pixel(VSYNC_LEVEL_IDLE, HSYNC_LEVEL_IDLE, 1'b0,
                      10'd0, 10'd0, 10'd0);
endtask