
/*##########################################################################
###
### Dummy accelerator module
###    
###     This is an accelerator module that implement the iterative (in-place) Cooley-Tukey FFT algorithm using a Moore FSM.
###
###     TU Delft ET4351
###     April 2023, C.Gao, C. Frenkel: 
###                - Baseline project for count from zero to the value of the input data.
###                - It is used to demonstrate the use of the accelerator interface.
###     April 2024, N.Chauvaux: 
###                - Sorting accelerator + memory interface
###     December 2024, Ang Li, Yizhuo Wu: 
###                - Pathfinding accelerator
###     January 2026, N.Chauvaux and Douwe den Blanken:
###                - FFT accelerator
###
##########################################################################*/

/* Accelerator Memory Map
    // CONFIGURATION FILE
	iomem_accel[0] | 0x0300_0000: 32-bit Config & Status Register (CSR)
        --Bit [31:3] <xxxxxx>  : Undefined. You can use these bits for your own purposes.
        --Bit 2      <Status>  : Done Flag (FFT finished)           | 0 = Not finished, 1 = Finished
        --Bit 1      <Config>  : Enable Accelerator (Active High)   | 0 = Disable, 1 = Enable
        --Bit 0      <Config>  : Reset Accelerator  (Active High)   | 0 = Assert,  1 = Release
    iomem_accel[1] | 0x300_0004: 32-bit Number data
    iomem_accel[2] | 0x300_0008: 32-bit General Purpose Input/Output (GPIO)
    iomem_accel[3] | 0x300_000C: 32-bit General Purpose Input/Output (GPIO)

    // MEMORY FILE
    MEM[0] | 0x0300_0010: 32-bit word
    MEM[1] | 0x0300_0014: 32-bit word
    ...
    ...
    ...
    ...
    MEM[31] | 0x0300_08C: 32-bit word
*/

