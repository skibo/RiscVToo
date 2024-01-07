#!/bin/sh
#
# all_tests.sh
#
#	Run all compliance tests using Icarus Verilog.  Usage build_compl.sh
#	to build Risc-V compliance tests.
#

WORKDIR=riscv-compliance/work
BENCHSRC="RiscVToo.srcs/sim_1/test_riscv_compl.v \
          RiscVToo.srcs/source_1/cpu/riscv_core.v \
          RiscVToo.srcs/source_1/cpu/riscv_cpu.v \
          RiscVToo.srcs/source_1/cpu/riscv_csr.v \
          RiscVToo.srcs/source_1/cpu/riscv_regfile.v"

for memfile in $WORKDIR/*.mem ; do
    test=`basename $memfile`
    echo ================= $test ====================
    iverilog -DNORAM32X1D -DMEMFILE=\"$test\" -o $WORKDIR/test $BENCHSRC
    if [ $? -ne 0 ] ; then
        echo "Aborting"
        exit 1
    fi
    (cd $WORKDIR ; ./test)
done
