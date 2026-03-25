# Create a vcd directory if it doesn't exist
if {![file exists vcd]} {
    file mkdir vcd
}

# Update this value with the accelerator start time
run 36.181386ms

# Start activity annotation
set vcd_file "./vcd/et4351.phys.setup.vcd"
vcd files $vcd_file
vcd add -r -internal -ports -file $vcd_file /*
vcd dumpportson $vcd_file
vcd on $vcd_file

# Update this value with the accelerator runtime
run 60.997560us

# Stop activity annotation
vcd off $vcd_file
vcd dumpportsoff $vcd_file

run -all

exit
 