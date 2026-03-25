module accelerator_fft #(
    parameter integer LOG_MAX_N   = 32,                // Number of bits to represent the maximum number of input samples
    parameter integer MEM_WIDTH = 32,  // Width of memory data
    parameter integer ADDR_WIDTH = 32,  // Width of memory address
    localparam LOG_MAX_FFT_STAGES = $clog2(LOG_MAX_N)  // Maximum number of stage in the FFT
) (
    input wire clk,
    input wire resetn,

    // Control input
    input wire reset_accel,
    input wire enable_accel,

    // Data input
    input wire [LOG_MAX_N-1:0] number_data,  // number_data is N in the algorithm
    input  wire [LOG_MAX_FFT_STAGES-1:0] fft_stages,          // Number of FFT stages required for the number of data provided

    // Memory inputs/outputs
    output reg  [ 4-1:0] accel_mem_wstrb,
    input  wire [32-1:0] accel_mem_rdata,
    output reg  [32-1:0] accel_mem_wdata,
    output reg  [32-1:0] accel_mem_addr,

    // Data output
    output reg fft_finished
);
  /*----------------------------------------------------------------------------------------
        Define FSM states and inner variables
    ----------------------------------------------------------------------------------------*/
  parameter INIT = 4'd0;
  parameter READ_W_M_RE = 4'd1;
  parameter READ_W_M_IM = 4'd2;
  parameter BUTTERFLY_READ_1_RE = 4'd3;
  parameter BUTTERFLY_READ_1_IM = 4'd4;
  parameter BUTTERFLY_READ_2_RE = 4'd5;
  parameter BUTTERFLY_READ_2_IM = 4'd6;
  parameter BUTTERFLY_COMPUTE = 4'd7;
  parameter BUTTERFLY_WRITE_1_RE = 4'd8;
  parameter BUTTERFLY_WRITE_1_IM = 4'd9;
  parameter BUTTERFLY_WRITE_2_RE = 4'd10;
  parameter BUTTERFLY_WRITE_2_IM = 4'd11;
  parameter FINISH = 4'd12;

  // Define state registers and next_state wires
  reg [3:0] state_reg;
  reg [3:0] next_state;  // THIS IS A WIRE. REG BECAUSE USED INSIDE AN ALWAYS BLOCK.

  // Define FFT variables
  // Registers
  reg [LOG_MAX_N-1:0] m;  // Support for a sequence of N=2**(LOG_MAX_N) input samples
  reg [LOG_MAX_FFT_STAGES-1:0] stage;  // Maximum number of stage in the FFT
  reg [LOG_MAX_N-1:0] base;  // Max is N = 2**(LOG_MAX_N)
  reg [LOG_MAX_N-2:0] k;  // Max is N/2 = 2**(LOG_MAX_N-1)
  reg [LOG_MAX_N-2:0] half;  // Max is N/2 = 2**(LOG_MAX_N-1)
  reg signed [MEM_WIDTH-1:0] w_re;  // Real part of twiddle factor
  reg signed [MEM_WIDTH-1:0] w_im;  // Imaginary part of twiddle factor
  reg signed [MEM_WIDTH-1:0] w_m_re;  // Real part of the partial twiddle factor
  reg signed [MEM_WIDTH-1:0] w_m_im;  // Imaginary part of the partial twiddle factor
  reg signed [MEM_WIDTH-1:0] u_re;  // Real part of u = X[base + k]
  reg signed [MEM_WIDTH-1:0] u_im;  // Imaginary part of u = X[base + k]
  reg signed [MEM_WIDTH-1:0] v_re;  // Real part of v = X[base + k + half]
  reg signed [MEM_WIDTH-1:0] v_im;  // Imaginary part of v = X[base + k + half]
  reg signed [MEM_WIDTH-1:0] e_re;  // Real part of e = u + t
  reg signed [MEM_WIDTH-1:0] e_im;  // Imaginary part of e = u + t
  reg signed [MEM_WIDTH-1:0] o_re;  // Real part of o = u - t
  reg signed [MEM_WIDTH-1:0] o_im;  // Imaginary part of o = u - t

  // Wires
  wire [LOG_MAX_FFT_STAGES-1:0] next_stage;
  wire [LOG_MAX_N-1:0] next_base;
  wire [LOG_MAX_N-2:0] next_k;
  wire [ADDR_WIDTH-1:0] start_input_address;
  wire [ADDR_WIDTH-1:0] mem_addr_base_k;
  wire [ADDR_WIDTH-1:0] mem_addr_base_k_plus_half;
  reg signed [MEM_WIDTH-1:0] t_re;  // Real part of t = w * X[base + k + half]
  reg signed [MEM_WIDTH-1:0] t_im;  // Imaginary part of t = w * X[base + k + half]
  reg signed [MEM_WIDTH-1:0] w_re_comb;  // Combined real part of w * w_m
  reg signed [MEM_WIDTH-1:0] w_im_comb;  // Combined imaginary part of w * w_m

  // Constants
  localparam SCALE = 12;  // Number of bits to right shift the multiplication results

  /*----------------------------------------------------------------------------------------
        Iterative (in-place) Cooley-Tukey FFT algorithm - MOORE FSM
    ----------------------------------------------------------------------------------------*/

  // Sequential logic for state transition 
  always @(posedge clk) begin
    if (reset_accel) state_reg <= INIT;
    else state_reg <= next_state;
  end

  // Combinational logic for next state computation
  assign butterfly_loop_finished = next_k == half;
  assign base_loop_finished = next_base == number_data;  // Only if N is a power of 2 number
  assign stage_loop_finished = stage == fft_stages;
  assign next_k = k + 1;
  assign next_base = base + m;
  assign next_stage = stage + 1;

  always @(*) begin
    case (state_reg)
      INIT:
      if (enable_accel)
        if (number_data[LOG_MAX_N-1:1] == 0)
          next_state = FINISH;  // If number_data < 2, finish FFT as the input does not change
        else next_state = READ_W_M_RE;
      else next_state = INIT;
      READ_W_M_RE: next_state = READ_W_M_IM;  // Initiate a memory read for the real part of W_M
      READ_W_M_IM:
      next_state = BUTTERFLY_READ_1_RE;  // Initiate a memory read for the imaginary part of W_M
      BUTTERFLY_READ_1_RE:
      next_state = BUTTERFLY_READ_1_IM;  // Initiate a memory read for the real part X[base+k]
      BUTTERFLY_READ_1_IM:
      next_state = BUTTERFLY_READ_2_RE;  // Initiate a memory read for the imaginary part X[base+k]
      BUTTERFLY_READ_2_RE:
      next_state = BUTTERFLY_READ_2_IM;  // Initiate a memory read for the real part X[base+k+half]
      BUTTERFLY_READ_2_IM:
      next_state = BUTTERFLY_COMPUTE;      // Initiate a memory read for the imaginary part X[base+k+half]
      BUTTERFLY_COMPUTE: next_state = BUTTERFLY_WRITE_1_RE;  // Compute the butterfly
      BUTTERFLY_WRITE_1_RE:
      next_state = BUTTERFLY_WRITE_1_IM;  // Initiate a memory write for the real part of X[base+k]
      BUTTERFLY_WRITE_1_IM:
      next_state = BUTTERFLY_WRITE_2_RE;  // Initiate a memory write for the imaginary part of X[base+k]
      BUTTERFLY_WRITE_2_RE:
      next_state = BUTTERFLY_WRITE_2_IM;  // Initiate a memory write for the real part of X[base+k+half]
      BUTTERFLY_WRITE_2_IM:                                     // Initiate a memory write for the imaginary part of X[base+k+half] and update for loops variables
      if (butterfly_loop_finished && base_loop_finished && stage_loop_finished) next_state = FINISH;
      else if (butterfly_loop_finished && base_loop_finished) next_state = READ_W_M_RE;
      else next_state = BUTTERFLY_READ_1_RE;
      FINISH:
      if (!enable_accel)  // Disable the accelerator to start a new FFT
        next_state = INIT;
      else next_state = FINISH;  // End of FFT process
      default: next_state = INIT;
    endcase
  end

  // Sequential logic based on the current state
  always @(posedge clk) begin
    if (reset_accel) begin  // Reset registers
      // Stage loop -- pre-initialization of loop variables corresponding to the first iteration of the loop
      stage <= 'b1;
      m <= 'd2;
      half <= 'b1;
      // Base loop -- pre-initialization of loop variables corresponding to the first iteration of the loop
      base <= '0;
      w_re <= 'b1 << SCALE;
      w_im <= '0;
      // Butterfly loop -- pre-initialization of loop variables corresponding to the first iteration of the loop
      k <= '0;
      // Reset input/output FSM registers
      w_m_re <= '0;
      w_m_im <= '0;
      u_re <= '0;
      u_im <= '0;
      v_re <= '0;
      v_im <= '0;
      e_re <= '0;
      e_im <= '0;
      o_re <= '0;
      o_im <= '0;
      // FSM accelerator flag
      fft_finished <= '0;
    end else begin
      case (state_reg)
        INIT: begin  // Reset registers
          // Stage loop
          stage <= 'b1;
          m <= 'd2;
          half <= 'b1;
          // Base loop
          base <= '0;
          w_re <= 'b1 << SCALE;
          w_im <= '0;
          // Butterfly loop
          k <= '0;
          // Reset input/output FSM registers
          w_m_re <= '0;
          w_m_im <= '0;
          u_re <= '0;
          u_im <= '0;
          v_re <= '0;
          v_im <= '0;
          e_re <= '0;
          e_im <= '0;
          o_re <= '0;
          o_im <= '0;
          // FSM accelerator flag
          fft_finished <= '0;
        end
        READ_W_M_RE: begin
          w_m_re <= accel_mem_rdata;
        end
        READ_W_M_IM: begin
          w_m_im <= accel_mem_rdata;
        end
        BUTTERFLY_READ_1_RE: begin
          u_re <= accel_mem_rdata;
        end
        BUTTERFLY_READ_1_IM: begin
          u_im <= accel_mem_rdata;
        end
        BUTTERFLY_READ_2_RE: begin
          v_re <= accel_mem_rdata;
        end
        BUTTERFLY_READ_2_IM: begin
          v_im <= accel_mem_rdata;  // v_im = Im(X[base + k + half])
        end
        BUTTERFLY_COMPUTE: begin
          e_re <= u_re + t_re;
          e_im <= u_im + t_im;
          o_re <= u_re - t_re;
          o_im <= u_im - t_im;
          w_re <= w_re_comb;
          w_im <= w_im_comb;
        end
        BUTTERFLY_WRITE_1_RE: ;  // Do nothing
        BUTTERFLY_WRITE_1_IM: ;  // Do nothing
        BUTTERFLY_WRITE_2_RE: ;  // Do nothing
        BUTTERFLY_WRITE_2_IM: begin
          if (butterfly_loop_finished && base_loop_finished) begin
            // Increment state loop
            stage <= next_stage;
            m <= 1 << next_stage;
            half <= 1 << stage;
            // Reset base loop
            w_re <= 'b1 << SCALE;
            w_im <= '0;
            base <= '0;
            // Reset butterfly loop
            k <= '0;
          end else if (butterfly_loop_finished) begin
            // Do nothing for state loop
            // Increment base loop
            w_re <= 'b1 << SCALE;
            w_im <= '0;
            base <= next_base;
            // Reset butterfly loop
            k <= '0;
          end else begin
            // Do nothing for state loop
            // Do nothing for base loop
            // Increment butterfly loop
            k <= next_k;
          end
        end
        FINISH: begin
          fft_finished <= 1'b1;  // End of fft process
        end
        default: ;  // Do nothing
      endcase
    end
  end

  // Combinational logic for current state output computation
  assign start_input_address = fft_stages << 1;  // Each complex number uses 2 memory locations
  assign mem_addr_base_k = (base + k) << 1;
  assign mem_addr_base_k_plus_half = (base + k + half) << 1;

  always @(*) begin
    // Important: If the 'case' block does not contain all possibilities for a 
    // combinational logic, set default values to avoid introducing latches.
    accel_mem_wstrb = 4'b0000;
    accel_mem_wdata = '0;
    accel_mem_addr = '0;
    t_re = '0;
    t_im = '0;
    w_re_comb = '0;
    w_im_comb = '0;

    case (state_reg)
      INIT: ;  // Nothing to do for this state
      READ_W_M_RE: begin
        accel_mem_addr = (stage - 1) << 1;  // Each complex number uses 2 memory locations
      end
      READ_W_M_IM: begin
        accel_mem_addr = ((stage - 1) << 1) + 1;
      end
      BUTTERFLY_READ_1_RE: begin
        accel_mem_addr = start_input_address + mem_addr_base_k;
      end
      BUTTERFLY_READ_1_IM: begin
        accel_mem_addr = start_input_address + mem_addr_base_k + 1;
      end
      BUTTERFLY_READ_2_RE: begin
        accel_mem_addr = start_input_address + mem_addr_base_k_plus_half;
      end
      BUTTERFLY_READ_2_IM: begin
        accel_mem_addr = start_input_address + mem_addr_base_k_plus_half + 1;
      end
      BUTTERFLY_COMPUTE: begin
        t_re = (v_re * w_re - v_im * w_im) >>> SCALE;  // t_re = Re(w * X[base + k + half]) 
        t_im = (v_re * w_im + v_im * w_re) >>> SCALE;  // t_im = Im(w * X[base + k + half])
        w_re_comb = (w_re * w_m_re - w_im * w_m_im) >>> SCALE;  // w_re_comb = Re(w * w_m)
        w_im_comb = (w_re * w_m_im + w_im * w_m_re) >>> SCALE;  // w_im_comb = Im(w * w_m)
      end
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
      FINISH: ;  // Nothing to do here
      default: ;  // Do nothing as already defined at the top of the always block
    endcase
  end
endmodule
