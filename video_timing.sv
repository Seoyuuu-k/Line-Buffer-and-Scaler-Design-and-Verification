`timescale 1ns / 1ps

module video_timing_fsm #(
    // ----- Vertical timing -----
    parameter int VSW        = 1,
    parameter int VBP        = 1,
    parameter int VACT       = 4,
    parameter int VFP        = 1,

    // ----- Horizontal timing -----
    parameter int HSW        = 1,
    parameter int HBP        = 2,
    parameter int HACT       = 10,
    parameter int HFP        = 1,

    // ----- Polarity -----
    // 0: Active High, 1: Active Low
    parameter int VSYNC_POL  = 0,    
    parameter int HSYNC_POL  = 0      
)(
    input  logic        pclk,         // pixel clock
    input  logic        rstn,
    input  logic        i_start,     // 1 → 프레임 생성 시작
    input  int          i_frames,    // 생성할 프레임 수

    output logic        o_busy,      // 동작 중
    output logic        o_done,      // 모든 프레임 전송 완료 (1 pclk 펄스)

    input  logic [9:0]  i_r,
    input  logic [9:0]  i_g,
    input  logic [9:0]  i_b,

    output logic        o_vsync,
    output logic        o_hsync,
    output logic        o_de,
    output logic [9:0]  o_r, // de일때만 나오도록
    output logic [9:0]  o_g,
    output logic [9:0]  o_b
);

    typedef enum int {
        ST_IDLE = 0,
        ST_SW   = 1, // Sync With
        ST_BP   = 2, // Back porch
        ST_ACT  = 3, // Active
        ST_FP   = 4, // Front porch
        ST_END  = 5
    } state_t;

    // 수직/수평 상태 
    state_t vstate;
    state_t hstate;

    int v_line_cnt;   // 현재 vertical state에서 몇 번째 라인인지
    int h_pix_cnt;    // 현재 horizontal state에서 몇 번째 픽셀인지

    int frame_cnt;    // 보낸 프레임 수

    logic vsync_int, hsync_int, de_int;

    // 한 프레임 끝나는지 표시하는 내부 신호
    logic frame_done;

    always_comb begin
        frame_done = (vstate    == ST_FP)   &&
                     (v_line_cnt == VFP-1) &&
                     (hstate    == ST_FP)   &&
                     (h_pix_cnt == HFP-1);
    end

    // ========================================================
    //      수직/수평 FSM + 카운터
    // ========================================================
    always_ff @(posedge pclk or negedge rstn) begin
        if (!rstn) begin
            vstate     <= ST_IDLE;
            hstate     <= ST_IDLE;
            v_line_cnt <= 0;
            h_pix_cnt  <= 0;
            frame_cnt  <= 0;
            o_busy     <= 1'b0;
            o_done     <= 1'b0;
        end else begin
            o_done <= 1'b0;

            // ==================================
            // 1) busy가 아닌 상태 (대기/END 이후)
            // ==================================
            if (!o_busy) begin
                if (i_start) begin
                    // --- 새 프레임 시작 ---
                    o_busy     <= 1'b1;
                    frame_cnt  <= 0;
                    v_line_cnt <= 0;
                    h_pix_cnt  <= 0;
                    vstate     <= ST_SW;   // VSYNC부터 시작
                    hstate     <= ST_SW;   // HSYNC부터 시작
                end else begin
                    vstate <= ST_IDLE;
                    hstate <= ST_IDLE;
                end
            end

            // ==================================
            // 2) busy == 1 → FSM 동작 구간
            // ==================================
            else begin
                // 수평 FSM
                case (hstate)
                    ST_SW: begin
                        if (h_pix_cnt == HSW-1) begin
                            h_pix_cnt <= 0;
                            hstate    <= ST_BP;
                        end else begin
                            h_pix_cnt <= h_pix_cnt + 1;
                        end
                    end

                    ST_BP: begin
                        if (h_pix_cnt == HBP-1) begin
                            h_pix_cnt <= 0;
                            hstate    <= ST_ACT;
                        end else begin
                            h_pix_cnt <= h_pix_cnt + 1;
                        end
                    end

                    ST_ACT: begin
                        if (h_pix_cnt == HACT-1) begin
                            h_pix_cnt <= 0;
                            hstate    <= ST_FP;
                        end else begin
                            h_pix_cnt <= h_pix_cnt + 1;
                        end
                    end

                    ST_FP: begin
                        if (h_pix_cnt == HFP-1) begin
                            h_pix_cnt <= 0;
                            hstate    <= ST_SW;

                            // === 한 줄(line)이 끝났으므로 vertical FSM 갱신 ===
                            case (vstate)
                                ST_SW: begin
                                    if (v_line_cnt == VSW-1) begin
                                        v_line_cnt <= 0;
                                        vstate     <= ST_BP;
                                    end else begin
                                        v_line_cnt <= v_line_cnt + 1;
                                    end
                                end

                                ST_BP: begin
                                    if (v_line_cnt == VBP-1) begin
                                        v_line_cnt <= 0;
                                        vstate     <= ST_ACT;
                                    end else begin
                                        v_line_cnt <= v_line_cnt + 1;
                                    end
                                end

                                ST_ACT: begin
                                    if (v_line_cnt == VACT-1) begin
                                        v_line_cnt <= 0;
                                        vstate     <= ST_FP;
                                    end else begin
                                        v_line_cnt <= v_line_cnt + 1;
                                    end
                                end

                                ST_FP: begin
                                    if (v_line_cnt == VFP-1) begin
                                        v_line_cnt <= 0;
                                        if (frame_done) begin
                                              if (frame_cnt == i_frames-1) begin
                                                  // 마지막 프레임 → END
                                                  vstate <= ST_END;
                                                  hstate <= ST_END; 
                                                  o_busy <= 1'b0;    
                                                  o_done <= 1'b1;   
                                              end else begin
                                                  // 다음 프레임 시작
                                                  frame_cnt <= frame_cnt + 1;
                                                  vstate <= ST_SW;
                                              end
                                        end
                                    end else begin
                                        v_line_cnt <= v_line_cnt + 1;
                                    end
                                end

                                default: begin
                                    vstate <= ST_IDLE;
                                end
                            endcase
                        end else begin
                            h_pix_cnt <= h_pix_cnt + 1;
                        end
                    end

                    ST_END: begin
                        hstate <= ST_END;
                    end

                    default: begin
                        h_pix_cnt <= 0;
                        hstate    <= ST_SW;
                    end
                endcase
            end
        end
    end
    // ========================================================
    //      출력(vsync / hsync / de / RGB)
    // ========================================================

    always_comb begin
        vsync_int = (vstate == ST_SW);
        hsync_int = (hstate == ST_SW);
        de_int    = (vstate == ST_ACT) && (hstate == ST_ACT);
    end

    // 폴라리티 적용
    // 폴라리티 : 언제 Active 인지(동작하는 상태인지) 정의하는 용도!
    // 패널의 제조사/규격마다 정의가 다름
    // 범용으로 쓰려면 폴라리티 적용필요함!
    always_comb begin
        o_vsync = (VSYNC_POL == 0) ? vsync_int : ~vsync_int;
        o_hsync = (HSYNC_POL == 0) ? hsync_int : ~hsync_int;
        o_de    = de_int;
    end

    // RGB -> de_int == 1 일 때만 통과
    always_comb begin
        if (de_int) begin
            o_r = i_r;
            o_g = i_g;
            o_b = i_b;
        end else begin
            o_r = '0;
            o_g = '0;
            o_b = '0;
        end
    end


endmodule
