#
# run_compl.tcl
#
#	Script to run RiscV compliance tests.  Must be run from project root
#	directory.  See the build_compl.sh script about checking out the
#	tests and building them.
#
#	Usage: vivado -mode batch -source RiscVToo.srcs/scripts/run_compl.tcl
#

proc do_compl_test {memfile} {
#    set_property generic "MEM_INIT_FILE=\"$memfile\" IBUS_VERBOSE=1" \
#        [get_filesets sim_1]
    set_property generic "MEM_INIT_FILE=\"$memfile\"" [get_filesets sim_1]
    
    puts "Starting compliance test, memfile=$memfile"

    launch_simulation

    run 100 us

    # Check top level logic signal "test_pass"
    if {[get_value test_pass] != 1} {
        # Test either hung or failed.
        puts "Test Failed! memfile=$memfile"
        exit 1
    } else {
        puts "Test Passed! memfile=$memfile"
    }

    close_sim
}


open_project RiscVToo/RiscVToo.xpr

set tests [glob riscv-compliance/work/*.mem]

if {[llength $tests] < 1} {
    puts "Could not find compliance test .mem files"
    puts "See the build_compl.sh script"
    exit 1
}

# Add compliance test mem files to project if they aren't there
if {[get_files -of [get_filesets sim_1] \
         -filter {NAME =~ *I-ADD-01.mem}] == ""} {
    puts "Adding compliance test .mem files to project."

    foreach test $tests {
        puts [file normalize $test]
        add_files -fileset sim_1 -norecurse [file normalize $test]
    }
}

set_property top test_riscv_compl [get_filesets sim_1]
update_compile_order -fileset sim_1

foreach test $tests {
    do_compl_test [file tail $test]
}

close_project