module accelerator (
    input  wire        clk,
    input  wire        resetn,
    input  wire        iomem_valid,
    output wire        iomem_ready,
    input  wire [ 3:0] iomem_wstrb,
    input  wire [31:0] iomem_addr,
    input  wire [31:0] iomem_wdata,
    output wire [31:0] iomem_rdata
);
  /*----------------------------------------------------------------------------------------
        SIGNALS DECLARATION
    ----------------------------------------------------------------------------------------*/
  /*
     * Declare Local Parameters
     */
  // Accelerator configuration registers
  localparam NUM_REGS = 4;  // Number of registers in the accelerator
  localparam NUM_REGS_WIDTH = $clog2(NUM_REGS);  // Number of bits required to address the registers
  // Accelerator internal memory
  localparam MEM_DEPTH = 128;
  localparam ADDR_WIDTH = $clog2(MEM_DEPTH);  // Number of bits required to address the MEMORY
  // Application specifications
  localparam LOG_MAX_N = 32;  // Maximum number of input samples is 2^32
  localparam LOG_MAX_FFT_STAGES = $clog2(LOG_MAX_N);  // Maximum number of stage in the FFT
  integer i;

  /*
     * Declare internal signals
     */
  // Define accelerator execution control signals
  wire reset_accel;
  wire enable_accel;
  wire finished_accel;

  // Define FFT variables
  wire [LOG_MAX_N-1:0] number_data;
  wire [LOG_MAX_FFT_STAGES-1:0] fft_stages;

  /// Define signals for the accelerator MEMORY
  wire [ADDR_WIDTH-1:0] mem_addr;
  wire [31:0] mem_rdata;
  wire [31:0] mem_wdata;
  wire [3:0] mem_wstrb;

  // Define access signal on the accelerator MEMORY coming from the accelerator itself.
  wire [3:0] accel_mem_wstrb;
  wire [31:0] accel_mem_wdata;
  wire [31:0] accel_mem_addr;

  // Define MEMORY/CONF access signal coming from the IOMEM(e.g. PICORV32)
  wire iomem_access_accelerator;  // Whether the PICO tries to access the accelerator
  wire iomem_access_conf;  // Whether the PICO tries to access the configuration registers
  wire iomem_access_mem;  // Whether the PICO tries to access the accelerator memory
  reg iomem_conf_ready;
  reg iomem_mem_ready;
  reg [31:0] iomem_conf_rdata;

  // Define the configuration register array
  reg [31:0] iomem_accel[NUM_REGS-1:0];  // Accelerator Registers
  wire [NUM_REGS_WIDTH-1:0] iomem_accel_addr;  // Accelerator Register Address

  /*----------------------------------------------------------------------------------------
        MEMORY AND ACCELERATOR
    ----------------------------------------------------------------------------------------*/
  // Instantiate the MEMORY of the accelerator
  accelerator_mem #(
      .MEM_DEPTH(MEM_DEPTH)
  ) mem (
      .clk  (clk),
      .wen  (mem_wstrb),
      .addr (mem_addr),
      .wdata(mem_wdata),
      .rdata(mem_rdata)
  );

  // Instantiate the FFT accelerator
  accelerator_fft #(
      .LOG_MAX_N (LOG_MAX_N),
      .MEM_WIDTH (32),
      .ADDR_WIDTH(ADDR_WIDTH)
  ) fft (
      .clk(clk),
      .resetn(resetn),

      .reset_accel (reset_accel),
      .enable_accel(enable_accel),

      .number_data(number_data),
      .fft_stages (fft_stages[LOG_MAX_FFT_STAGES-1:0]),

      .accel_mem_wstrb(accel_mem_wstrb),
      .accel_mem_rdata(mem_rdata),
      .accel_mem_wdata(accel_mem_wdata),
      .accel_mem_addr (accel_mem_addr),

      .fft_finished(finished_accel)
  );

  /*----------------------------------------------------------------------------------------
        INTERFACE LOGIC
    ----------------------------------------------------------------------------------------*/
  // Read paramemeters for the FFT algorithm
  assign reset_accel = iomem_accel[0][0];
  assign enable_accel = iomem_accel[0][1];
  assign number_data = iomem_accel[1][LOG_MAX_N-1:0];
  assign fft_stages = iomem_accel[2][LOG_MAX_FFT_STAGES-1:0];

  assign iomem_access_accelerator = iomem_valid && iomem_addr[31:24] == 8'h03;
  assign iomem_access_conf = iomem_access_accelerator && (iomem_addr[23:0] >> 2) < NUM_REGS;
  assign iomem_access_mem = iomem_access_accelerator && (iomem_addr[23:0] >> 2) >= NUM_REGS;

  // Select MEMORY or CONFIGURATION for the IOMEM interface
  assign iomem_ready                  = iomem_access_conf ? iomem_conf_ready : (iomem_access_mem ? iomem_mem_ready : 1'b0);
  assign iomem_rdata                  = iomem_access_conf ? iomem_conf_rdata : (iomem_access_mem ? mem_rdata : 32'b0);

  assign iomem_accel_addr = iomem_addr >> 2;
  assign mem_addr = iomem_access_mem ? {10'b0, iomem_addr[23:2] - NUM_REGS} : accel_mem_addr;

  // Select IOMEM or ACCELERATOR to access the MEMORY for write operation
  assign mem_wdata = iomem_access_mem ? iomem_wdata : accel_mem_wdata;
  assign mem_wstrb = iomem_access_mem ? iomem_wstrb : accel_mem_wstrb;

  // Manage the configuration register accesses.
  always @(posedge clk) begin
    if (!resetn) begin
      for (i = 0; i < NUM_REGS; i = i + 1) iomem_accel[i] <= 0;

      iomem_conf_ready <= 0;

      iomem_mem_ready  <= 0;
    end else begin
      iomem_accel[0][2] <= finished_accel;  // Output Finish Flag

      /*
       * Configuration register access control
       */
      if (iomem_access_conf && !iomem_conf_ready) begin
        iomem_conf_ready <= 1;

        iomem_conf_rdata <= iomem_accel[iomem_accel_addr];
        if (iomem_wstrb[0]) iomem_accel[iomem_accel_addr][7:0] <= iomem_wdata[7:0];
        if (iomem_wstrb[1]) iomem_accel[iomem_accel_addr][15:8] <= iomem_wdata[15:8];
        if (iomem_wstrb[2]) iomem_accel[iomem_accel_addr][23:16] <= iomem_wdata[23:16];
        if (iomem_wstrb[3]) iomem_accel[iomem_accel_addr][31:24] <= iomem_wdata[31:24];
      end else begin
        iomem_conf_ready <= 0;
      end

      /*
             * Accelerator memory access control
             */
      if (iomem_access_mem && !iomem_mem_ready) begin
        iomem_mem_ready <= 1'b1;
      end else begin
        iomem_mem_ready <= 1'b0;
      end
    end
  end
endmodule
