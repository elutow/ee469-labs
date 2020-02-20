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
	mvn r4, r5
	add r4, r5, r6
	sub r4, r5, r6
	cmp r4, r5
	tst r4, r5
	teq r4, r5
	eor r4, r5, r6
	bic r4, r5, r6
	orr r4, r5, r6
	ldr r4, [r5]
	b start
