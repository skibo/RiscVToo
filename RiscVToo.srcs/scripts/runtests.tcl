#
#
#
proc do_cpu_test {memfile {count 1} {delays 1}} {
    set_property generic \
        "MEM_INIT_FILE=\"$memfile\" IMEM_DELAYS=$delays DMEM_DELAYS=$delays" \
        [get_filesets sim_1]

    launch_simulation

    for {set i 0} {$i < $count} {incr i} {
        puts "Starting cpu test #$i memfile=$memfile delays=$delays"

        run 100 us

        # Check top level logic signal "test_pass"
        if {[get_value test_pass] != 1} {
            # Test either hung or failed.
            puts "Test Failed! memfile=$memfile delays=$delays"
            exit 1
        } else {
            puts "Test Passed! memfile=$memfile delays=$delays"
        }

        if {$i < [expr $count - 1]} {
            restart
        }
    }

    close_sim
}

proc do_too_test {memfile {count 1} {waitrange 0}} {
    set_property generic "MEM_INIT_FILE=\"$memfile\" WAITRANGE=$waitrange" \
        [get_filesets sim_1]

    launch_simulation

    for {set i 0} {$i < $count} {incr i} {
        puts "Starting riscv_too test #$i memfile=$memfile waitrange=$waitrange";

        run 200 us

        # Check top level logic signal "test_pass"
        if {[get_value test_pass] != 1} {
            # Test either hung or failed.
            puts "Test Failed! memfile=$memfile waitrange=$waitrange"
            exit 1
        } else {
            puts "Test Passed! memfile=$memfile waitrange=$waitrange"
        }

        if {$i < [expr $count - 1]} {
            restart
        }
    }

    close_sim
}

open_project RiscVToo/RiscVToo.xpr

# test_riscv_cpu tests:
set_property top test_riscv_cpu [get_filesets sim_1]
update_compile_order -fileset sim_1

# No delays
do_cpu_test "test1.mem" 1 0
do_cpu_test "test2.mem" 1 0
do_cpu_test "test3.mem" 1 0
do_cpu_test "testcsr.mem" 1 0

# Random delays
do_cpu_test "test1.mem" 200
do_cpu_test "test2.mem" 200
do_cpu_test "test3.mem" 200
do_cpu_test "testcsr.mem" 200

set_property top test_riscv_too [get_filesets sim_1]
update_compile_order -fileset sim_1

do_too_test "test_timer.mem"
do_too_test "test_too.mem"

do_too_test "test_too.mem" 200 4

close_project
