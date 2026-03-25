
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
## Generate output files for structural simulation and PnR
####################################################################

change_names -verilog
write_encounter *

write_hdl ${DESIGN} > ${OUTPUTS_PATH}/${DESIGN}.struct.v
write_sdc ${DESIGN} > ${OUTPUTS_PATH}/${DESIGN}.struct.sdc

write_sdf -nonegchecks -interconn "interconnect" -delimiter "/" > ${OUTPUTS_PATH}/${DESIGN}.struct.sdf 
