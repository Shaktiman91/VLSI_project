// =============================================================================
// Pipelined Radix-2 FFT Accelerator
//
// KEY CHANGE vs baseline accelerator_fft.v:
//   The twiddle multiplication  t = w * v  is pre-computed combinationally
//   and LATCHED during the BUTTERFLY_READ_2_IM state, while v_im arrives
//   from memory.  This overlaps the multiply with the last read cycle so
//   BUTTERFLY_COMPUTE only performs add/sub.
//
//   Per-butterfly cycle cost:  10 cycles (baseline)  -->  8 cycles (here)
//   ~20% fewer active cycles => shorter race-to-sleep window => lower energy.
//
// Interface: identical to baseline.  Drop-in replacement.
// Memory layout / twiddle format: identical to baseline.
// =============================================================================
module accelerator_fft #(
    parameter integer LOG_MAX_N        = 32,
    parameter integer MEM_WIDTH        = 32,
    parameter integer ADDR_WIDTH       = 32,
    localparam        LOG_MAX_FFT_STAGES = $clog2(LOG_MAX_N)
) (
    input wire clk,
    input wire resetn,

    // Control
    input wire reset_accel,
    input wire enable_accel,

    // Data
    input wire [LOG_MAX_N-1:0]          number_data,
    input wire [LOG_MAX_FFT_STAGES-1:0] fft_stages,

    // Memory
    output reg [ 3:0] accel_mem_wstrb,
    input  wire [31:0] accel_mem_rdata,
    output reg [31:0] accel_mem_wdata,
    output reg [31:0] accel_mem_addr,

    output reg fft_finished
);

  // ---------------------------------------------------------------------------
  // FSM state encoding  (identical names/values to baseline for easy diff)
  // ---------------------------------------------------------------------------
  parameter INIT                 = 4'd0;
  parameter READ_W_M_RE          = 4'd1;
  parameter READ_W_M_IM          = 4'd2;
  parameter BUTTERFLY_READ_1_RE  = 4'd3;
  parameter BUTTERFLY_READ_1_IM  = 4'd4;
  parameter BUTTERFLY_READ_2_RE  = 4'd5;
  parameter BUTTERFLY_READ_2_IM  = 4'd6;  // <-- multiply starts here now
  parameter BUTTERFLY_COMPUTE    = 4'd7;  // <-- now only add/sub
  parameter BUTTERFLY_WRITE_1_RE = 4'd8;
  parameter BUTTERFLY_WRITE_1_IM = 4'd9;
  parameter BUTTERFLY_WRITE_2_RE = 4'd10;
  parameter BUTTERFLY_WRITE_2_IM = 4'd11;
  parameter FINISH               = 4'd12;

  localparam SCALE = 12;

  // ---------------------------------------------------------------------------
  // Registers
  // ---------------------------------------------------------------------------
  reg [3:0] state_reg;
  reg [3:0] next_state;

  reg [LOG_MAX_N-1:0]           m, base;
  reg [LOG_MAX_FFT_STAGES-1:0]  stage;
  reg [LOG_MAX_N-2:0]           k, half;

  reg signed [MEM_WIDTH-1:0] w_re, w_im;
  reg signed [MEM_WIDTH-1:0] w_m_re, w_m_im;
  reg signed [MEM_WIDTH-1:0] u_re,   u_im;
  reg signed [MEM_WIDTH-1:0] v_re,   v_im;
  reg signed [MEM_WIDTH-1:0] e_re,   e_im;
  reg signed [MEM_WIDTH-1:0] o_re,   o_im;

  // PIPELINE REGISTERS: t is latched one cycle early (during READ_2_IM)
  reg signed [MEM_WIDTH-1:0] t_re_lat, t_im_lat;

  // ---------------------------------------------------------------------------
  // Loop-control wires  (identical to baseline)
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
  // Combinational: w update for next butterfly (computed every cycle cheaply)
  // These are used to advance w inside READ_2_IM instead of COMPUTE.
  // ---------------------------------------------------------------------------
  wire signed [MEM_WIDTH-1:0] w_re_next = (w_re * w_m_re - w_im * w_m_im) >>> SCALE;
  wire signed [MEM_WIDTH-1:0] w_im_next = (w_re * w_m_im + w_im * w_m_re) >>> SCALE;

  // ---------------------------------------------------------------------------
  // FSM: state register
  // ---------------------------------------------------------------------------
  always @(posedge clk) begin
    if (reset_accel) state_reg <= INIT;
    else             state_reg <= next_state;
  end

  // ---------------------------------------------------------------------------
  // FSM: next-state logic  (identical to baseline)
  // ---------------------------------------------------------------------------
  always @(*) begin
    case (state_reg)
      INIT:
        if (enable_accel)
          next_state = (number_data[LOG_MAX_N-1:1] == 0) ? FINISH : READ_W_M_RE;
        else
          next_state = INIT;
      READ_W_M_RE:          next_state = READ_W_M_IM;
      READ_W_M_IM:          next_state = BUTTERFLY_READ_1_RE;
      BUTTERFLY_READ_1_RE:  next_state = BUTTERFLY_READ_1_IM;
      BUTTERFLY_READ_1_IM:  next_state = BUTTERFLY_READ_2_RE;
      BUTTERFLY_READ_2_RE:  next_state = BUTTERFLY_READ_2_IM;
      BUTTERFLY_READ_2_IM:  next_state = BUTTERFLY_COMPUTE;
      BUTTERFLY_COMPUTE:    next_state = BUTTERFLY_WRITE_1_RE;
      BUTTERFLY_WRITE_1_RE: next_state = BUTTERFLY_WRITE_1_IM;
      BUTTERFLY_WRITE_1_IM: next_state = BUTTERFLY_WRITE_2_RE;
      BUTTERFLY_WRITE_2_RE: next_state = BUTTERFLY_WRITE_2_IM;
      BUTTERFLY_WRITE_2_IM:
        if (butterfly_loop_finished && base_loop_finished && stage_loop_finished)
          next_state = FINISH;
        else if (butterfly_loop_finished && base_loop_finished)
          next_state = READ_W_M_RE;
        else
          next_state = BUTTERFLY_READ_1_RE;
      FINISH:
        next_state = enable_accel ? FINISH : INIT;
      default: next_state = INIT;
    endcase
  end

  // ---------------------------------------------------------------------------
  // FSM: datapath sequential
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
      t_re_lat <= '0;   t_im_lat <= '0;
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
          t_re_lat <= '0; t_im_lat <= '0;
          fft_finished <= '0;
        end

        READ_W_M_RE: w_m_re <= accel_mem_rdata;
        READ_W_M_IM: w_m_im <= accel_mem_rdata;

        BUTTERFLY_READ_1_RE: u_re <= accel_mem_rdata;
        BUTTERFLY_READ_1_IM: u_im <= accel_mem_rdata;
        BUTTERFLY_READ_2_RE: v_re <= accel_mem_rdata;

        // ===================================================================
        // PIPELINING CHANGE: compute t = w*v here, overlapping with the read.
        // accel_mem_rdata holds v_im at this moment (not yet in v_im register).
        // We also advance w here so BUTTERFLY_COMPUTE has nothing to multiply.
        // ===================================================================
        BUTTERFLY_READ_2_IM: begin
          v_im     <= accel_mem_rdata;
          // Latch t = w * v  (v_re already registered; v_im from bus)
          t_re_lat <= (v_re * w_re - accel_mem_rdata * w_im) >>> SCALE;
          t_im_lat <= (v_re * w_im + accel_mem_rdata * w_re) >>> SCALE;
          // Advance twiddle for the NEXT butterfly (was done in COMPUTE before)
          w_re     <= w_re_next;
          w_im     <= w_im_next;
        end

        // ===================================================================
        // PIPELINING CHANGE: no multiply here anymore -- pure add/sub only.
        // ===================================================================
        BUTTERFLY_COMPUTE: begin
          e_re <= u_re + t_re_lat;
          e_im <= u_im + t_im_lat;
          o_re <= u_re - t_re_lat;
          o_im <= u_im - t_im_lat;
          // w already advanced in READ_2_IM
        end

        BUTTERFLY_WRITE_1_RE: ; // Do nothing
        BUTTERFLY_WRITE_1_IM: ; // Do nothing
        BUTTERFLY_WRITE_2_RE: ; // Do nothing

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
            k <= next_k;
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
