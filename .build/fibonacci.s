	.section	__TEXT,__text,regular,pure_instructions
	.build_version macos, 15, 0	sdk_version 26, 1
	.globl	__fibonacci                     ; -- Begin function _fibonacci
	.p2align	2
__fibonacci:                            ; @_fibonacci
	.cfi_startproc
; %bb.0:
	stp	x20, x19, [sp, #-32]!           ; 16-byte Folded Spill
	stp	x29, x30, [sp, #16]             ; 16-byte Folded Spill
	add	x29, sp, #16
	.cfi_def_cfa w29, 16
	.cfi_offset w30, -8
	.cfi_offset w29, -16
	.cfi_offset w19, -24
	.cfi_offset w20, -32
	cmp	w0, #2
	b.ge	LBB0_2
; %bb.1:
	mov	w19, #0                         ; =0x0
	b	LBB0_4
LBB0_2:
	mov	w19, #0                         ; =0x0
	mov	x20, x0
LBB0_3:                                 ; =>This Inner Loop Header: Depth=1
	sub	w0, w20, #1
	bl	__fibonacci
	mov	x8, x0
	sub	w0, w20, #2
	add	w19, w8, w19
	cmp	w20, #3
	mov	x20, x0
	b.hi	LBB0_3
LBB0_4:
	add	w0, w0, w19
	ldp	x29, x30, [sp, #16]             ; 16-byte Folded Reload
	ldp	x20, x19, [sp], #32             ; 16-byte Folded Reload
	ret
	.cfi_endproc
                                        ; -- End function
.subsections_via_symbols
