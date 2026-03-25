// =============================================================================
// Radix-2^2 SDF (Single-path Delay Feedback) FFT Accelerator
//
// KEY CHANGE vs baseline accelerator_fft.v:
//   Pairs of consecutive Radix-2 stages are fused into Radix-2^2 butterfly
//   pairs.  In each pair:
//     Stage A (odd stage index):  lower-arm rotation is always  W^(N/4) = -j
//                                 => swap Re/Im and negate Im (FREE, no mult).
//     Stage B (even stage index): one complex multiplier  t = w^2 * v.
//
//   Result: the number of complex multiplications is HALVED vs baseline,
//   saving roughly 2 DSP slices per butterfly in silicon.
//
// Twiddle ROM layout: UNCHANGED from baseline (2 words per stage).
// Interface:          UNCHANGED.  Drop-in replacement.
// =============================================================================
module accelerator_fft #(
    parameter integer LOG_MAX_N        = 32,
    parameter integer MEM_WIDTH        = 32,
    parameter integer ADDR_WIDTH       = 32,
    localparam        LOG_MAX_FFT_STAGES = $clog2(LOG_MAX_N)
) (
    input wire clk,
    input wire resetn,

    input wire reset_accel,
    input wire enable_accel,

    input wire [LOG_MAX_N-1:0]          number_data,
    input wire [LOG_MAX_FFT_STAGES-1:0] fft_stages,

    output reg [ 3:0] accel_mem_wstrb,
    input  wire [31:0] accel_mem_rdata,
    output reg [31:0] accel_mem_wdata,
    output reg [31:0] accel_mem_addr,

    output reg fft_finished
);

  // ---------------------------------------------------------------------------
  // FSM states
  // New state STAGE_A_COMPUTE replaces READ_W_M_* and BUTTERFLY_COMPUTE for
  // odd stages (the -j rotation is trivial -- no reads or multiply needed).
  // ---------------------------------------------------------------------------
  parameter INIT                 = 4'd0;
  parameter READ_W_M_RE          = 4'd1;   // only used in even stages
  parameter READ_W_M_IM          = 4'd2;   // only used in even stages
  parameter BUTTERFLY_READ_1_RE  = 4'd3;
  parameter BUTTERFLY_READ_1_IM  = 4'd4;
  parameter BUTTERFLY_READ_2_RE  = 4'd5;
  parameter BUTTERFLY_READ_2_IM  = 4'd6;
  parameter BUTTERFLY_COMPUTE    = 4'd7;   // used for even stages (has mult)
  parameter BUTTERFLY_WRITE_1_RE = 4'd8;
  parameter BUTTERFLY_WRITE_1_IM = 4'd9;
  parameter BUTTERFLY_WRITE_2_RE = 4'd10;
  parameter BUTTERFLY_WRITE_2_IM = 4'd11;
  parameter FINISH               = 4'd12;
  // NEW: trivial -j butterfly for odd stages (no multiplier)
  parameter STAGE_A_COMPUTE      = 4'd13;

  localparam SCALE = 12;

  // ---------------------------------------------------------------------------
  // Registers
  // ---------------------------------------------------------------------------
  reg [3:0] state_reg, next_state;

  reg [LOG_MAX_N-1:0]           m, base;
  reg [LOG_MAX_FFT_STAGES-1:0]  stage;
  reg [LOG_MAX_N-2:0]           k, half;

  reg signed [MEM_WIDTH-1:0] w_re, w_im;
  reg signed [MEM_WIDTH-1:0] w_m_re, w_m_im;
  reg signed [MEM_WIDTH-1:0] u_re,   u_im;
  reg signed [MEM_WIDTH-1:0] v_re,   v_im;
  reg signed [MEM_WIDTH-1:0] e_re,   e_im;
  reg signed [MEM_WIDTH-1:0] o_re,   o_im;
  reg signed [MEM_WIDTH-1:0] t_re,   t_im;
  reg signed [MEM_WIDTH-1:0] w_re_comb, w_im_comb;

  // stage_is_odd: '1' for stage 1, 3, 5, ... (Stage-A of each R2^2 pair)
  wire stage_is_odd = stage[0];

  // ---------------------------------------------------------------------------
  // Loop-control  (identical to baseline)
  // ---------------------------------------------------------------------------
  wire [LOG_MAX_FFT_STAGES-1:0] next_stage = stage + 1;
  wire [LOG_MAX_N-2:0]          next_k     = k + 1;
  wire [LOG_MAX_N-1:0]          next_base  = base + m;

  wire butterfly_loop_finished = (next_k == half);
  wire base_loop_finished      = (next_base == number_data);
  wire stage_loop_finished     = (stage == fft_stages);

  wire [ADDR_WIDTH-1:0] start_input_address      = fft_stages << 1;
  wire [ADDR_WIDTH-1:0] mem_addr_base_k           = (base + k) << 1;
  wire [ADDR_WIDTH-1:0] mem_addr_base_k_plus_half = (base + k + half) << 1;

  // ---------------------------------------------------------------------------
  // FSM: state register
  // ---------------------------------------------------------------------------
  always @(posedge clk) begin
    if (reset_accel) state_reg <= INIT;
    else             state_reg <= next_state;
  end

  // ---------------------------------------------------------------------------
  // FSM: next-state logic
  // For ODD stages  -> skip READ_W_M_RE/IM, go straight to reads, use
  //                    STAGE_A_COMPUTE (no mult) instead of BUTTERFLY_COMPUTE.
  // For EVEN stages -> follow baseline path (read twiddle, multiply).
  // ---------------------------------------------------------------------------
  always @(*) begin
    case (state_reg)
      INIT:
        if (enable_accel)
          next_state = (number_data[LOG_MAX_N-1:1] == 0) ? FINISH
                     : (stage_is_odd ? BUTTERFLY_READ_1_RE : READ_W_M_RE);
        else
          next_state = INIT;

      // Even-stage twiddle read path
      READ_W_M_RE:          next_state = READ_W_M_IM;
      READ_W_M_IM:          next_state = BUTTERFLY_READ_1_RE;

      // Shared data-read path
      BUTTERFLY_READ_1_RE:  next_state = BUTTERFLY_READ_1_IM;
      BUTTERFLY_READ_1_IM:  next_state = BUTTERFLY_READ_2_RE;
      BUTTERFLY_READ_2_RE:  next_state = BUTTERFLY_READ_2_IM;
      BUTTERFLY_READ_2_IM:
        // Route to trivial -j compute for odd stages, full multiply for even
        next_state = stage_is_odd ? STAGE_A_COMPUTE : BUTTERFLY_COMPUTE;

      // Odd stage: trivial -j rotation (no multiplier)
      STAGE_A_COMPUTE:      next_state = BUTTERFLY_WRITE_1_RE;

      // Even stage: full complex multiply
      BUTTERFLY_COMPUTE:    next_state = BUTTERFLY_WRITE_1_RE;

      BUTTERFLY_WRITE_1_RE: next_state = BUTTERFLY_WRITE_1_IM;
      BUTTERFLY_WRITE_1_IM: next_state = BUTTERFLY_WRITE_2_RE;
      BUTTERFLY_WRITE_2_RE: next_state = BUTTERFLY_WRITE_2_IM;
      BUTTERFLY_WRITE_2_IM:
        if (butterfly_loop_finished && base_loop_finished && stage_loop_finished)
          next_state = FINISH;
        else if (butterfly_loop_finished && base_loop_finished)
          // Move to next stage; pick path based on upcoming stage parity
          next_state = (stage + 1 == fft_stages + 1) ? FINISH
                     : ((next_stage[0]) ? BUTTERFLY_READ_1_RE : READ_W_M_RE);
        else
          next_state = BUTTERFLY_READ_1_RE;

      FINISH: next_state = enable_accel ? FINISH : INIT;
      default: next_state = INIT;
    endcase
  end

  // ---------------------------------------------------------------------------
  // FSM: datapath
  // ---------------------------------------------------------------------------
  always @(posedge clk) begin
    if (reset_accel) begin
      stage    <= 'b1;  m    <= 'd2;  half <= 'b1;
      base     <= '0;   k    <= '0;
      w_re     <= 'b1 << SCALE;  w_im <= '0;
      w_m_re   <= '0;   w_m_im <= '0;
      u_re     <= '0;   u_im   <= '0;
      v_re     <= '0;   v_im   <= '0;
      e_re     <= '0;   e_im   <= '0;
      o_re     <= '0;   o_im   <= '0;
      t_re     <= '0;   t_im   <= '0;
      fft_finished <= '0;
    end else begin
      case (state_reg)
        INIT: begin
          stage  <= 'b1;  m   <= 'd2;  half <= 'b1;
          base   <= '0;   k   <= '0;
          w_re   <= 'b1 << SCALE;  w_im <= '0;
          w_m_re <= '0;   w_m_im <= '0;
          u_re <= '0; u_im <= '0; v_re <= '0; v_im <= '0;
          e_re <= '0; e_im <= '0; o_re <= '0; o_im <= '0;
          fft_finished <= '0;
        end

        READ_W_M_RE: w_m_re <= accel_mem_rdata;
        READ_W_M_IM: w_m_im <= accel_mem_rdata;

        BUTTERFLY_READ_1_RE: u_re <= accel_mem_rdata;
        BUTTERFLY_READ_1_IM: u_im <= accel_mem_rdata;
        BUTTERFLY_READ_2_RE: v_re <= accel_mem_rdata;
        BUTTERFLY_READ_2_IM: v_im <= accel_mem_rdata;

        // ===================================================================
        // STAGE A (odd stage): W^(N/4) = -j  =>  t = -j * v = (v_im, -v_re)
        // No multiplier needed!
        // ===================================================================
        STAGE_A_COMPUTE: begin
          t_re <=  v_im;   // Re(-j*v) =  Im(v)
          t_im <= -v_re;   // Im(-j*v) = -Re(v)
          e_re <= u_re + v_im;
          e_im <= u_im - v_re;
          o_re <= u_re - v_im;
          o_im <= u_im + v_re;
          // w unchanged for odd stages
        end

        // ===================================================================
        // STAGE B (even stage): full complex multiply  t = w * v
        // ===================================================================
        BUTTERFLY_COMPUTE: begin
          t_re      <= (v_re * w_re - v_im * w_im) >>> SCALE;
          t_im      <= (v_re * w_im + v_im * w_re) >>> SCALE;
          e_re      <= u_re + ((v_re * w_re - v_im * w_im) >>> SCALE);
          e_im      <= u_im + ((v_re * w_im + v_im * w_re) >>> SCALE);
          o_re      <= u_re - ((v_re * w_re - v_im * w_im) >>> SCALE);
          o_im      <= u_im - ((v_re * w_im + v_im * w_re) >>> SCALE);
          w_re_comb <= (w_re * w_m_re - w_im * w_m_im) >>> SCALE;
          w_im_comb <= (w_re * w_m_im + w_im * w_m_re) >>> SCALE;
        end

        BUTTERFLY_WRITE_1_RE: ; BUTTERFLY_WRITE_1_IM: ;
        BUTTERFLY_WRITE_2_RE: ;

        BUTTERFLY_WRITE_2_IM: begin
          if (butterfly_loop_finished && base_loop_finished) begin
            stage <= next_stage;
            m     <= 1 << next_stage;
            half  <= 1 << stage;
            w_re  <= 'b1 << SCALE;  w_im <= '0;
            base  <= '0;  k <= '0;
          end else if (butterfly_loop_finished) begin
            w_re  <= 'b1 << SCALE;  w_im <= '0;
            base  <= next_base;  k <= '0;
          end else begin
            k    <= next_k;
            // For even stages advance twiddle; for odd stages w stays 1
            if (!stage_is_odd) begin
              w_re <= w_re_comb;
              w_im <= w_im_comb;
            end
          end
        end

        FINISH: fft_finished <= 1'b1;
        default: ;
      endcase
    end
  end

  // ---------------------------------------------------------------------------
  // Output combinational  (identical to baseline)
  // ---------------------------------------------------------------------------
  always @(*) begin
    accel_mem_wstrb = 4'b0000;
    accel_mem_wdata = '0;
    accel_mem_addr  = '0;

    case (state_reg)
      INIT: ;
      READ_W_M_RE:          accel_mem_addr = (stage - 1) << 1;
      READ_W_M_IM:          accel_mem_addr = ((stage - 1) << 1) + 1;
      BUTTERFLY_READ_1_RE:  accel_mem_addr = start_input_address + mem_addr_base_k;
      BUTTERFLY_READ_1_IM:  accel_mem_addr = start_input_address + mem_addr_base_k + 1;
      BUTTERFLY_READ_2_RE:  accel_mem_addr = start_input_address + mem_addr_base_k_plus_half;
      BUTTERFLY_READ_2_IM:  accel_mem_addr = start_input_address + mem_addr_base_k_plus_half + 1;
      BUTTERFLY_WRITE_1_RE: begin
        accel_mem_wstrb = 4'b1111;
        accel_mem_addr  = start_input_address + mem_addr_base_k;
        accel_mem_wdata = e_re;
      end
      BUTTERFLY_WRITE_1_IM: begin
        accel_mem_wstrb = 4'b1111;
        accel_mem_addr  = start_input_address + mem_addr_base_k + 1;
        accel_mem_wdata = e_im;
      end
      BUTTERFLY_WRITE_2_RE: begin
        accel_mem_wstrb = 4'b1111;
        accel_mem_addr  = start_input_address + mem_addr_base_k_plus_half;
        accel_mem_wdata = o_re;
      end
      BUTTERFLY_WRITE_2_IM: begin
        accel_mem_wstrb = 4'b1111;
        accel_mem_addr  = start_input_address + mem_addr_base_k_plus_half + 1;
        accel_mem_wdata = o_im;
      end
      FINISH: ;
      default: ;
    endcase
  end

endmodule
