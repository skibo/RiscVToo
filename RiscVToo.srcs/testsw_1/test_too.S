/*-
 * Copyright (c) 2018-2019 Thomas Skibo.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

/* test_too.S:	small test just to bring up riscv_too module. */

	.text
	. = 0x1c0
exception:
	j	_except

	. = 0x200
	.globl	_start
_start:
	/* Write and read an AXI location. */
	li	t1, 0x87654321
	li	t2, 0x4000
	sw	t1, 0(t2)
	lw	t3, 0(t2)
	bne	t1, t3, fail

	/* Test byte enables on AXI location. */
	li	t4, 0xffeeddcc
	sh	t4, 2(t2)
	lw	t3, 0(t2)
	li	t5, 0xddcc4321
	bne	t3, t5, fail
	sh	t4, 0(t2)
	lw	t3, 0(t2)
	li	t5, 0xddccddcc
	bne	t3, t5, fail
	sb	t1, 3(t2)
	lw	t3, 0(t2)
	li	t5, 0x21ccddcc
	bne	t3, t5, fail
	sb	t1, 2(t2)
	lw	t3, 0(t2)
	li	t5, 0x2121ddcc
	bne	t3, t5, fail
	sb	t1, 1(t2)
	lw	t3, 0(t2)
	li	t5, 0x212121cc
	bne	t3, t5, fail
	sb	t1, 0(t2)
	lw	t3, 0(t2)
	li	t5, 0x21212121
	bne	t3, t5, fail

	/* Write and read RAM.	Test byte enables.  RAM read results also
	 * sent to AXI location 0xe0000 just for observation.
	 */
	la	t1, foo2
	li	t2, 0x12345678
	li	t6, 0xe0000
	sw	t2, 0(t1)
	lw	t3, 0(t1)
	sw	t3, 0(t6)
	bne	t3, t2, fail

	/* Check byte enables on memory. */
	li	t3, 0xaabbccdd
	sh	t3, 2(t1)
	lw	t4, 0(t1)
	sw	t4, 0(t6)
	li	t5,0xccdd5678
	bne	t4, t5, fail
	sh	t3, 0(t1)
	lw	t4, 0(t1)
	sw	t4, 0(t6)
	li	t5, 0xccddccdd
	bne	t4, t5, fail
	sb	t2, 3(t1)
	lw	t4, 0(t1)
	sw	t4, 0(t6)
	li	t5, 0x78ddccdd
	bne	t4, t5, fail
	sb	t2, 2(t1)
	lw	t4, 0(t1)
	sw	t4, 0(t6)
	li	t5, 0x7878ccdd
	bne	t4, t5, fail
	sb	t2, 1(t1)
	lw	t4, 0(t1)
	sw	t4, 0(t6)
	li	t5, 0x787878dd
	bne	t4, t5, fail
	sb	t2, 0(t1)
	lw	t4, 0(t1)
	sw	t4, 0(t6)
	li	t5, 0x78787878
	bne	t4, t5, fail

	/* Write to ROM.  (Should cause exception.) */
wrom:
	sw	t1, 100(zero)

	la	t1, xnum
	li	t2, 0x2222
	lw	t3, 0(t1)
	bne	t2, t3, fail

	sw	zero, 0(t1)

	/* Read and write bad AXI location.  (Should cause exception.) */
	li	t1, 0xdead0
badwr1:
	sw	t2, 0(t1)

	la	t1, xnum
	li	t2, 0x2222
	lw	t3, 0(t1)
	bne	t2, t3, fail

	sw	zero, 0(t1)

	li	t1, 0xdead0
badrd1:
	lw	t2, 0(t1)

	la	t1, xnum
	li	t2, 0x2222
	lw	t3, 0(t1)
	bne	t2, t3, fail

	/* Read mtime and mtimeh registers. */
	li	t1, 0x20000
	li	t2, 0x30000
	lw	t3, 8(t1)
	sw	t3, 8(t2)
	lw	t3, 12(t1)
	sw	t3, 12(t2)
	lw	t3, 0(t1)
	sw	t3, 0(t2)
	lw	t4, 4(t1)
	sw	t4, 4(t2)

	/* Set timecmp register. */
	addi	t3, t3, 64
	sw	t3, 8(t1)
	sw	t4, 12(t1)

	/* Enable interrupt. (MTIE in mie and then MIE in mstatus.) */
	li	t0, 1 << 7
	csrs	mie, t0
	csrsi	mstatus, 8

	/* Wait for interrupt. */
timo:
	j	timo

	/* Clear interrupt bits. */
	li	t0, 1 << 7
	csrc	mie, t0
	csrci	mstatus, 8

	/* Success! */
success:
	li	t1, 2
	li	t2, 0xf0000
	sw	t1, 0(t2)

1:
	j	1b

/* Exception handler.  NOTE: clobbers t1,t2, and t3. */
_except:
	li	t1, 0x1111
	la	t2, xnum
	sw	t1, 0(t2)
	csrr	t1, mcause
	sw	t1, 4(t2)
	csrr	t1, mepc
	sw	t1, 8(t2)

	/* Check if exception happened where we expected. */
	la	t3, wrom
	beq	t1, t3, 4f
	la	t3, timo
	bne	t1, t3, 3f

	/* timer int.  clear by writing timecmp. */
	li	t3, 0x20000
	sw	zero, 8(t3)
	j	4f
3:
	la	t3, badrd1
	beq	t1, t3, 4f
	la	t3, badwr1
	bne	t1, t3, fail
4:
	/* Expected exception.	Return to instruction after failed one. */
	addi	t1, t1, 4
	csrw	mepc, t1
	li	t1, 0x2222
	sw	t1, 0(t2)
	mret

fail:
	li	t1, 0xf0000
	li	t2, 1
	sw	t2, 0(t1)

2:
	j	2b

	.data
foo1:
	.word	9999

foo2:
	.word	0

xnum:
	.word	0
	.word	0
	.word	0
