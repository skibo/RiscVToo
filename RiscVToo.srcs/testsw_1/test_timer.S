/*-
 * Copyright (c) 2019 Thomas Skibo.
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

/* test_timer.S:  test timer interrupts. */
	.text
	. = 0x1c0
exception:
	j	_except

	. = 0x200
	.global _start
_start:
	/* Set timecmp and enable interrupt. */
	li	t0, 0x300
	li	t1, 0x20000
	sw	zero, 12(t1)
	sw	t0, 8(t1)

	/* Enable interrupt. */
	li	t0, 1 << 7
	csrs	mie, t0
	csrsi	mstatus, 8

	/* Do loads of AXI. */
	li	t1, 0x4000
	li	t2, 0xabcd
	sw	t2, 0(t1)
1:
	lw	t0, 0(t1)
	nop
	nop
	beq	t0, t2, 1b

	/* Huh?	 Read value corrupted. */
fail:
	li	s0, 1
	li	s1, 0xf0000
	sw	s0, 0(s1)
1:
	j	1b

pass:
	li	s0, 2
	li	s1, 0xf0000
	sw	s0, 0(s1)
1:
	j	1b

_except:
	/* Save regs. */
	csrw	mscratch, t0
	la	t0, rsave
	sw	t1, 4(t0)
	sw	t2, 8(t0)
	sw	t3, 12(t0)
	csrr	t1, mscratch
	sw	t1, 0(t0)

	csrr	t0, mcause
	bge	t0, zero, notint

	/* Check reason. */
	and	t0, t0, 15
	li	t1, 7
	bne	t0, t1, fail

	/* Check mtip. */
	csrr	t0, mip
	andi	t0, t0, 1 << 7
	beq	t0, zero, fail

	/* New timer value.  Stop test timer >= 0x4000 */
	li	t0, 0x20000
1:
	lw	t1, 0(t0)
	srli	t2, t1, 14
	bne	t2, zero, pass
	addi	t1, t1, 127
	sw	t1, 8(t0)

	/* Restore regs. */
	la	t0, rsave
	lw	t1, 4(t0)
	lw	t2, 8(t0)
	lw	t3, 12(t0)
	lw	t0, 0(t0)
	mret

notint:
	csrr	t0, mstatus
	csrr	t1, mepc
	j	fail

	.data
rsave:
	.word	0
	.word	0
	.word	0
	.word	0
