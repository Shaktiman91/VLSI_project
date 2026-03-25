
##########################################################################
###
### Place-and-route scripts - floorplanning.
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
Puts " ##                        FLOORPLAN                               "
Puts " ##                                                                "
Puts " ##############################################################    "
Puts ""
Puts ""
Puts ""


setDrawView fplan

# ####################
# FLOOR PLAN VARIABLES
# ####################

set rowgap 0.0

# gap between the core and the power rails (FEED1 size: 0.2 BY 1.71)  
set coregap 34.2

# Core dimensions (if first floorPlan option selected below)
set Wcore 596.4
set Hcore 596.4


# ####################
# FLOOR PLAN DRAW
# #################### 

setFPlanRowSpacingAndType $rowgap 1

floorPlan -site CoreSite -s $Wcore $Hcore $coregap $coregap $coregap $coregap -noSnapToGrid

loadIoFile ./scripts/3.1.ET4351_chip.io

set sram_gap   2.000
set sram_ring 22.000
set sram_w    36.835
set sram_h   234.390

placeInstance soc/memory/sram_3     [expr {$coregap                      }] [expr {$coregap+$Hcore-$sram_h}] R0
placeInstance soc/memory/sram_2     [expr {$coregap+  ($sram_w+$sram_gap)}] [expr {$coregap+$Hcore-$sram_h}] R0
placeInstance soc/memory/sram_1     [expr {$coregap+2*($sram_w+$sram_gap)}] [expr {$coregap+$Hcore-$sram_h}] R0
placeInstance soc/memory/sram_0     [expr {$coregap+3*($sram_w+$sram_gap)}] [expr {$coregap+$Hcore-$sram_h}] R0

addHaloToBlock 0  $sram_gap  $sram_gap  0 -fromInstBox soc/memory/sram_3
addHaloToBlock 0  $sram_gap  $sram_gap  0 -fromInstBox soc/memory/sram_2
addHaloToBlock 0  $sram_gap  $sram_gap  0 -fromInstBox soc/memory/sram_1
addHaloToBlock 0  $sram_gap  $sram_ring 0 -fromInstBox soc/memory/sram_0


# #############
# # Report 	 ##
# #############

checkFPlan -outFile verifyReports/checkFPlan.rpt


# #############
# # Save 	 ##
# #############

Puts " \n\n save Design \n\n"
saveDesign checkpoints/${DESIGN}_fplan.enc
saveFPlan  checkpoints/${DESIGN}.fp

fit
