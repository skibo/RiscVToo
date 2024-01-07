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

	/* Check endianness, byte and half loads and stores. */
	.text
	. = 0x1c0
exception:
	/* Ooops! */
	li	a0, 0xf00
	li	t0, 1111
	sw	t0, 0(a0)
1:
	j	1b
	nop

	. = 0x200
	.global _start
_start:
	li	t0, 0x88888888
	li	t1, 0x1234
	li	a0, 8
	li	a1, 0x0000	/* base address. */

	sw	t0, 16(a1)	/* Store 0x88888888 to 0x10. */

	/* Test byte stores. */
	sb	t1, 16(a1)
	lw	t2, 16(a1)
	li	t3, 0x88888834
	bne	t3, t2, fail

	sb	t1, 17(a1)
	lw	t2, 16(a1)
	li	t3, 0x88883434
	bne	t3, t2, fail

	sb	t1, 18(a1)
	lw	t2, 16(a1)
	li	t3, 0x88343434
	bne	t3, t2, fail

	sb	t1, 19(a1)
	lw	t2, 16(a1)
	li	t3, 0x34343434
	bne	t3, t2, fail

	/* Test half stores. */
	li	t1, 0x55667788
	sh	t1, 16(a1)
	lw	t2, 16(a1)
	li	t3, 0x34347788
	bne	t3, t2, fail

	sh	t1, 18(a1)
	lw	t2, 16(a1)
	li	t3, 0x77887788
	bne	t2, t3, fail

	/* Test byte loads, signed and unsigned. */
	li	t1, 0x8899aabb
	sw	t1, 16(a1)

	lb	t2, 16(a1)
	li	t3, 0xffffffbb
	bne	t2, t3, fail

	lbu	t2, 16(a1)
	li	t3, 0xbb
	bne	t2, t3, fail

	lb	t2, 17(a1)
	li	t3, 0xffffffaa
	bne	t2, t3, fail

	lbu	t2, 17(a1)
	li	t3, 0xaa
	bne	t2, t3, fail

	lb	t2, 18(a1)
	li	t3, 0xffffff99
	bne	t2, t3, fail

	lbu	t2, 18(a1)
	li	t3, 0x99
	bne	t2, t3, fail

	lb	t2, 19(a1)
	li	t3, 0xffffff88
	bne	t2, t3, fail

	lbu	t2, 19(a1)
	li	t3, 0x88
	bne	t2, t3, fail

	/* Test half loads, signed and unsigned. */
	lh	t2, 16(a1)
	li	t3, 0xffffaabb
	bne	t2, t3, fail

	lhu	t2, 16(a1)
	li	t3, 0xaabb
	bne	t2, t3, fail

	lh	t2, 18(a1)
	li	t3, 0xffff8899
	bne	t2, t3, fail

	lhu	t2, 18(a1)
	li	t3, 0x8899
	bne	t2, t3, fail

	/* Pass! */
	li	a0, 0xf00
	li	t0, 2
	sw	t0, 0(a0)
1:
	j	1b

fail:
	/* Fail! */
	li	a0, 0xf00
	li	t0, 1
	sw	t0, 0(a0)
1:
	j	1b
	nop
