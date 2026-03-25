
##########################################################################
###
### Place-and-route scripts - sample IO placement file.
###
###     TU Delft ET4351
###     March 2023, C. Frenkel
###     (part of this script was adapted from place-and-route scripts developed at UCLouvain, Belgium)
###
##########################################################################


(globals
	version = 3
	io_order = default
)
(iopin
	(right
	(pin name="clk"           offset=280.0000 layer=3 width=0.2800 depth=0.5000 )
	(pin name="resetn"        offset=281.0000 layer=3 width=0.2800 depth=0.5000 )
	(pin name="ser_tx"        offset=290.0000 layer=3 width=0.2800 depth=0.5000 )
	(pin name="ser_rx"        offset=291.0000 layer=3 width=0.2800 depth=0.5000 )
	)
	(left
	(pin name="flash_csb"     offset=280.0000 layer=3 width=0.2800 depth=0.5000 )
	(pin name="flash_clk"     offset=281.0000 layer=3 width=0.2800 depth=0.5000 )
	(pin name="flash_io0"     offset=282.0000 layer=3 width=0.2800 depth=0.5000 )
	(pin name="flash_io1"     offset=283.0000 layer=3 width=0.2800 depth=0.5000 )
	(pin name="flash_io2"     offset=284.0000 layer=3 width=0.2800 depth=0.5000 )
	(pin name="flash_io3"     offset=285.0000 layer=3 width=0.2800 depth=0.5000 )

	(pin name="accel_o_path_node_valid"     offset=286.0000 layer=3 width=0.2800 depth=0.5000 )
	(pin name="accel_o_path_node[0]"        offset=287.0000 layer=3 width=0.2800 depth=0.5000 )
	(pin name="accel_o_path_node[1]"        offset=288.0000 layer=3 width=0.2800 depth=0.5000 )
	(pin name="accel_o_path_node[2]"        offset=289.0000 layer=3 width=0.2800 depth=0.5000 )
	(pin name="accel_o_path_node[3]"        offset=290.0000 layer=3 width=0.2800 depth=0.5000 )
	(pin name="accel_o_path_node[4]"        offset=291.0000 layer=3 width=0.2800 depth=0.5000 )
	(pin name="accel_o_path_node[5]"        offset=292.0000 layer=3 width=0.2800 depth=0.5000 )
	(pin name="accel_o_path_node[6]"        offset=293.0000 layer=3 width=0.2800 depth=0.5000 )
	(pin name="accel_o_path_node[7]"        offset=294.0000 layer=3 width=0.2800 depth=0.5000 )
	)
)