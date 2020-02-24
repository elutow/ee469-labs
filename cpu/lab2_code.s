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
	mov r4, r5
	mov r4, r5, LSL #2	@ test logical shift left
	mov r4, r5, LSR #2	@ test logical shift right
	mov r4, r5, ASR #2	@ test arithmetic shift right
	mov r4, r5, ROR #2	@ test rotate right
	mvn r4, r5
	add r4, r6, r7
	add r4, r6, #2	@ test use of immediate
	add r4, r6, #261120	@test use of rotated immediate
	sub r4, r5, r6
	cmp r4, r5
	tst r4, r5
	teq r4, r5
	eor r4, r5, r6
	bic r4, r5, r6
	orr r4, r5, r6
	ldr r4, [r8]		@ pull data from memory in [r8]
	str r5, [r8]		@ store value of r5 into [r8]
	ldr r4, [r8]		@ check that [r8] held the value of r5 from previous instruction
	ldr r4, [r8, #2]	@ test immediate offset
	ldr r4, [r8, +r9, LSL #2]	@ test register shift offset

	bl start
	mov pc, lr
