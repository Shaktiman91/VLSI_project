
##########################################################################
###
### Place-and-route scripts - variable settings.
###
###     TU Delft ET4351
###     March 2023, C. Frenkel
###     (part of this script was adapted from place-and-route scripts developed at UCLouvain, Belgium)
###
##########################################################################


setMessageLimit 1     ENCLF 45
setMessageLimit 1     ENCLF 119
setMessageLimit 1     ENCLF 200
setMessageLimit 1     ENCLF 201
setMessageLimit 10    IMPDB 2078
setMessageLimit 10    IMPDC 348


# ###############################
#
#		DESIGN
#
# ###############################

set DESIGN "et4351"

set DESIGN_PATH "../synth/outputs"

set PROCESS 45

setMultiCpuUsage -localCpu 4 -cpuPerRemoteHost 4 -remoteHost 1 -keepLicense true


# ###############################
#
#		LEF FILES
#
# ###############################

set LEF_FILES " \
/data/Cadence/gpdk045_v60/gsclib045_svt_v4.7/gsclib045_tech/lef/gsclib045_tech.lef \
/data/Cadence/gpdk045_v60/gsclib045_svt_v4.7/gsclib045/lef/gsclib045_macro.lef \
/data/Cadence/gpdk045_v60/Synopsys_sram/saed32sram.lef "


# ###############################
#
#		LIB FILES
#
# ###############################

#Note: there is usually a "TYP" view as well, which is usually used for power extraction. It is not the case in this 45nm standard cell library, so using the min-timing view instead.
set LIB_FILES_TYP " \
/data/Cadence/gpdk045_v60/gsclib045_svt_v4.7/gsclib045/timing/fast_vdd1v2_basicCells.lib \
/data/Cadence/gpdk045_v60/Synopsys_sram/saed32sram_tt1p05v125c.lib "

set LIB_FILES_MAX " \
/data/Cadence/gpdk045_v60/gsclib045_svt_v4.7/gsclib045/timing/slow_vdd1v0_basicCells.lib \
/data/Cadence/gpdk045_v60/Synopsys_sram/saed32sram_ss0p95vn40c.lib "

set LIB_FILES_MIN " \
/data/Cadence/gpdk045_v60/gsclib045_svt_v4.7/gsclib045/timing/fast_vdd1v2_basicCells.lib \
/data/Cadence/gpdk045_v60/Synopsys_sram/saed32sram_ff1p16vn40c.lib "


# ###############################
#
#		CAPTABLE FILES
#
# ###############################

set QRC "/data/Cadence/gpdk045_v60/gsclib045_svt_v4.7/gsclib045_tech/qrc/qx/gpdk045.tch"




