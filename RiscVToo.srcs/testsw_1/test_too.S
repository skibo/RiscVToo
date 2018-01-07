/*-
 * Copyright (c) 2018 Thomas Skibo.
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

/* test_too.S:  small test just to bring up riscv_too module. */
        
        .text
	. = 0x1c0
exception:
        j       _except
        
	. = 0x200
	.globl	_start
_start:
        
        /* Write and read an onboard memory location. */
        li      t1, 0x1234
        la      t2, foo2
        sw      t1, 0(t2)
        lw      t3, 0(t2)

        bne     t1, t3, fail

        /* Now write and read an AXI location. */
        li      t1, 0x54321
        li      t2, 0x4000
        sw      t1, 0(t2)
        lw      t3, 0(t2)

        bne     t1, t3, fail

        /* Write to ROM.  (Should cause exception.) */
wrom:
        sw      t1, 100(zero)

        la      t1, xnum
        li      t2, 0x2222
        lw      t3, 0(t1)
        bne     t2, t3, fail

        sw      zero, 0(t1)
        
        /* Read and write bad AXI location.  (Should cause exception.) */
        li      t1, 0xdead0
badwr1: 
        sw      t2, 0(t1)

        la      t1, xnum
        li      t2, 0x2222
        lw      t3, 0(t1)
        bne     t2, t3, fail
        
        sw      zero, 0(t1)
        
        li      t1, 0xdead0
badrd1: 
        lw      t2, 0(t1)

        la      t1, xnum
        li      t2, 0x2222
        lw      t3, 0(t1)
        bne     t2, t3, fail
        
        /* Success! */
success:
        li      t1, 2
        li      t2, 0xf0000
        sw      t1, 0(t2)
        
1:
        j       1b

/* Exception handler. */        
_except:        
	li	t1, 0x1111
	la      t2, xnum
	sw	t1, 0(t2)
        csrr    t1, mcause
        sw      t1, 4(t2)        
        csrr    t1, mepc
        sw      t1, 8(t2)

        /* Check if exception happened where we expected. */
        la      t3, wrom
        beq     t1, t3, 4f
        /* XXX: On failed reads and writes to AXI, mepc if off by 4.  Fix this
        * later. */
        addi    t1, t1, -4
        la      t3, badrd1
        beq     t1, t3, 4f
        la      t3, badwr1
        bne     t1, t3, fail
4:      
        /* Expected exception.  Return to instruction after failed one. */
        addi    t1, t1, 4
        csrw    mepc, t1
        li      t1, 0x2222
        sw      t1, 0(t2)
        mret
        
fail:
        li      t1, 0xf0000
        li      t2, 1
        sw      t2, 0(t1)
        
2:      
	j	2b

        .data
foo1:
        .word   9999

foo2:
        .word   0

xnum:
        .word   0
        .word   0
        .word   0
        
