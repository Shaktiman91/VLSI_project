
##########################################################################
###
### Synthesis Settings
###
###     TU Delft ET4351
###     May 2023, C. Frenkel, C. Gao
###     (part of this script was adapted from place-and-route scripts developed at UCLouvain, Belgium)
###
##########################################################################


puts ""
puts ""
puts " ##################################"
puts " #                                #"
puts " #    SETTINGS                    #"
puts " #                                #"
puts " ##################################"
puts ""
puts ""

# Path variables
set DESIGN           et4351
set INPUT_PATH       "../src/"

# Technology files
set TECH_PATH        "/data/Cadence/gpdk045_v60/gsclib045_svt_v4.7/gsclib045_tech"
set TECH_LEF         "${TECH_PATH}/lef/gsclib045_tech.lef"

# Standard cells 
set STD_CELLS_PATH   "/data/Cadence/gpdk045_v60/gsclib045_svt_v4.7/gsclib045"
set STD_CELLS_LIB    "${STD_CELLS_PATH}/timing/slow_vdd1v0_basicCells.lib"
set STD_CELLS_LEF    "${STD_CELLS_PATH}/lef/gsclib045_macro.lef"

# SRAMs
set SRAM_PATH        "/data/Cadence/gpdk045_v60/Synopsys_sram"
set SRAM_LIB         "${SRAM_PATH}/saed32sram_ss0p95vn40c.lib"
set SRAM_LEF         "${SRAM_PATH}/saed32sram.lef"


##############################################################################
## Preset global variables and attributes
##############################################################################
set_attribute max_cpus_per_server 4
# Define reporting options
set_attr information_level 6
set_attr hdl_track_filename_row_col true
set_attr lp_power_unit uW /
set_attr max_print 2 [find / -message "LBR-21"]
set_attr max_print 2 [find / -message "LBR-38"]
set_attr max_print 2 [find / -message "LBR-39"]
set_attr max_print 2 [find / -message "LBR-81"]
set_attr max_print 2 [find / -message "PHYS-15"]
set_attr max_print 2 [find / -message "TUI-92"]
set_attr max_print 2 [find / -message "TUI-710"]
# warning when reading libs
set_attr max_print 2 [find / -message "ELABUTL-123"]  
set_attr max_print 2 [find / -message "PHYS-113"] 
set_attr max_print 2 [find / -message "CDFG-818"] 
set_attr max_print 2 [find / -message "PHYS-107"]
set_attr max_print 2 [find / -message "PHYS-124"]
# Added for TSMC-N65 
set_attr max_print 2 [find / -message "PHYS-129"]
set_attr max_print 2 [find / -message "LBR-9"]
set_attr max_print 2 [find / -message "LBR-40"]
set_attr max_print 2 [find / -message "LBR-41"]
set_attr max_print 2 [find / -message "LBR-76"]
set_attr max_print 2 [find / -message "LBR-155"]
set_attr max_print 2 [find / -message "LBR-162"]
set_attr max_print 2 [find / -message "LBR-170"]
set_attr max_print 2 [find / -message "CHNM-102"]
set_attr max_print 2 [find / -message "ELABUTL-124"]
set_attr max_print 2 [find / -message "ELABUTL-132"]
set_attr max_print 2 [find / -message "GLO-42"]


##############################################################################
## Setup of Physical Layout Estimation (PLE)
##############################################################################

set_attr lib_lef_consistency_check_enable false /

# Provide LEF files
set LEF_LIST " \
${TECH_LEF} \
${STD_CELLS_LEF} \
${SRAM_LEF} "

set_attribute lef_library ${LEF_LIST} /

# Power report unit
set_attribute lp_power_unit uW


##############################################################################
## Setup of the design & libs directories
##############################################################################

# Path to source verilog code
set_attribute hdl_search_path " \
${INPUT_PATH} " /

# Path to standard-cell libraries
set_attribute lib_search_path " \
${STD_CELLS_PATH}/ \
${SRAM_PATH}/ " /

# Standard-cell libraries
set_attribute library " \
${STD_CELLS_LIB} \
${SRAM_LIB} " /


##############################################################################
## Setup of the directories
##############################################################################

set OUTPUTS_PATH   "./outputs"
set REPORTS_PATH   "./reports"


if {![file exists ${OUTPUTS_PATH}]} {
  file mkdir ${OUTPUTS_PATH}
  puts "Creating directory ${OUTPUTS_PATH}"
}
if {![file exists ${REPORTS_PATH}]} {
  file mkdir ${REPORTS_PATH}
  puts "Creating directory ${REPORTS_PATH}"
}


##############################################################################
# (Un)usable cells
##############################################################################

# Avoid scan FFs
set_attribute avoid true SDFF*
set_attribute avoid true SEDFF*
set_attribute avoid true SMDFF*
