@ armv2 assembly for GCC
.arch armv2 @ same as -march
.cpu arm2 @ same as -mcpu
@ Switch to the text section (where the linker stores our code)
.text
@ Assemble in ARM mode
.arm
@ Specify ARM unified syntax (https://sourceware.org/binutils/docs/as/ARM_002dInstruction_002dSet.html#ARM_002dInstruction_002dSet)
.syntax unified

start:
	@ Test basic data hazards with r1
	add r1, r2, r3
	sub r4, r1, r1
	add r5, r1, #1
	orr r6, r1, r1
	bic r7, r1, #0

	@ Clear pipeline (to make things easier to read)
	nop
	nop
	nop
	nop

	@ Test stall after LDR
	ldr r1, [r2]
	sub r4, r1, r1
	add r5, r1, #1
	orr r6, r1, r1
	bic r7, r1, #0

	@ Clear pipeline
	nop
	nop
	nop
	nop

	@ Test BL, ensuring pipeline flushes correctly
	bl branch_test

	@ Test conditional execution
	cmp r4, r5
	addne r1, r2, r3
	subeq r4, r1, r1
	addlt r5, r1, #1
	orrgt r6, r1, r1
	bicmi r7, r1, #0

	@ Set non-zero data into address of r8 (used for code below)
	str r1, [r8]

	@ Clear pipeline
	nop
	nop
	nop
	nop

	@ Loop to start using LDR
	@ We know that the first instruction is at address 0 in our CPU
	mov r10, #0
	str r10, [r8]
	ldr pc, [r8]
	@ These should not run
	add r1, r2, r3
	sub r4, r1, r1
	add r5, r1, #1
	orr r6, r1, r1
	bic r7, r1, #0

branch_test:
	mov pc, lr
	@ These should not run
	add r1, r2, r3
	sub r4, r1, r1
	add r5, r1, #1
	orr r6, r1, r1
	bic r7, r1, #0
