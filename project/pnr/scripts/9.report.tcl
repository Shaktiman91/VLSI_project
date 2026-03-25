
##########################################################################
###
### Place-and-route scripts - final reports.
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
Puts " ##                        REPORT                                  "
Puts " ##                                                                "
Puts " ##############################################################    "
Puts ""
Puts ""
Puts ""

setSIMode -enable_glitch_report true
setSIMode -enable_delay_report true

report_power -hierarchy all -outfile finalReports/report_power.rpt

report_area -out_file finalReports/report_area.rpt

#Reduce effort level as only captables are available
setExtractRCMode -engine postRoute -effortLevel high
setDelayCalMode -reset -siMode

timeDesign -postRoute -pathReports -slackReports -numPaths 50 -outDir finalReports/report_timing
timeDesign -postRoute -hold -pathReports -slackReports -numPaths 50 -outDir finalReports/report_timing_hold
timeDesign -postRoute -drvReports -numPaths 500 -outDir finalReports/report_DRV
report_noise -bumpy_waveform -output_file finalReports/bumpyWaves.rpt 
