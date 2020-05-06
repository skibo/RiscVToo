
# Point $RISCV at your local copy of GNU embedded toolchain.
ifdef RISCV
CROSS_COMPILE=$(RISCV)/bin/riscv64-unknown-elf-
else
CROSS_COMPILE=riscv64-unknown-elf-
endif

AFLAGS=-march=rv32i
LFLAGS=-melf32lriscv -static -T ldscript.riscv

BIN2HEX=/usr/bin/hexdump -v -e '/4 "%08X\n"'

TESTS=test1 test2 test3 testcsr test_too test_timer

TARGETS=$(TESTS:=.lst) $(TESTS:=.mem)
OBJS=$(TESTS:=.o)
BINS=$(TESTS:=.bin)
ELFS=$(TESTS:=.elf)

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

