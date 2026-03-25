
##########################################################################
###
### Place-and-route scripts - export.
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
Puts " ##                        EXPORT                                  "
Puts " ##                                                                "
Puts " ##############################################################    "
Puts ""
Puts ""
Puts ""


# Export Verilog netlist for simulation
saveNetlist outputs/${DESIGN}.phys.v

# Export SDF
write_sdf -min_view analysis_view_hold -max_view analysis_view_setup -typ_view analysis_view_power -delimiter "/" outputs/${DESIGN}.phys.sdf

# Export .enc
saveDesign checkpoints/${DESIGN}_done.enc

# gds
streamOut outputs/${DESIGN}.phys.gds
