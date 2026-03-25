 
/*##########################################################################
###
### Dummy et4351 chip (top level)
###    
###     TU Delft ET4351
###     April 2023, C.Gao, C. Frenkel
###
##########################################################################*/

module et4351 (
	input  clk,
	input  resetn,

	output ser_tx,
	input  ser_rx,

	output flash_csb,
	output flash_clk,
	inout  flash_io0,
	inout  flash_io1,
	inout  flash_io2,
	inout  flash_io3
);

    // ------------------------------------------ Sync barriers: ----------------------------------------

	reg       ser_rx_sync_int, ser_rx_sync;
	reg       resetn_sync_int, resetn_sync;

	always @(posedge clk) begin
		ser_rx_sync_int <= ser_rx;
		ser_rx_sync     <= ser_rx_sync_int;
		resetn_sync_int <= resetn;
		resetn_sync     <= resetn_sync_int;
	end

	wire flash_io0_oe, flash_io0_do, flash_io0_di;
	wire flash_io1_oe, flash_io1_do, flash_io1_di;
	wire flash_io2_oe, flash_io2_do, flash_io2_di;
	wire flash_io3_oe, flash_io3_do, flash_io3_di;

	bidir_buf flash_bufs [3:0] (
		.oe({flash_io3_oe, flash_io2_oe, flash_io1_oe, flash_io0_oe}),
		.soc_o({flash_io3_do, flash_io2_do, flash_io1_do, flash_io0_do}),
		.soc_i({flash_io3_di, flash_io2_di, flash_io1_di, flash_io0_di}),
		.io({flash_io3, flash_io2, flash_io1, flash_io0})
	);

	wire        iomem_valid;
	wire        iomem_ready;
	wire [3:0]  iomem_wstrb;
	wire [31:0] iomem_addr;
	wire [31:0] iomem_wdata;
	wire [31:0] iomem_rdata;


	// PicoSoC
	picosoc soc (
		.clk          (clk         ),
		.resetn       (resetn_sync ),

		.ser_tx       (ser_tx      ),
		.ser_rx       (ser_rx      ),

		.flash_csb    (flash_csb   ),
		.flash_clk    (flash_clk   ),

		.flash_io0_oe (flash_io0_oe),
		.flash_io1_oe (flash_io1_oe),
		.flash_io2_oe (flash_io2_oe),
		.flash_io3_oe (flash_io3_oe),

		.flash_io0_do (flash_io0_do),
		.flash_io1_do (flash_io1_do),
		.flash_io2_do (flash_io2_do),
		.flash_io3_do (flash_io3_do),

		.flash_io0_di (flash_io0_di),
		.flash_io1_di (flash_io1_di),
		.flash_io2_di (flash_io2_di),
		.flash_io3_di (flash_io3_di),

		.irq_5        (1'b0        ),
		.irq_6        (1'b0        ),
		.irq_7        (1'b0        ),

		.iomem_valid  (iomem_valid ),
		.iomem_ready  (iomem_ready ),
		.iomem_wstrb  (iomem_wstrb ),
		.iomem_addr   (iomem_addr  ),
		.iomem_wdata  (iomem_wdata ),
		.iomem_rdata  (iomem_rdata )
	);

	// Accelerator
	accelerator accel (
		.clk          (clk         ),
		.resetn       (resetn_sync ),
		.iomem_valid  (iomem_valid ),
		.iomem_ready  (iomem_ready ),
		.iomem_wstrb  (iomem_wstrb ),
		.iomem_addr   (iomem_addr  ),
		.iomem_wdata  (iomem_wdata ),
		.iomem_rdata  (iomem_rdata )
	);
	
endmodule

module bidir_buf (
	input  wire oe,
	input  wire soc_o,
	output wire soc_i,
	inout  wire io
);
	assign io = oe ? soc_o : 1'bz;
	assign soc_i = io;
endmodule
