/*##########################################################################
###
### Toplevel SoC Testbench
###
###     TU Delft ET4351
###     April 2023, C. Gao
###
##########################################################################*/
`timescale 1 ns / 1 ps

module testbench;
	// Local Parameters
	localparam clk_period = 83.33; // Clock cycle in ns
	localparam clk_half_period = clk_period / 2;
	localparam ser_half_period = 53;
	localparam freq_show_cycles = 1000;  // Number of clock cycles between each cycle count display
    localparam num_init_cycles = 10; // Number of clock cycles for resetn = 1
    localparam num_reset_cycles = 10; // Number of clock cycles for resetn = 0

    // Signals
    logic clk;
    logic resetn;
    logic ser_rx;
	wire  ser_tx;
	wire  flash_csb;
	wire  flash_clk;
	wire  flash_io0;
	wire  flash_io1;
	wire  flash_io2;
	wire  flash_io3;

	// Real Values
	real latency_ms;

	// Generate clock
	always #clk_half_period clk = (clk === 1'b0);

	// Clock Cycle Counter
	integer cnt_cycles = 0;
	always @(posedge clk) begin
		cnt_cycles <= cnt_cycles + 1;
	end

	reg is_sim_behav;
	initial begin
		if (!$value$plusargs("is_sim_behav=%b", is_sim_behav)) begin
			is_sim_behav = 0; // Default value
		end
	end

	// Start simulation
	integer file;  // File handle
	initial begin
		$display("##################################################");
		$display("# Start of Testbench 						        ");
		$display("##################################################");

        // Reset
        ser_rx = 0;
        resetn = 1;
        repeat (num_init_cycles) @(posedge clk);
        resetn = 0;
        repeat (num_reset_cycles) @(posedge clk);
        resetn = 1;

		// Create a file store simulation outputs
		file = $fopen("outputs.txt", "w");

		// Run
		while (1) begin
			@(posedge clk);
			if (cnt_cycles % freq_show_cycles == 0) begin
				`ifdef DISPLAY_CYCLES
				$display("+%d cycles", cnt_cycles);
				`endif
			end
		end
	end

	et4351 dut (
		.clk      (clk      ),
		.resetn   (resetn   ),
		.ser_rx   (ser_rx   ),
		.ser_tx   (ser_tx   ),
		.flash_csb(flash_csb),
		.flash_clk(flash_clk),
		.flash_io0(flash_io0),
		.flash_io1(flash_io1),
		.flash_io2(flash_io2),
		.flash_io3(flash_io3)
	);
	
	spiflash spiflash (
		.csb(flash_csb),
		.clk(flash_clk),
		.io0(flash_io0),
		.io1(flash_io1),
		.io2(flash_io2),
		.io3(flash_io3)
	);

	logic [7:0] buffer_tx;

    integer accel_start_cycles = 0;
    integer accel_finish_cycles = 0;
	integer total_accel_cycles = 0;

	logic [7:0] is_accel_enabled;
	logic [7:0] did_accel_run_once;
    integer first_accel_start_cycles = 0;
    integer first_accel_finish_cycles = 0;

	initial begin
		is_accel_enabled = 0;
		did_accel_run_once = 0;

		while(1) begin
			@(posedge clk);

			if (is_sim_behav == 0) begin
				break; // Skip the rest of the loop if not in behavioral simulation mode
			end

			if (is_accel_enabled == 0 && dut.accel.fft.enable_accel == 1 && dut.accel.fft.fft_finished == 0) begin
				accel_start_cycles = cnt_cycles;
				is_accel_enabled = 1;
			end else if (is_accel_enabled == 1 && dut.accel.fft.fft_finished == 1) begin
				accel_finish_cycles = cnt_cycles;    
				total_accel_cycles = total_accel_cycles + (accel_finish_cycles - accel_start_cycles);

				if (did_accel_run_once == 0) begin
					first_accel_start_cycles = accel_start_cycles;
					first_accel_finish_cycles = accel_finish_cycles;

					did_accel_run_once = 1;
				end
				
				is_accel_enabled = 0;
			end
		end
	end

	initial begin
        while(1) begin
            @(negedge ser_tx);

            // start bit
            repeat (ser_half_period) @(posedge clk);

            // data bit
            repeat (8) begin
                repeat (ser_half_period) @(posedge clk);
                repeat (ser_half_period) @(posedge clk);
                buffer_tx = {ser_tx, buffer_tx[7:1]};
            end

            // stop bit
            repeat (ser_half_period) @(posedge clk);
            repeat (ser_half_period) @(posedge clk);

            if (buffer_tx == 255) begin    // use -1 ASCII code to stop simulation
                $display("Complete latency in Clock Cycles:       %d", cnt_cycles);
				if (is_sim_behav == 1) begin
					$display("Accelerator runtime in Clock Cycles:    %d", total_accel_cycles);
				end else begin
					$display("Accelerator runtime in Clock Cycles:    N/A (not in behavioral simulation mode)");
				end
                latency_ms = cnt_cycles * clk_period / 1000.0 / 1000.0;
                $display("Complete latency in Milliseconds:       %f", latency_ms);
				// Accelerator latency is not (yet) updated so that the time for waiting for UART commands is not counted
                latency_ms = (total_accel_cycles) * clk_period / 1000.0 / 1000.0;
				if (is_sim_behav == 1) begin
                	$display("Accelerator runtime in Milliseconds:    %f", latency_ms);
					$display("Acceleration of first chunk started at (Milliseconds): %f", first_accel_start_cycles * clk_period / 1000.0 / 1000.0);
					$display("Latency of first chunk is (MICROseconds): %f", (first_accel_finish_cycles - first_accel_start_cycles) * clk_period / 1000.0 );
				end else begin
					$display("Accelerator runtime in Milliseconds:    N/A (not in behavioral simulation mode)");
				end
                $display("##################################################");
                $display("# End of Testbench 						        ");
                $display("##################################################");
                $finish;
            end else if (buffer_tx == 13 || buffer_tx == 10) begin	// CR or LF
                $write("\n");
				$fwrite(file, "%c", buffer_tx);
            end else begin
                $write("%c", buffer_tx);
                $fwrite(file, "%c", buffer_tx);
            end
        end
	end

    // Timeout watchdog
    initial begin
        repeat(10e8) @(posedge clk);
        $display("ERROR: Simulation timeout!");
        $finish;
    end
    
endmodule
