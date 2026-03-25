
##########################################################################
###
### Master synthesis script, including settings.
###
### Start this script with:
###   genus -legacy_ui -64 -f scripts/synth_cg.tcl
###
###
###     TU Delft ET4351
###     May 2023, C. Frenkel, C. Gao
###     (part of this script was adapted from place-and-route scripts developed at UCLouvain, Belgium)
###
##########################################################################





##############################################################################
# Run the different synthesis steps
##############################################################################
# Settings
source scripts/synth_set.tcl

#suspend

# Elaboration
source scripts/synth_elbcg.tcl

#suspend

# Compilation
source scripts/synth_map.tcl

#suspend

# Export
source scripts/synth_exp.tcl



