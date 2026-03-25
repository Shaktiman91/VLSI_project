
##########################################################################
###
### ModelSim script - Behavioral simulation.
###
##########################################################################

workLib=workLib
rm -rf ${workLib}
vlib ${workLib}
vmap work ${workLib}

# et4351_tb.v et4351.v accelerator.v spimemio.v simpleuart.v picosoc.v ../picorv32.v spiflash.v
# Compile the DUT
vlog /data/Cadence/gpdk045_v60/Synopsys_sram/saed32sram.v
vlog ../src/design/accelerator.v \
     ../src/design/accelerator_fft.v \
     ../src/design/accelerator_mem.v \
     ../src/design/picosoc.v \
     ../src/design/spimemio.v \
     ../src/design/simpleuart.v \
     ../src/design/picorv32.v \
     ../src/design/et4351.v \
     +incdir+../src/                  -timescale 1ns/1ps

# Compile the testbench 
vlog     ../src/testbench/spiflash.v +define+BEHAV=1 -timescale 1ns/1ps
vlog -sv ../src/testbench/tb_et4351.sv +incdir+../src/ +define+BEHAV=1 -timescale 1ns/1ps

# Launch the simulation
# Command only mode:
vsim testbench -c -do ./scripts/run.cmd -t 10ns +firmware=../firmware/accel_audio.hex +fft_data=../firmware/fft_data.hex +is_sim_behav=1
# GUI mode:
# vsim testbench -voptargs=+acc -do ./scripts/run.cmd -t 10ns +firmware=../firmware/accel_audio.hex +fft_data=../firmware/fft_data.hex
