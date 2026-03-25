
##########################################################################
###
### Synthesis scripts - compilation/mapping.
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
puts " #    COMPILATION                 #"
puts " #                                #"
puts " ##################################"
puts ""
puts ""


####################################################################################################
## Synthesizing to gates
####################################################################################################
# Synthesize with low effort
# set_attribute auto_ungroup none /
set_attribute syn_map_effort low
syn_map
echo "Synthesis complete"
puts "Runtime & Memory after synthesis"
timestat MAPPED


##################################################################
## Generate reports
##################################################################

set IMPL_STAGE "map"

if {![file exists ${REPORTS_PATH}/${IMPL_STAGE}]} {
  file mkdir ${REPORTS_PATH}/${IMPL_STAGE}
  puts "Creating directory ${REPORTS_PATH}/${IMPL_STAGE}"
}

report gates                      > ${REPORTS_PATH}/${IMPL_STAGE}/${DESIGN}_gates.rpt
report area                       > ${REPORTS_PATH}/${IMPL_STAGE}/${DESIGN}_area.rpt
report timing -worst 100          > ${REPORTS_PATH}/${IMPL_STAGE}/${DESIGN}_timing.rpt
report timing -lint -verbose      > ${REPORTS_PATH}/${IMPL_STAGE}/${DESIGN}_lint.rpt

