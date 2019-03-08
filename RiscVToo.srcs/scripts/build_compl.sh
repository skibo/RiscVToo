#!/bin/sh
#
# build_compl.sh
#
#       Build compliance tests.  Expects compliance tests to be git cloned
#	from https://github.com/riscv/riscv-compliance.git.  Script should
#	be run from top directory of RiscVToo project.  Use all_tests.sh
#	to run them using Icarus Verilog.
#

if [ "$XILINX_VIVADO" = "" ] ; then
   echo "XILINX_VIVADO must be set to point to Xilinx tools"
   exit 1
fi

if [ "$RISCV" = "" ] ; then
    echo "RISCV must be set to point to RiscV toolchain"
    exit 1
fi

RISCV_TARGET=riscvOVPsim
RISCV_DEVICE=rv32i

# Local directory of compliance tests cloned from
# https://github.com/riscv/riscv-compliance
COMPLDIR=riscv-compliance
COMPLSUITE=$COMPLDIR/riscv-test-suite/$RISCV_DEVICE/src

if [ ! -d $COMPLDIR ] ; then
   echo "Missing source for compliance tests.  Please"
   echo "git clone https://github.com/riscv/riscv-compliance.git $COMPLDIR"
   exit 1
fi

RISCV_PREFIX=$RISCV/bin/riscv32-unknown-elf-
RISCV_GCC_OPTS="-march=rv32i -mabi=ilp32 -static -mcmodel=medany -fvisibility=hidden -nostdlib -nostartfiles"
#BIN2HEX='/usr/bin/hexdump -v -e \'/4 "%08X\\n"\''
# echo $BIN2HEX ; exit 1

if [ ! -d $COMPLDIR/work ]; then
    mkdir $COMPLDIR/work
fi

for src in $COMPLSUITE/*.S ; do
    out=$COMPLDIR/work/`basename $src .S` ; echo $out
    "$RISCV_PREFIX"gcc \
        $RISCV_GCC_OPTS \
        -I $COMPLDIR/riscv-test-env \
        -I $COMPLDIR/riscv-test-env/p \
        -I $COMPLDIR/riscv-target/$RISCV_TARGET \
        -T $COMPLDIR/riscv-test-env/p/link.ld \
        $src -o $out.elf
    "$RISCV_PREFIX"objdump --disassemble-all $out.elf > $out.lst
    "$RISCV_PREFIX"objcopy -O binary $out.elf $out.bin
    echo "@00000000" > $out.mem
    /usr/bin/hexdump -v -e '"%08X\n"' $out.bin >> $out.mem
done
