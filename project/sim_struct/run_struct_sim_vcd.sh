##########################################################################
###
### ModelSim script - Structural simulation.
###
##########################################################################

WORKLIB=workLib
rm -rf ${WORKLIB}
vlib ${WORKLIB}
vmap work ${WORKLIB}

# Compile libraries
vlog /data/Cadence/gpdk045_v60/gsclib045_svt_v4.7/gsclib045/verilog/slow_vdd1v0_basicCells.v
vlog /data/Cadence/gpdk045_v60/Synopsys_sram/saed32sram.v

# Compile the DUT
vlog ../synth/outputs/et4351.struct.v                   -timescale 1ns/1ps

# Compile the testbench 
vlog ../src/testbench/spiflash.v    +incdir+../src/ +define+STRUCT=1 -timescale 1ns/1ps
vlog -sv ../src/testbench/tb_et4351.sv    +incdir+../src/ +define+STRUCT=1 -timescale 1ns/1ps

# Launch the simulation
vsim testbench -c -do ./scripts/run_vcd.cmd -t 100ps \
     -sdfmax /testbench/dut=../synth/outputs/et4351.struct.sdf \
     -v2k_int_delays +nosdferror +nosdfwarn \
     +firmware=../firmware/accel_audio.hex \
     +fft_data=../firmware/fft_data.hex
