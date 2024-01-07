/*-
 * Copyright (c) 2016 Thomas Skibo.
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

	.text
	. = 0x1c0
exception:
	csrr	t0, mepc
	sw	t0, 48(zero)
	addi	t0, t0, 4
	csrrw	t0, mepc, t0
	csrr	t0, mstatus
	sw	t0, 52(zero)
	nop
	mret

1:
	j	1b

	. = 0x200

	.global _start
_start:
	li	a1, 0xdeadbeef
	li	a2, 0xbeefbabe

	/* See ISA, Vendor ID, Architecture ID, Implemention ID. */
	csrr	s0, misa
	sw	s0, 0(zero)
	csrr	s0, mvendorid
	sw	s0, 4(zero)
	csrr	s0, marchid
	sw	s0, 8(zero)
	csrr	s0, mimpid
	sw	s0, 12(zero)

	/* Write to mscratch. */
	csrrw	s0, mscratch, a1
	nop
	nop
	nop

	/* No bypass */
	csrrw	s0, mscratch, a2
	nop
	nop
	sw	s0, 8(zero)

	lw	s3, 8(zero)
	bne	s3, a1, fail

	/* Bypass M-->D */
	csrrw	s1, mscratch, a1
	nop
	sw	s1, 12(zero)

	lw	s3, 12(zero)
	bne	s3, a2, fail

	/* Load bubble */
	csrrw	s2, mscratch, a2
	sw	s2, 16(zero)

	lw	s3, 16(zero)
	bne	s3, a1, fail

	/* Swap with scratch. */
	csrrw	s3, mscratch, a1
	sw	s3, 20(zero)
	sw	s3, 20(zero)
	bne	s3, a2, fail

	csrrw	s2, mscratch, s3
	nop
	sw	s2, 24(zero)
	bne	s2, a1, fail

	csrrw	s2, mscratch, s2
	sw	s2, 28(zero)
	bne	s2, s3, fail

	/* Swap quickly. */
	csrrw	s2, mscratch, a2
	csrrw	s3, mscratch, s2
	csrrw	s2, mscratch, a1
	csrr	s4, mscratch

	bne	s3, a2, fail
	bne	s2, a1, fail
	bne	s4, a1, fail

	/* Clear some bits in scratch. */
	csrrc	s2, mscratch, 0xf
	sw	s2, 32(zero)
	csrrs	s2, mscratch, 0x1a
	sw	s2, 36(zero)
	csrrc	s2, mscratch, 0
	sw	s2, 40(zero)
	csrrw	s2, mscratch, s2
	sw	s2, 44(zero)

	/* Check mtvec register. */
	li	a0, -1
	csrrw	a1, mtvec, a0
	li	a2, 0x1c0
	bne	a1, a2, fail
	li	a0, 0x20000000
	csrrw	a1, mtvec, a0
	li	a2, 0xfffffffc
	bne	a1, a2, fail
	li	a2, 0x1c0
	csrrw	a1, mtvec, a2
	bne	a1, a0, fail

	/* Unaligned load. */
	lw	t0, 1(zero)
	nop
	nop

	/* Unaligned store. */
	sw	t0, 1(zero)
	nop

	/* ecall */
	ecall
	nop
	ebreak
	nop

	li	s0, 2
	li	s1, 0xf00
	sw	s0, 0(s1)
1:
	j	1b

fail:
	li	s0, 1
	li	s1, 0xf00
	sw	s0, 0(s1)

	j	1b
	nop
