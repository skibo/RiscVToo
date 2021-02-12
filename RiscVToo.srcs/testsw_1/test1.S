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

	/* Miscellaneous tests thrown together.	 Writing anything other than
	 * 0 or 2 to 0xf00 causes test failure.	 Writing 2 to 0xf00 passes
	 * test and writing 0 has no effect.
	 */
	.text
	. = 0x1c0
exception:
	li	x1, 1111
	li	x2, 0xf00
	sw	x1, 0(x2)
1:
	j	1b

	. = 0x200
	.globl	_start
_start:
	li	x1, 0x88888888
	li	x2, 0x77777777
	li	x3, 0x11111111
	li	x4, 0x30
	li	x6, 0xf00

	/* Bypass 32 */
	move	x5, x2
	add	x5, x5, x3
	sw	x5, 0(x0)

	nop
	nop
	beq	x5, x1, 1f
	nop
	li	x7, 3
	sw	x7, 0(x6)

1:
	/* Bypass 42 */
	move	x5, x1
	nop
	sub	x5, x5, x3
	sw	x5, 4(x0)

	nop
	nop
	nop
	beq	x5, x2, 1f
	nop

	li	x7, 5
	sw	x7, 0(x6)
1:
	/* No bypass. */
	move	x5, x2
	nop
	nop
	add	x5, x5, x3
	sw	x5, 8(x0)

	nop
	nop
	beq	x5, x1, 1f
	nop
	li	x7, 7
	sw	x7, 0(x6)
1:
	/* No bypass. */
	move	x5, x1
	nop
	nop
	nop
	sub	x5, x5, x3
	sw	x5, 12(x0)

	/* Other stores. */
	sh	x5, 18(x0)
	sb	x5, 21(x0)
	sb	x5, 22(x0)

	sw	x1, 0(x4)

	/* Load stall. */
	lw	x5, 0(x4)
	addi	x5, x5, 1
	sw	x5, 0(x4)

	addi	x7, x1, 1
	beq	x7, x5, 1f

	li	x7, 7
	sw	x7, 0(x6)
1:
	/* No load stall, but bypass 42 */
	lw	x5, 0(x4)
	nop
	addi	x5, x5, 1
	sw	x5, 0(x4)

	addi	x7, x7, 1
	nop
	nop
	beq	x7, x5, 1f

	li	x7, 9
	sw	x7, 0(x6)
1:
	/* Set up pointer for next test. */
	sw	x4, 16(x0)
	nop
	nop

	/* Back to back load stalls. */
	lw	x7, 16(x0)
	lw	x8, 0(x7)
	beq	x8, x5, 1f

	nop
	nop
	nop
	li	x7, 11
	sw	x7, 0(x6)
1:
	/* Test some ALU stuff. */
	slti	x5, x1, -500
	xori	x5, x5, 1
	sw	x5, 0(x6)

	sltiu	x5, x1, 500
	sw	x5, 0(x6)

	slt	x5, x1, x1
	sw	x5, 0(x6)

	slt	x5, x1, x2
	xori	x5, x5, 1
	sw	x5, 0(x6)

	slt	x5, x2, x1
	sw	x5, 0(x6)

	sltu	x5, x1, x2
	sw	x5, 0(x6)

	sltu	x5, x2, x1
	xori	x5, x5, 1
	sw	x5, 0(x6)

	slt	x5, x3, x2
	xori	x5, x5, 1
	sw	x5, 0(x6)

	li	x5, 0
	sw	x5, 0(x6)

	/* Test jal. */
	li	x5, 0
	jal	x3, 2f
	addi	x5, x5, 1
2:
	sw	x5, 0(x6)
	sw	x3, 0(x0)

	/* Test jalr. */
	la	x4, 1f
	jalr	x3, x4
	addi	x5, x5, 1
1:
	sw	x5, 0(x6)
	sw	x3, 0(x0)

	/* Test conditional br. */
	beq	x0, x0, 3f
	addi	x5, x5, 1
3:
	sw	x5, 0(x6)

	/* Prevent writes to x0. */
	li	x0, 1
	sw	x0, 0(x6)

	/* Finish. */
	li	x5, 2
	sw	x5, 0(x6)
1:
	j	1b

	nop
	nop
