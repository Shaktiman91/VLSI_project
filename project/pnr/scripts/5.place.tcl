
##########################################################################
###
### Place-and-route scripts - standard cell placement.
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
Puts " ##                        PLACE                                   "
Puts " ##                                                                "
Puts " ##############################################################    "
Puts ""
Puts ""
Puts ""



# Give the activity extracted from structural simulations
set_power_analysis_mode -report_missing_nets true -corner delay_typ -analysis_view analysis_view_power
read_activity_file ../sim_struct/vcd/${DESIGN}.struct.vcd -reset -format VCD -scope testbench/dut
propagate_activity

report_power -outfile powerReports/prePlace_VCDImport.rpt


# ####################
# Place standard cells
# ####################

setPlaceMode -place_global_cong_effort high \
             -place_global_solver_effort high \
             -place_global_timing_effort medium \
             -place_global_activity_power_driven true \
             -place_global_activity_power_driven_effort standard \
             -place_global_uniform_density true
setDesignMode -topRoutingLayer 10
set delaycal_use_default_delay_limit 1000
setExtractRCMode -engine preRoute -effortLevel high

placeDesign
place_opt_design -incremental -out_dir timingReports/place_opt_design.rpt

setDrawView place

trialRoute -noDetour


# ####################
# Add Tie High and Tie Low cells
# ####################

addTieHiLo -prefix TIEHILO_ -cell "TIEHI TIELO"


# ####################
# PRE-CTS REPORTS
# ####################

set_power_analysis_mode -method static -corner delay_typ -create_binary_db true -write_static_currents true -honor_negative_energy true -ignore_control_signals true -analysis_view analysis_view_power

timeDesign -preCTS -outDir timingReports/preCTS
timeDesign -preCTS -hold -outDir timingReports/preCTS_hold
report_power -outfile powerReports/preCTS.rpt

reportDensityMap
checkPlace verifyReports/checkPlace.rpt


# #############
# # Save 	 ##
# #############


Puts " \n\n save Design \n\n"
saveDesign checkpoints/${DESIGN}_place.enc

fit
