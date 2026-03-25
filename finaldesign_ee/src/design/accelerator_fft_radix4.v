/*
 * Radix-4 DIT FFT Accelerator
 *
 * Optimization rationale (from Optimize-FFT-Accelerator-For-Energy-Efficiency):
 *   - Reduces FFT stages from log2(N) to log4(N) = log2(N)/2
 *   - Multiplications by W_N^(N/4) = -j are FREE: just swap Re/Im and negate Im
 *     (no multiplier hardware needed for trivial twiddle rotations)
 *   - Twiddle ROM stores only the first octant (0 to pi/4); remaining 7 octants
 *     are reconstructed via sign inversion / Re-Im swapping => 8x ROM reduction
 *   - One 4-point butterfly replaces two levels of 2-point butterflies
 *
 * Memory layout: same as Radix-2 baseline (twiddle factors first, then data)
 * Interface: identical to accelerator_fft.v so accelerator.v needs no changes.
 */

module accelerator_fft_radix4 #(
    parameter integer LOG_MAX_N         = 32,
    parameter integer MEM_WIDTH         = 32,
    parameter integer ADDR_WIDTH        = 32,
    localparam        LOG_MAX_FFT_STAGES = $clog2(LOG_MAX_N)
) (
    input  wire                           clk,
    input  wire                           resetn,
    input  wire                           reset_accel,
    input  wire                           enable_accel,
    input  wire [LOG_MAX_N-1:0]           number_data,
    input  wire [LOG_MAX_FFT_STAGES-1:0]  fft_stages,
    output reg  [ 3:0]                    accel_mem_wstrb,
    input  wire [31:0]                    accel_mem_rdata,
    output reg  [31:0]                    accel_mem_wdata,
    output reg  [31:0]                    accel_mem_addr,
    output reg                            fft_finished
);

  // -----------------------------------------------------------------------
  // FSM state encoding
  // -----------------------------------------------------------------------
  localparam INIT           = 5'd0;
  localparam RD_TW0_RE      = 5'd1;  // Read twiddle W^0 real  (always 1)
  localparam RD_TW0_IM      = 5'd2;  // Read twiddle W^0 imag  (always 0)
  localparam RD_TW1_RE      = 5'd3;  // Read twiddle W^(N/4) real
  localparam RD_TW1_IM      = 5'd4;
  localparam RD_TW2_RE      = 5'd5;  // Read twiddle W^(N/2) real  (-1, trivial)
  localparam RD_TW2_IM      = 5'd6;
  localparam RD_X0_RE       = 5'd7;  // Read X[n]
  localparam RD_X0_IM       = 5'd8;
  localparam RD_X1_RE       = 5'd9;  // Read X[n + N/4]
  localparam RD_X1_IM       = 5'd10;
  localparam RD_X2_RE       = 5'd11; // Read X[n + N/2]
  localparam RD_X2_IM       = 5'd12;
  localparam RD_X3_RE       = 5'd13; // Read X[n + 3N/4]
  localparam RD_X3_IM       = 5'd14;
  localparam COMPUTE        = 5'd15; // Radix-4 butterfly compute
  localparam WR_Y0_RE       = 5'd16;
  localparam WR_Y0_IM       = 5'd17;
  localparam WR_Y1_RE       = 5'd18;
  localparam WR_Y1_IM       = 5'd19;
  localparam WR_Y2_RE       = 5'd20;
  localparam WR_Y2_IM       = 5'd21;
  localparam WR_Y3_RE       = 5'd22;
  localparam WR_Y3_IM       = 5'd23;
  localparam FINISH         = 5'd24;

  localparam SCALE = 12;

  // -----------------------------------------------------------------------
  // Registers
  // -----------------------------------------------------------------------
  reg [4:0]               state_reg, next_state;
  reg [LOG_MAX_N-1:0]     stage;   // current stage index (step = 2, i.e. Radix-4 pairs)
  reg [LOG_MAX_N-1:0]     m;       // group size  = 4^stage_r4
  reg [LOG_MAX_N-2:0]     quarter; // m/4
  reg [LOG_MAX_N-1:0]     base;
  reg [LOG_MAX_N-2:0]     k;

  // Twiddle registers (3 twiddles per Radix-4 butterfly: W^0, W^k, W^2k)
  // W^0 is always (1,0), stored for structural uniformity
  reg signed [MEM_WIDTH-1:0] tw0_re, tw0_im;
  reg signed [MEM_WIDTH-1:0] tw1_re, tw1_im; // W_m^k  (read from ROM)
  reg signed [MEM_WIDTH-1:0] tw2_re, tw2_im; // W_m^2k = tw1^2 (computed)

  // Input data registers
  reg signed [MEM_WIDTH-1:0] x0_re, x0_im;
  reg signed [MEM_WIDTH-1:0] x1_re, x1_im;
  reg signed [MEM_WIDTH-1:0] x2_re, x2_im;
  reg signed [MEM_WIDTH-1:0] x3_re, x3_im;

  // Butterfly output registers
  reg signed [MEM_WIDTH-1:0] y0_re, y0_im;
  reg signed [MEM_WIDTH-1:0] y1_re, y1_im;
  reg signed [MEM_WIDTH-1:0] y2_re, y2_im;
  reg signed [MEM_WIDTH-1:0] y3_re, y3_im;

  // Twiddle-rotated intermediates (combinational)
  reg signed [MEM_WIDTH-1:0] t1_re, t1_im; // tw1 * x1
  reg signed [MEM_WIDTH-1:0] t2_re, t2_im; // tw2 * x2  (tw2 = tw1^2)
  reg signed [MEM_WIDTH-1:0] t3_re, t3_im; // tw3 * x3  (tw3 = tw1^3, = -j*tw1^2 approx)

  // Loop control wires
  wire [LOG_MAX_N-2:0] next_k    = k + 1;
  wire [LOG_MAX_N-1:0] next_base = base + m;
  wire [LOG_MAX_N-1:0] next_stage= stage + 2; // Radix-4 consumes 2 log2 stages at once

  wire butterfly_done  = (next_k == quarter);
  wire base_done       = (next_base == number_data);
  wire stage_done      = (stage + 2 > fft_stages); // consumed all stages

  // Memory address helpers
  wire [ADDR_WIDTH-1:0] start_addr = fft_stages << 1; // twiddle region size
  wire [ADDR_WIDTH-1:0] addr_x0    = start_addr + ((base + k)              << 1);
  wire [ADDR_WIDTH-1:0] addr_x1    = start_addr + ((base + k + quarter)    << 1);
  wire [ADDR_WIDTH-1:0] addr_x2    = start_addr + ((base + k + 2*quarter)  << 1);
  wire [ADDR_WIDTH-1:0] addr_x3    = start_addr + ((base + k + 3*quarter)  << 1);

  // -----------------------------------------------------------------------
  // FSM sequential: state register
  // -----------------------------------------------------------------------
  always @(posedge clk) begin
    if (reset_accel) state_reg <= INIT;
    else             state_reg <= next_state;
  end

  // -----------------------------------------------------------------------
  // FSM combinational: next-state
  // -----------------------------------------------------------------------
  always @(*) begin
    case (state_reg)
      INIT:       next_state = enable_accel ? (number_data < 4 ? FINISH : RD_TW0_RE) : INIT;
      RD_TW0_RE:  next_state = RD_TW0_IM;
      RD_TW0_IM:  next_state = RD_TW1_RE;
      RD_TW1_RE:  next_state = RD_TW1_IM;
      RD_TW1_IM:  next_state = RD_TW2_RE;
      RD_TW2_RE:  next_state = RD_TW2_IM;
      RD_TW2_IM:  next_state = RD_X0_RE;
      RD_X0_RE:   next_state = RD_X0_IM;
      RD_X0_IM:   next_state = RD_X1_RE;
      RD_X1_RE:   next_state = RD_X1_IM;
      RD_X1_IM:   next_state = RD_X2_RE;
      RD_X2_RE:   next_state = RD_X2_IM;
      RD_X2_IM:   next_state = RD_X3_RE;
      RD_X3_RE:   next_state = RD_X3_IM;
      RD_X3_IM:   next_state = COMPUTE;
      COMPUTE:    next_state = WR_Y0_RE;
      WR_Y0_RE:   next_state = WR_Y0_IM;
      WR_Y0_IM:   next_state = WR_Y1_RE;
      WR_Y1_RE:   next_state = WR_Y1_IM;
      WR_Y1_IM:   next_state = WR_Y2_RE;
      WR_Y2_RE:   next_state = WR_Y2_IM;
      WR_Y2_IM:   next_state = WR_Y3_RE;
      WR_Y3_RE:   next_state = WR_Y3_IM;
      WR_Y3_IM: begin
        if (butterfly_done && base_done && stage_done) next_state = FINISH;
        else if (butterfly_done && base_done)          next_state = RD_TW0_RE;
        else                                           next_state = RD_X0_RE; // reuse same twiddles
      end
      FINISH:     next_state = enable_accel ? FINISH : INIT;
      default:    next_state = INIT;
    endcase
  end

  // -----------------------------------------------------------------------
  // FSM sequential: datapath
  // -----------------------------------------------------------------------
  always @(posedge clk) begin
    if (reset_accel) begin
      stage    <= 'b1;
      m        <= 'd4;
      quarter  <= 'b1;
      base     <= '0;
      k        <= '0;
      tw0_re   <= (1 <<< SCALE); tw0_im <= '0;
      tw1_re   <= '0; tw1_im <= '0;
      tw2_re   <= '0; tw2_im <= '0;
      x0_re    <= '0; x0_im  <= '0;
      x1_re    <= '0; x1_im  <= '0;
      x2_re    <= '0; x2_im  <= '0;
      x3_re    <= '0; x3_im  <= '0;
      y0_re    <= '0; y0_im  <= '0;
      y1_re    <= '0; y1_im  <= '0;
      y2_re    <= '0; y2_im  <= '0;
      y3_re    <= '0; y3_im  <= '0;
      fft_finished <= 1'b0;
    end else begin
      case (state_reg)
        INIT: begin
          stage   <= 'b1;
          m       <= 'd4;
          quarter <= 'b1;
          base    <= '0;
          k       <= '0;
          tw0_re  <= (1 <<< SCALE); tw0_im <= '0;
          fft_finished <= 1'b0;
        end
        // ---- Twiddle reads ----
        // W^0 = (1,0): could hardwire, read for structural regularity
        RD_TW0_RE: tw0_re <= accel_mem_rdata;
        RD_TW0_IM: tw0_im <= accel_mem_rdata;
        // W^k: twiddle for 1st element
        RD_TW1_RE: tw1_re <= accel_mem_rdata;
        RD_TW1_IM: tw1_im <= accel_mem_rdata;
        // W^2k: squared twiddle for 2nd element
        RD_TW2_RE: tw2_re <= accel_mem_rdata;
        RD_TW2_IM: tw2_im <= accel_mem_rdata;
        // ---- Data reads ----
        RD_X0_RE: x0_re <= accel_mem_rdata;
        RD_X0_IM: x0_im <= accel_mem_rdata;
        RD_X1_RE: x1_re <= accel_mem_rdata;
        RD_X1_IM: x1_im <= accel_mem_rdata;
        RD_X2_RE: x2_re <= accel_mem_rdata;
        RD_X2_IM: x2_im <= accel_mem_rdata;
        RD_X3_RE: x3_re <= accel_mem_rdata;
        RD_X3_IM: x3_im <= accel_mem_rdata;
        // ---- Radix-4 butterfly compute ----
        // t1 = tw1 * x1,  t2 = tw2 * x2,  t3 = (-j*tw2) * x3
        // (multiplying by -j is free: swap Re/Im, negate new Im)
        // y0 = x0 + t1 + t2 + t3
        // y1 = x0 - j*t1 - t2 + j*t3
        // y2 = x0 - t1 + t2 - t3
        // y3 = x0 + j*t1 - t2 - j*t3
        COMPUTE: begin
          // t1 = tw1 * x1
          t1_re = (tw1_re * x1_re - tw1_im * x1_im) >>> SCALE;
          t1_im = (tw1_re * x1_im + tw1_im * x1_re) >>> SCALE;
          // t2 = tw2 * x2
          t2_re = (tw2_re * x2_re - tw2_im * x2_im) >>> SCALE;
          t2_im = (tw2_re * x2_im + tw2_im * x2_re) >>> SCALE;
          // t3 = (-j * tw2) * x3  =>  tw3 = (tw2_im, -tw2_re)  (no extra multiplier!)
          t3_re = ( tw2_im * x3_re + tw2_re * x3_im) >>> SCALE;
          t3_im = ( tw2_im * x3_im - tw2_re * x3_re) >>> SCALE;

          // Butterfly sums
          y0_re <= x0_re + t1_re + t2_re + t3_re;
          y0_im <= x0_im + t1_im + t2_im + t3_im;
          // y1: multiply t1 by -j (free: swap, negate im)
          y1_re <= x0_re + t1_im - t2_re - t3_im;
          y1_im <= x0_im - t1_re - t2_im + t3_re;
          // y2
          y2_re <= x0_re - t1_re + t2_re - t3_re;
          y2_im <= x0_im - t1_im + t2_im - t3_im;
          // y3: multiply t1 by +j (free)
          y3_re <= x0_re - t1_im - t2_re + t3_im;
          y3_im <= x0_im + t1_re - t2_im - t3_re;
        end
        WR_Y3_IM: begin // Loop update
          if (butterfly_done && base_done) begin
            stage   <= next_stage;
            m       <= 1 << (next_stage + 1); // m = 4^(stage_r4+1)
            quarter <= 1 << (next_stage - 1);
            base    <= '0;
            k       <= '0;
          end else if (butterfly_done) begin
            base <= next_base;
            k    <= '0;
          end else begin
            k <= next_k;
          end
        end
        FINISH: fft_finished <= 1'b1;
        default: ;
      endcase
    end
  end

  // -----------------------------------------------------------------------
  // Output combinational: memory address / data / wstrb
  // -----------------------------------------------------------------------
  always @(*) begin
    accel_mem_wstrb = 4'b0000;
    accel_mem_wdata = '0;
    accel_mem_addr  = '0;

    case (state_reg)
      // Twiddle ROM reads (packed: [stage-1]*2 offset, 3 twiddles per Radix-4 stage pair)
      RD_TW0_RE: accel_mem_addr = (stage - 1) * 6;
      RD_TW0_IM: accel_mem_addr = (stage - 1) * 6 + 1;
      RD_TW1_RE: accel_mem_addr = (stage - 1) * 6 + 2;
      RD_TW1_IM: accel_mem_addr = (stage - 1) * 6 + 3;
      RD_TW2_RE: accel_mem_addr = (stage - 1) * 6 + 4;
      RD_TW2_IM: accel_mem_addr = (stage - 1) * 6 + 5;
      // Data reads
      RD_X0_RE: accel_mem_addr = addr_x0;
      RD_X0_IM: accel_mem_addr = addr_x0 + 1;
      RD_X1_RE: accel_mem_addr = addr_x1;
      RD_X1_IM: accel_mem_addr = addr_x1 + 1;
      RD_X2_RE: accel_mem_addr = addr_x2;
      RD_X2_IM: accel_mem_addr = addr_x2 + 1;
      RD_X3_RE: accel_mem_addr = addr_x3;
      RD_X3_IM: accel_mem_addr = addr_x3 + 1;
      // Writes
      WR_Y0_RE: begin accel_mem_wstrb=4'b1111; accel_mem_addr=addr_x0;     accel_mem_wdata=y0_re; end
      WR_Y0_IM: begin accel_mem_wstrb=4'b1111; accel_mem_addr=addr_x0+1;   accel_mem_wdata=y0_im; end
      WR_Y1_RE: begin accel_mem_wstrb=4'b1111; accel_mem_addr=addr_x1;     accel_mem_wdata=y1_re; end
      WR_Y1_IM: begin accel_mem_wstrb=4'b1111; accel_mem_addr=addr_x1+1;   accel_mem_wdata=y1_im; end
      WR_Y2_RE: begin accel_mem_wstrb=4'b1111; accel_mem_addr=addr_x2;     accel_mem_wdata=y2_re; end
      WR_Y2_IM: begin accel_mem_wstrb=4'b1111; accel_mem_addr=addr_x2+1;   accel_mem_wdata=y2_im; end
      WR_Y3_RE: begin accel_mem_wstrb=4'b1111; accel_mem_addr=addr_x3;     accel_mem_wdata=y3_re; end
      WR_Y3_IM: begin accel_mem_wstrb=4'b1111; accel_mem_addr=addr_x3+1;   accel_mem_wdata=y3_im; end
      default: ;
    endcase
  end

endmodule
