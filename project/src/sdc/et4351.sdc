
##########################################################################
###
### SDC constraints file of toplevel chip design.
###
###     TU Delft EE4615 lecture on the automated digital IC design flow
###     March 2022, C. Frenkel
###
##########################################################################


#####################################
#                                   #
#    Timing in active mode          #
#                                   #
#####################################

set CLK_PERIOD         83.33
set QSPI_DIV           2

set MAX_IO_DLY         5.0
set MIN_IO_DLY         0.0

set CLK_UNCERTAINTY    0.25


#####################################
#                                   #
#    Main clocks                    #
#                                   #
#####################################

# Controller clock
create_clock -name "clk" -period "$CLK_PERIOD" -waveform "0 [expr $CLK_PERIOD/2]" [get_ports clk]

# QSPI clock
create_generated_clock -name "flash_clk" -source [get_ports clk] -divide_by "$QSPI_DIV" [get_ports flash_clk]

# Clock distribution latency and uncertainty
set_clock_uncertainty     $CLK_UNCERTAINTY    [all_clocks]


#####################################
#                                   #
#    Boundary conditions            #
#                                   #
#####################################

set_driving_cell -lib_cell INVX1 [all_inputs]

set_load -pin_load 0.050 [all_outputs]


#####################################
#                                   #
#    Input/output delays            #
#                                   #
#####################################

# RESET
set_false_path       -from  [get_ports resetn]

# UART
set_false_path       -to    [get_ports ser_tx]
set_false_path       -from  [get_ports ser_rx]

# QSPI
set_input_delay      -max [expr $CLK_PERIOD/$QSPI_DIV/2+$MAX_IO_DLY]     -clock "flash_clk"     [get_ports flash_io*]
set_input_delay      -min [expr $CLK_PERIOD/$QSPI_DIV/2+$MIN_IO_DLY]     -clock "flash_clk"     [get_ports flash_io*]
set_output_delay     -max "$MAX_IO_DLY"                                  -clock "flash_clk"     [get_ports flash_io*]
set_output_delay     -min "$MIN_IO_DLY"                                  -clock "flash_clk"     [get_ports flash_io*]
set_output_delay     -max "$MAX_IO_DLY"                                  -clock "flash_clk"     [get_ports flash_csb]
set_output_delay     -min "$MIN_IO_DLY"                                  -clock "flash_clk"     [get_ports flash_csb]

# Accelerator outputs
set_output_delay     -max "$MAX_IO_DLY"                                  -clock "clk"           [get_ports accel_o_path_node]
set_output_delay     -min "$MIN_IO_DLY"                                  -clock "clk"           [get_ports accel_o_path_node]
set_output_delay     -max "$MAX_IO_DLY"                                  -clock "clk"           [get_ports accel_o_path_node_valid]
set_output_delay     -min "$MIN_IO_DLY"                                  -clock "clk"           [get_ports accel_o_path_node_valid]
