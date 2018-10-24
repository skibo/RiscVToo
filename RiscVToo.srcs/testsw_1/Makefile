
ifndef RISCV
$(error RISCV must be set to point to RiscV toolchain)
endif

CROSS_COMPILE=$(RISCV)/bin/riscv64-unknown-linux-gnu-
BIN2HEX=/usr/bin/hexdump -v -e '/4 "%08X\n"'

TESTS=test_too test1 test2 test3 testcsr

TARGETS=$(TESTS:=.lst) $(TESTS:=.mem)
OBJS=$(TESTS:=.o)
BINS=$(TESTS:=.bin)
ELFS=$(TESTS:=.elf)

AFLAGS=-march=rv32i
LFLAGS=-melf32lriscv -static -T ldscript.riscv

default: $(TARGETS)

%.o: %.S
	$(CROSS_COMPILE)as $(AFLAGS) -o $@ $<

%.elf: %.o
	$(CROSS_COMPILE)ld $(LFLAGS) -o $@ $<

%.bin: %.elf
	$(CROSS_COMPILE)objcopy -O binary $< $@

%.lst: %.elf
	$(CROSS_COMPILE)objdump --disassemble-all $< > $@

%.mem: %.bin
	$(BIN2HEX) $< > $@

clean:
	rm -f $(TARGETS) $(OBJS) $(BINS) $(ELFS)

