// Register file for the accelerator

module accelerator_mem #(
    parameter  MEM_DEPTH = 32,
    localparam ADDR_MEM_WIDTH = $clog2(MEM_DEPTH)  // Number of bits required to address the MEMORY
) (
    input wire clk,
    input wire [3:0] wen,
    input wire [ADDR_MEM_WIDTH-1:0] addr,
    input wire [31:0] wdata,
    output wire[31:0] rdata
);
    reg [31:0] mem [0:MEM_DEPTH-1];

    assign rdata = mem[addr];

    always @(posedge clk) begin
        if (wen[0]) mem[addr][ 7: 0] <= wdata[ 7: 0];
        if (wen[1]) mem[addr][15: 8] <= wdata[15: 8];
        if (wen[2]) mem[addr][23:16] <= wdata[23:16];
        if (wen[3]) mem[addr][31:24] <= wdata[31:24];
    end
endmodule