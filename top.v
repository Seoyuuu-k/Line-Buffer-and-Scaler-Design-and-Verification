`timescale 1ns / 1ps

module line_buf_ctrl_top #(
    parameter int VSW        = 1,
    parameter int VBP        = 1,
    parameter int VACT       = 4,
    parameter int VFP        = 1,

    parameter int HSW        = 1,
    parameter int HBP        = 2,
    parameter int HACT       = 10,
    parameter int HFP        = 1,

    parameter int ADDR_WIDTH = 10,
    parameter int DATA_WIDTH = 30,
    parameter int VSYNC_POL  = 0,    // 0: active high, 1: active low
    parameter int HSYNC_POL  = 0     // 0: active high, 1: active low
)(
    input              clk,
    input              rstn,
    input              i_vsync,
    input              i_hsync,
    input              i_de,
    input       [9:0]  i_r_data,
    input       [9:0]  i_g_data,
    input       [9:0]  i_b_data,
    output             o_vsync,
    output             o_hsync,
    output             o_de,
    output      [9:0]  o_r_data,
    output      [9:0]  o_g_data,
    output      [9:0]  o_b_data
);

    logic                  cs1, we1;
    logic                  cs2, we2;
    logic [ADDR_WIDTH-1:0] addr1, addr2;
    logic [DATA_WIDTH-1:0] din1,  din2;
    logic [DATA_WIDTH-1:0] dout1, dout2;

    localparam int VTOTAL = VSW + VBP + VACT + VFP;
    localparam int HTOTAL = HSW + HBP + HACT + HFP;




    line_buf_ctrl #(
        .VSW       (VSW),
        .VBP       (VBP),
        .VACT      (VACT),
        .VFP       (VFP),
        .VTOTAL    (VTOTAL),
        .HSW       (HSW),
        .HBP       (HBP),
        .HACT      (HACT),
        .HFP       (HFP),
        .HTOTAL    (HTOTAL),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .VSYNC_POL (VSYNC_POL),
        .HSYNC_POL (HSYNC_POL)
    ) u_line_buf_ctrl (
        .clk      (clk),
        .rstn     (rstn),

        .i_vsync  (i_vsync),
        .i_hsync  (i_hsync),
        .i_de     (i_de),
        .i_r_data (i_r_data),
        .i_g_data (i_g_data),
        .i_b_data (i_b_data),

        .o_vsync  (o_vsync),
        .o_hsync  (o_hsync),
        .o_de     (o_de),
        .o_r_data (o_r_data),
        .o_g_data (o_g_data),
        .o_b_data (o_b_data),

        .o_cs1    (cs1),
        .o_we1    (we1),
        .o_cs2    (cs2),
        .o_we2    (we2),

        .o_addr1  (addr1),
        .o_din1   (din1),
        .o_addr2  (addr2),
        .o_din2   (din2),

        .i_dout1  (dout1),
        .i_dout2  (dout2)
    );


    single_port_ram #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) U_SRAM1 (
        .clk   (clk),
        .i_cs  (cs1),
        .i_we  (we1),
        .i_addr(addr1),
        .i_din (din1),
        .o_dout(dout1)
    );

    single_port_ram #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) U_SRAM2 (
        .clk   (clk),
        .i_cs  (cs2),
        .i_we  (we2),
        .i_addr(addr2),
        .i_din (din2),
        .o_dout(dout2)
    );

endmodule


module line_buf_ctrl #(
    parameter int VSW        = 1,
    parameter int VBP        = 1,
    parameter int VACT       = 4,
    parameter int VFP        = 1,
    parameter int VTOTAL    = 7,

    // ----- Horizontal timing -----
    parameter int HSW        = 1,
    parameter int HBP        = 2,
    parameter int HACT       = 10,
    parameter int HFP        = 1,
    parameter int HTOTAL     = 14,

    parameter int ADDR_WIDTH = 10,
    parameter int DATA_WIDTH = 30,
    parameter int VSYNC_POL  = 0,    // 0: active high, 1: active low
    parameter int HSYNC_POL  = 0     // 0: active high, 1: active low
)(
    input                    clk,
    input                    rstn,

    input                    i_vsync,
    input                    i_hsync,
    input                    i_de,
    input       [9:0]        i_r_data,
    input       [9:0]        i_g_data,
    input       [9:0]        i_b_data,

    output  logic            o_vsync,
    output  logic            o_hsync,
    output  logic            o_de,
    output  logic [9:0]      o_r_data,
    output  logic [9:0]      o_g_data,
    output  logic [9:0]      o_b_data,

    // --- External RAM control ---
    output logic             o_cs1,
    output logic             o_we1,
    output logic             o_cs2,
    output logic             o_we2,

    output logic [ADDR_WIDTH-1:0] o_addr1,
    output logic [DATA_WIDTH-1:0] o_din1,
    output logic [ADDR_WIDTH-1:0] o_addr2,
    output logic [DATA_WIDTH-1:0] o_din2,
    input  logic [DATA_WIDTH-1:0] i_dout1,
    input  logic [DATA_WIDTH-1:0] i_dout2
);

  
    wire vsync_act = (VSYNC_POL == 0) ? i_vsync : ~i_vsync;
    wire hsync_act = (HSYNC_POL == 0) ? i_hsync : ~i_hsync; 
    wire de_act    = i_de;   

    logic vsync_d, de_d;

    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            vsync_d <= 1'b0;
            de_d    <= 1'b0;
        end else begin
            vsync_d <= vsync_act;
            de_d    <= de_act;
        end
    end

    wire vsync_rise = (~vsync_d &  vsync_act);   // 프레임 시작
    wire de_rise    = (~de_d    &  de_act);      // 한 라인 시작



    typedef enum int {
        ST_IDLE           = 0,
        ST_LINE_DELAY     = 1,
        ST_VSW            = 2,
        ST_FIRST_DE_WAIT  = 3, 
        ST_FIRST_LINE_ACT = 4, 
        ST_ACTIVE_WAIT    = 5,
        ST_LINE_ACTIVE    = 6,
        ST_LAST_LINE_WAIT = 7,
        ST_LAST_LINE_ACT  = 8,
        ST_END            = 9
    } state_t;

    state_t state;

    int p_cnt;
    int cnt_hact;
    int cnt_vact;


    //폴라리티반영!!!
    wire vsync_pol = (VSYNC_POL==0)? 1'b1 :1'b0;
    wire hsync_pol = (HSYNC_POL==0)? 1'b1 :1'b0;

    //====================================================
    // FSM
    //====================================================
    always_ff @(posedge clk or negedge rstn) begin 
        if (!rstn) begin
            state   <= ST_IDLE;

            p_cnt     <= 0;
            cnt_hact  <= 0;
            cnt_vact  <= 0;

            o_cs1   <= 1'b0; o_we1   <= 1'b0;
            o_cs2   <= 1'b0; o_we2   <= 1'b0;

            o_vsync <= ~vsync_pol;
            o_hsync <= ~hsync_pol;
            o_de    <= 1'b0;

            o_addr1 <= '0;
            o_addr2 <= '0;
            o_din1  <= '0;
            o_din2  <= '0;
        end else begin
            o_cs1   <= 1'b0; o_we1   <= 1'b0;
            o_cs2   <= 1'b0; o_we2   <= 1'b0;

            o_vsync <= ~vsync_pol;
            o_hsync <= ~hsync_pol;
            o_de    <= 1'b0;

            o_addr1 <= '0;
            o_addr2 <= '0;
            o_din1  <= '0;
            o_din2  <= '0;

            case (state) 
                //-----------------------------------------
                ST_IDLE : begin
                    if (vsync_rise) begin
                        p_cnt    <= 0;
                        cnt_vact <= 0;
                        state    <= ST_LINE_DELAY;
                    end
                end

                //-----------------------------------------
                // 한 라인 delay (전체 HTOTAL 만큼)
                //-----------------------------------------
                ST_LINE_DELAY : begin
                    if (p_cnt == HTOTAL-1) begin
                        p_cnt <= 0;
                        state <= ST_VSW;
                        o_vsync <= vsync_pol;       
                        o_hsync <= i_hsync;     
                    end else begin
                        p_cnt <= p_cnt + 1;
                    end
                end 

                //-----------------------------------------
                // VSW 구간
                //-----------------------------------------
                ST_VSW : begin
                    o_vsync <= vsync_pol;       
                    o_hsync <= i_hsync;     

                    if (p_cnt == (HTOTAL*VSW)-1) begin
                        p_cnt <= 0;
                        state <= ST_FIRST_DE_WAIT;
                        o_vsync <= ~vsync_pol;
                        o_hsync <= i_hsync;
                    end else begin
                        p_cnt <= p_cnt + 1;
                    end
                end 
            
                //-----------------------------------------
                // 첫 Active 라인 시작 대기 (DE rise)
                //-----------------------------------------
                ST_FIRST_DE_WAIT : begin
                    o_vsync <= ~vsync_pol;
                    o_hsync <= i_hsync;

                    if (de_rise) begin
                        p_cnt    <= 0;
                        state    <= ST_FIRST_LINE_ACT;
                        cnt_vact <= 0;
                        o_vsync <= ~vsync_pol;
                        o_hsync <= i_hsync;
                        o_de    <= 1'b0; // 0으로 강제

                        o_cs1   <= 1'b1; o_we1 <= 1'b1;
                        o_cs2   <= 1'b0; o_we2 <= 1'b0;

                        o_addr1 <= p_cnt; 
                        o_addr2 <= '0;
                        o_din1  <= {i_r_data, i_g_data, i_b_data};
                        o_din2  <= '0;
                    end
                end

                //-----------------------------------------
                // 첫 Active 라인: 쓰기만, 출력 0
                //-----------------------------------------
                ST_FIRST_LINE_ACT : begin
                    o_vsync <= ~vsync_pol;
                    o_hsync <= i_hsync;
                    o_de    <= 1'b0; // 0으로 강제

                    o_cs1   <= 1'b1; o_we1 <= 1'b1;
                    o_cs2   <= 1'b0; o_we2 <= 1'b0;

                    o_addr1 <= p_cnt+1; 
                    o_addr2 <= '0;
                    o_din1  <= {i_r_data, i_g_data, i_b_data};
                    o_din2  <= '0;
                
                  if (p_cnt == HACT-1) begin
                        p_cnt    <= 0;
                        state    <= ST_ACTIVE_WAIT;
                        cnt_vact <=  1;
                        o_de <= 1'b0;
                        o_vsync <= ~vsync_pol;
                        o_hsync <= i_hsync;

                        o_cs1   <= 1'b0; o_we1 <= 1'b0;
                        o_cs2   <= 1'b0; o_we2 <= 1'b0;
                        o_addr1 <= '0; 
                        o_addr2 <= '0;
                        o_din1  <= '0;
                        o_din2  <= '0;
                    end else begin
                        p_cnt <= p_cnt + 1;
                    end
                end 
               
                //-----------------------------------------
                // 다음 라인 DE 기다림
                //-----------------------------------------
                ST_ACTIVE_WAIT : begin
                    o_de <= 1'b0;
                    o_vsync <= ~vsync_pol;
                    o_hsync <= i_hsync;

                    if (de_rise) begin
                        p_cnt <= 0;
                        state <= ST_LINE_ACTIVE;

                        o_vsync <= ~vsync_pol;
                        o_hsync <= i_hsync;
                        o_de    <= 1'b1;

                        if ((cnt_vact % 2) == 1) begin // 홀수 라인
                        o_cs1   <= 1'b1; o_we1 <= 1'b0;
                        o_cs2   <= 1'b1; o_we2 <= 1'b1;

                        o_addr1 <= p_cnt; // 이전주소 읽기
                        o_addr2 <= p_cnt;   // 현재주소 쓰기
                        o_din1  <= '0;
                        o_din2  <= {i_r_data, i_g_data, i_b_data};
                        end else begin            // 짝수 라인
                            o_cs1   <= 1'b1; o_we1 <= 1'b1;
                            o_cs2   <= 1'b1; o_we2 <= 1'b0;

                            o_addr1 <= p_cnt; 
                            o_addr2 <= p_cnt;
                            o_din1  <= {i_r_data, i_g_data, i_b_data};
                            o_din2  <= '0;
                        end
                    end
                end
                


                //-----------------------------------------
                // 중간 라인들: 읽기 + 쓰기
                //-----------------------------------------
                ST_LINE_ACTIVE : begin
                    o_vsync <= ~vsync_pol;
                    o_hsync <= i_hsync;
                    o_de    <= 1'b1;

                  if ((cnt_vact % 2) == 1) begin // 홀수 라인
                        o_cs1   <= 1'b1; o_we1 <= 1'b0;
                        o_cs2   <= 1'b1; o_we2 <= 1'b1;

                        o_addr1 <= p_cnt+1; 
                        o_addr2 <= p_cnt+1;  
                        o_din1  <= '0;
                        o_din2  <= {i_r_data, i_g_data, i_b_data};
                    end else begin            // 짝수 라인
                        o_cs1   <= 1'b1; o_we1 <= 1'b1;
                        o_cs2   <= 1'b1; o_we2 <= 1'b0;

                        o_addr1 <= p_cnt+1; 
                        o_addr2 <= p_cnt+1;
                        o_din1  <= {i_r_data, i_g_data, i_b_data};
                        o_din2  <= '0;
                    end
                
                  if (p_cnt == HACT-1) begin
                        p_cnt <= 0;

                        if (cnt_vact == VACT-1) begin
                            cnt_vact <= 0;
                            state    <= ST_LAST_LINE_WAIT;
                            o_de <= 1'b0;
                            o_vsync <= ~vsync_pol;
                            o_hsync <= i_hsync;
                            o_cs1   <= 1'b0; o_we1 <= 1'b0;
                            o_cs2   <= 1'b0; o_we2 <= 1'b0;
                            o_addr1 <= '0; 
                            o_addr2 <= '0;
                            o_din1  <= '0;
                            o_din2  <= '0;
                        end else begin
                            cnt_vact <= cnt_vact + 1;
                            state    <= ST_ACTIVE_WAIT;
                            o_de <= 1'b0;
                            o_vsync <= ~vsync_pol;
                            o_hsync <= i_hsync;
                            o_cs1   <= 1'b0; o_we1 <= 1'b0;
                            o_cs2   <= 1'b0; o_we2 <= 1'b0;
                            o_addr1 <= '0; 
                            o_addr2 <= '0;
                            o_din1  <= '0;
                            o_din2  <= '0;
                        end
                    end else begin
                        p_cnt <= p_cnt + 1;
                    end
                end

                //-----------------------------------------
                // 마지막 라인 전의 HSW/HBP/HFP 기다림
                //-----------------------------------------
                ST_LAST_LINE_WAIT : begin
                    if (p_cnt == (HFP + HBP + HSW) - 1) begin
                        p_cnt <= 0;
                        state <= ST_LAST_LINE_ACT;
                        o_vsync <= ~vsync_pol;
                        o_hsync <= i_hsync;
                        o_de    <= 1'b1; // 1로 강제

                        if ((cnt_vact % 2) == 1) begin // 홀수 라인
                                o_cs1   <= 1'b1; o_we1 <= 1'b0;
                                o_cs2   <= 1'b0; o_we2 <= 1'b0;
                                o_addr1 <= '0;   o_addr2 <= '0;  
                                o_din1  <= '0;   o_din2  <= '0;
                                end else begin            // 짝수 라인
                                    o_cs1   <= 1'b0; o_we1 <= 1'b0;
                                    o_cs2   <= 1'b1; o_we2 <= 1'b0;
                                    o_addr1 <= '0; o_addr2 <= '0;
                                    o_din1  <= '0;
                                    o_din2  <= '0;
                                end

                    end else begin
                        p_cnt <= p_cnt + 1;
                    end
                end 
               
                //-----------------------------------------
                // 마지막 라인 Active
                //-----------------------------------------
                ST_LAST_LINE_ACT : begin
                    o_vsync <= ~vsync_pol;
                    o_hsync <= i_hsync;
                    o_de    <= 1'b1; // 1로 강제


                    if ((cnt_vact % 2) == 1) begin // 홀수 라인
                                o_cs1   <= 1'b1; o_we1 <= 1'b0;
                                o_cs2   <= 1'b0; o_we2 <= 1'b0;
                                o_addr1 <= p_cnt+1;  o_addr2 <= '0;  
                                o_din1  <= '0;       o_din2  <= '0;
                            end else begin // 짝수 라인
                                o_cs1   <= 1'b0; o_we1 <= 1'b0;
                                o_cs2   <= 1'b1; o_we2 <= 1'b0;
                                o_addr1 <= '0;   o_addr2 <= p_cnt+1;
                                o_din1  <= '0;   o_din2  <= '0;
                        end


                    if (p_cnt == HACT-1) begin
                        p_cnt <= 0;
                        state <= ST_END;
                        o_vsync <= ~vsync_pol;
                        o_hsync <= i_hsync;
                        o_de    <= 1'b0;

                        
                    end else begin
                        p_cnt <= p_cnt + 1;
                    end
                end

                //-----------------------------------------
                ST_END : begin
                    o_vsync <= ~vsync_pol;
                    o_hsync <= i_hsync;
                    o_de    <= 1'b0;

                    if (vsync_rise) begin
                        p_cnt    <= 0;
                        cnt_vact <= 0;
                        state    <= ST_LINE_DELAY;
                    end
                end
            endcase
        end
    end



  wire [DATA_WIDTH-1:0] rgb_from_ram = ((cnt_vact % 2) == 1) ? i_dout1 : i_dout2;


always_comb begin
    o_r_data = 10'd0;
    o_g_data = 10'd0;
    o_b_data = 10'd0;

    if (rstn) begin
        if (o_de) begin
            o_r_data = rgb_from_ram[29:20];
            o_g_data = rgb_from_ram[19:10];
            o_b_data = rgb_from_ram[9:0];
        end
        else begin
            o_r_data = 10'd0;
            o_g_data = 10'd0;
            o_b_data = 10'd0;
        end
    end
end
endmodule