
##########################################################################
###
### Place-and-route scripts - verifications (LVS, DRC, ANTENNA).
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
Puts " ##                        VERIFY                                  "
Puts " ##                                                                "
Puts " ##############################################################    "
Puts ""
Puts ""
Puts ""
 
clearDrc

# connectivity
verifyConnectivity -type all -error 1000 -warning 50 -report verifyReports/verifyConnectivity.rpt

# geometry
verify_drc -limit 1000 -report verifyReports/verify_drc.rpt

# antenna
verifyProcessAntenna -error 1000 -reportfile verifyReports/verifyProcessAntenna.rpt
