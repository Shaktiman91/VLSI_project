
##########################################################################
###
### ModelSim script - Physical simulation (typical timing)
###
###     TU Delft EE4615 lecture on the automated digital IC design flow
###     May 2022, C. Frenkel, C. Gao
###
##########################################################################


workLib=workLib
rm -rf ${workLib}
vlib ${workLib}
vmap work ${workLib}


# Compile libraries
vlog /data/Cadence/gpdk045_v60/gsclib045_svt_v4.7/gsclib045/verilog/slow_vdd1v0_basicCells.v
vlog /data/Cadence/gpdk045_v60/Synopsys_sram/saed32sram.v

# Compile the DUT
vlog ../pnr/outputs/et4351.phys.v                   -timescale 1ns/1ps

# Compile the testbench 
vlog ../src/testbench/spiflash.v    +incdir+../src/ +define+PHYS=1 -timescale 1ns/1ps
vlog -sv ../src/testbench/tb_et4351.sv    +incdir+../src/ +define+PHYS=1 -timescale 1ns/1ps

# Launch the simulation
vsim testbench -c -do ./scripts/run_vcd_setup.cmd -t 1ns \
            -sdfmax /testbench/dut=../pnr/outputs/et4351.phys.sdf \
            +nosdferror -v2k_int_delays +nosdferror +nosdfwarn \
            +firmware=../firmware/accel_audio.hex \
            +fft_data=../firmware/fft_data.hex

