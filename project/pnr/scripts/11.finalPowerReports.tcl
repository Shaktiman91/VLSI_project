
##########################################################################
###
### Power report script with post-place-and-route activity annotation.
###
###     TU Delft EE4615
###     March 2022, C. Frenkel
###     (part of this script was adapted from place-and-route scripts developed at UCLouvain, Belgium)
###
##########################################################################


source ./scripts/1.set_variable.tcl
restoreDesign ./checkpoints/et4351_done.enc.dat et4351
setDrawView place
fit

set_power_analysis_mode -report_missing_nets true -corner delay_typ -analysis_view analysis_view_power
read_activity_file ../sim_phys/vcd/${DESIGN}.phys.hold.vcd -reset -format VCD -scope testbench/dut
propagate_activity

report_power -hierarchy all -outfile finalReports/report_power_postRouteVCD.rpt
