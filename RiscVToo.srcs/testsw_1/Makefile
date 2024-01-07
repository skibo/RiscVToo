
ifdef RISCV
CROSS_COMPILE=$(RISCV)/bin/riscv64-unknown-elf-
else
CROSS_COMPILE=riscv64-unknown-elf-
endif

LD=$(CROSS_COMPILE)ld
AS=$(CROSS_COMPILE)as
BIN2HEX=/usr/bin/hexdump -v -e '/4 "%08X\n"'

TESTS=test1 test2 test3 testcsr test_too test_timer

OBJS=$(TESTS:=.o)
BINS=$(TESTS:=.bin)
ELFS=$(TESTS:=.elf)

AFLAGS=-march=rv32i_zicsr
LFLAGS=-melf32lriscv -static -T ldscript.riscv

TARGETS=$(TESTS:=.lst) $(TESTS:=.mem)

default: $(TARGETS)

%.o: %.S
	$(AS) $(AFLAGS) -o $@ $<

%.elf: %.o
	$(LD) $(LFLAGS) -o $@ $<

%.bin: %.elf
	$(CROSS_COMPILE)objcopy -O binary $< $@

%.lst: %.elf
	$(CROSS_COMPILE)objdump --disassemble-all $< > $@

%.mem: %.bin
	$(BIN2HEX) $< > $@

clean:
	rm -f $(TARGETS) $(OBJS) $(BINS) $(ELFS)

