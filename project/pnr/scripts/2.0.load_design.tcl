
##########################################################################
###
### Place-and-route scripts - load and initialize design.
###
###     TU Delft ET4351
###     March 2023, C. Frenkel
###     (part of this script was adapted from place-and-route scripts developed at UCLouvain, Belgium)
###
##########################################################################

 
Puts ""
Puts ""
Puts ""
Puts " ##############################################################    "
Puts " ##                                                                "
Puts " ##                         LOAD DESIGN                            "
Puts " ##                                                                "
Puts " ##############################################################    "
Puts ""
Puts ""
Puts ""


#
#
#    Define VDD & GND
#
#

set init_pwr_net {VDD}
set init_gnd_net {VSS}


#
#
#	Source the synthesized netlist
#
#

set init_design_settop	1
set init_verilog $DESIGN_PATH/$DESIGN.struct.v
set init_top_cell $DESIGN


#
#
#	Source .lef files
#
#

set init_lef_file $LEF_FILES


#
#
#	Source .lib files and post-synthesis SDC file
#
#

set init_mmmc_file ./scripts/2.1.set_library_n_sdc.tcl

setDesignMode -process $PROCESS

setDelayCalMode -SIAware true

setAnalysisMode -analysisType onChipVariation -cppr both


#
#
#	Initialize design 
#
#

init_design


#
#
#	Reports
#
#

report_design > initialReports/report_design.rpt

report_constraint > initialReports/report_constraint.rpt

report_clocks > initialReports/report_clocks.rpt

report_ports > initialReports/report_ports.rpt

report_path_exceptions > initialReports/report_path_exceptions.rpt

report_annotated_check > initialReports/report_annotated_check.rpt


