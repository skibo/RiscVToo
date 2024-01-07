	/* Mostly test interrupts and exceptions. */

	.text
	. = 0x1c0
exception:
	j	exception2

	. = 0x200
	.global _start
_start:
	li	a0, 0x88888888
	sw	a0, 0(zero)

	li	a0, 100
	sw	a0, 0(a0)
1:
	nop
	nop
	nop

	lw	a1, 0(a0)
	lw	a2, 0(a1)
	lw	a3, 0(a2)

	sw	a3, 4(zero)

	/* Enable interrupts. (Set MIE in MSTATUS and MEIE in MIE. */
	csrrs	a1, mstatus, 8
	sw	a1, 4(zero)
	li	a1, 0x800
	csrrs	a1, mie, a1
	sw	a1, 4(zero)

	lw	a2, 0(zero)
	csrrw	a0, mscratch, a2
	sw	a2, 8(zero)
	csrrw	a2, mscratch, a2
	sw	a2, 12(zero)

	/* Write magic location to set external IRQ. */
	li	a0, 0xf00
	li	a1, 999
	sw	a1, 0(a0)

	wfi
intr_foo:
	la	a1, intr_foo
	sw	a1, 0(zero)
	sw	a6, 4(zero)
	bne	a6, a1, fail

	li	a0, 0x55555555
	sw	a0, 16(zero)

	li	a0, 0x99999999

	/* D-fault */
d_fault:
	sb	a0, 0(a0)

	li	a1, 7
	bne	a4, a1, fail
	la	a1, d_fault
	bne	a6, a1, fail
	bne	a7, a0, fail

	/* Store alignment */
alg_st:
	sw	a0, 1(zero)

	li	a1, 6
	bne	a4, a1, fail
	la	a1, alg_st
	bne	a6, a1, fail
	li	a1, 1
	bne	a7, a1, fail

alg_ld:
	/* Load alignment */
	lw	a1, 1(zero)

	li	a1, 4
	bne	a4, a1, fail
	la	a1, alg_ld
	bne	a6, a1, fail
	li	a1, 1
	bne	a7, a1, fail

alg_jmp:
	/* Unaligned branch or jump */
	j	alg_jmp - 2

	bne	a4, zero, fail
	la	a1, alg_jmp
	bne	a6, a1, fail

	la	a4, alg_jmp
	addi	a4, a4, 2
alg_jmp2:
	jr	a4

	bne	a4, zero, fail
	la	a1, alg_jmp2
	bne	a6, a1, fail

	li	a6, 0
	bne	zero, zero, 1f + 2	/* should not trap */
1:
	bne	a6, zero, fail
alg_jmp3:
	beq	zero, zero, 1b + 2	/* should trap */
	bne	a4, zero, fail
	la	a1, alg_jmp3
	bne	a6, a1, fail

	/* ecall */
ecall:
	ecall

	li	a1, 11
	bne	a4, a1, fail
	la	a1, ecall
	bne	a6, a1, fail

	/* ebreak */
ebrk:
	ebreak

	li	a1, 3
	bne	a4, a1, fail
	la	a1, ebrk
	bne	a6, a1, fail

	/* Illegal instruction. */
illi:
	/* mul	   a1, a1, a1 */
	.word	0x02b585b3

	li	a1, 2
	bne	a4, a1, fail
	la	a1, illi
	bne	a6, a1, fail
	li	a1, 0x02b585b3
	bne	a7, a1, fail

	/* Check I-fault. */
	li	a0, 0x9999999c
	jr	a0
i_fault_ret:
	li	a1, 1
	bne	a4, a1, fail
	bne	a6, a0, fail

	sw	a0, 20(zero)
done:
	/* Success (of some sorts) */
	li	a0, 0xf00
	li	a1, 2
	sw	a1, 0(a0)
1:
	j	1b

fail:
	li	a0, 0xf00
	li	a1, 1
	sw	a1, 0(a0)
1:
	j	1b

exception2:
	csrr	a4, mcause
	sw	a4, 32(zero)
	csrr	a5, mstatus
	sw	a5, 36(zero)
	csrr	a6, mepc
	sw	a6, 40(zero)
	blt	a4, zero, 1f

	/* For non-interrupts, return to mepc+4 to pass offending instr. */
	addi	a7, a6, 4
	csrw	mepc, a7

	/* I-fault? */
	li	a7, 1
	bne	a4, a7, 1f

	la	a7, i_fault_ret
	csrw	mepc, a7
1:
	li	a7, 128
	csrc	mie, a7
	csrr	a7, mbadaddr
	sw	a7, 44(zero)
	mret
	nop
	nop
	nop
