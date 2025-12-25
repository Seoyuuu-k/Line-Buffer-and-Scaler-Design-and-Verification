// tb_rgb_random.sv
module tb_rgb_random #(
    parameter int WIDTH = 10
)(
    input  logic             pclk,
    input  logic             rstn,
    // de 안 씀! 항상 랜덤 생성만 함
    output logic [WIDTH-1:0] o_r,
    output logic [WIDTH-1:0] o_g,
    output logic [WIDTH-1:0] o_b
);

    always_ff @(posedge pclk or negedge rstn) begin
        if (!rstn) begin
            o_r <= '0;
            o_g <= '0;
            o_b <= '0;
        end else begin
            // 매 clk마다 랜덤 값
            o_r <= $urandom_range(0, (1<<WIDTH)-1);
            o_g <= $urandom_range(0, (1<<WIDTH)-1);
            o_b <= $urandom_range(0, (1<<WIDTH)-1);
        end
    end

endmodule
