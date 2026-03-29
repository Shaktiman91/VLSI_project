##########################################################################
###
### Synthesis scripts - export.
###
###     TU Delft ET4351
###     March 2023, C. Frenkel
###     (part of this script was adapted from place-and-route scripts developed at UCLouvain, Belgium)
###
##########################################################################


puts ""
puts ""
puts " ##################################"
puts " #                                #"
puts " #    EXPORT                      #"
puts " #                                #"
puts " ##################################"
puts ""
puts ""


####################################################################
## Generate reports
####################################################################

set IMPL_STAGE "struct"

if {![file exists ${REPORTS_PATH}/${IMPL_STAGE}]} {
  file mkdir ${REPORTS_PATH}/${IMPL_STAGE}
  puts "Creating directory ${REPORTS_PATH}/${IMPL_STAGE}"
}

report gates                              > ${REPORTS_PATH}/${IMPL_STAGE}/${DESIGN}_gates.rpt
report area                               > ${REPORTS_PATH}/${IMPL_STAGE}/${DESIGN}_area.rpt

report timing -worst 100                  > ${REPORTS_PATH}/${IMPL_STAGE}/${DESIGN}_timing.rpt

report qor                                > ${REPORTS_PATH}/${IMPL_STAGE}/${DESIGN}_qor.rpt

check_design -all                         > ${REPORTS_PATH}/${IMPL_STAGE}/${DESIGN}_check.rpt
report timing -lint -verbose              > ${REPORTS_PATH}/${IMPL_STAGE}/${DESIGN}_lint.rpt

report datapath -all                      > ${REPORTS_PATH}/${IMPL_STAGE}/${DESIGN}_datapath.rpt
report sequential -hier                   > ${REPORTS_PATH}/${IMPL_STAGE}/${DESIGN}_sequential.rpt
report nets -cap_worst 50 -hierarchical   > ${REPORTS_PATH}/${IMPL_STAGE}/${DESIGN}_nets.rpt


####################################################################
## Power reports
####################################################################

# 1. Static power report (internal switching activity estimate, always available)
report power -hierarchy                   > ${REPORTS_PATH}/${IMPL_STAGE}/${DESIGN}_power_static.rpt

# 2. VCD-annotated power report (most accurate - uses physical simulation activity)
#    Uses the hold-corner VCD written by sim_phys/scripts/run_vcd_hold.cmd
set VCD_FILE "../sim_phys/vcd/${DESIGN}.phys.hold.vcd"
if {[file exists ${VCD_FILE}]} {
  puts "\nAnnotating switching activity from VCD: ${VCD_FILE}"
  read_activity_file -format VCD -scope /testbench/dut ${VCD_FILE}
  report power -hierarchy                 > ${REPORTS_PATH}/${IMPL_STAGE}/${DESIGN}_power_vcd.rpt
  puts "VCD-annotated power report written to ${REPORTS_PATH}/${IMPL_STAGE}/${DESIGN}_power_vcd.rpt"
} else {
  puts "\nINFO: VCD file not found at ${VCD_FILE}"
  puts "      Run sim_phys first to generate the VCD, then re-run synthesis export"
  puts "      for an activity-annotated power report."
}


####################################################################
## Generate output files for structural simulation and PnR
####################################################################

change_names -verilog
write_encounter *

write_hdl ${DESIGN} > ${OUTPUTS_PATH}/${DESIGN}.struct.v
write_sdc ${DESIGN} > ${OUTPUTS_PATH}/${DESIGN}.struct.sdc

write_sdf -nonegchecks -interconn "interconnect" -delimiter "/" > ${OUTPUTS_PATH}/${DESIGN}.struct.sdf
