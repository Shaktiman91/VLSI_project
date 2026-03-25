
##########################################################################
###
### Place-and-route scripts - power planning.
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
Puts " ##                        POWER PLAN                              "
Puts " ##                                                                "
Puts " ##############################################################    "
Puts ""
Puts ""
Puts ""


# ####################
# Add power rings
# ####################

#Chip 
addRing -around default_power_domain         -nets {VSS VDD} -layer {bottom M1 top M1 right M2 left M2} -width 12 -spacing 5 -offset 2
addRing -around default_power_domain         -nets {VSS VDD} -layer {bottom M3 top M3 right M4 left M4} -width 12 -spacing 5 -offset 2

#Stripe after macros to ease followpin routing
addStripe -number_of_sets 1 -start_from left -start [expr {$coregap+3*($sram_w+$sram_gap)+$sram_w+$sram_gap+1}] -spacing 2.0 -direction vertical -layer 6 -width 8 -nets {VSS VDD} 

# ####################
# Global power net connect rules
# ####################

globalNetConnect VDD -type pgpin -pin VDD -inst *
globalNetConnect VSS -type pgpin -pin VSS -inst *

globalNetConnect VDD -type tiehi
globalNetConnect VSS -type tielo

# ####################
# SRAM power connections
# ####################

sroute -nets { VDD VSS } -connect { blockPin }


# ####################
# Add power tripes
# ####################

addStripe -number_of_sets 8 -start_from bottom -start  70 -stop 596 -spacing 2.5 -direction horizontal -layer 7 -width 8 -nets {VSS VDD} 
addStripe -number_of_sets 2 -start_from left   -start  70 -stop 155 -spacing 2.5 -direction vertical   -layer 8 -width 8 -nets {VSS VDD} 
addStripe -number_of_sets 5 -start_from left   -start 240 -stop 596 -spacing 2.5 -direction vertical   -layer 8 -width 8 -nets {VSS VDD} 


# ####################
# Followpin power connections
# ####################

sroute -nets { VDD VSS } -connect { corePin }


# #############
# # Save 	 ##
# #############

#Useful to do a check at this stage:
#verify_drc -limit 1000 -report verifyReports/verify_drc.rpt

Puts " \n\n save design \n\n"
saveDesign checkpoints/${DESIGN}_pplan.enc

fit

