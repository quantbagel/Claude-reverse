	.section	__TEXT,__text,regular,pure_instructions
	.build_version macos, 15, 0	sdk_version 26, 1
	.globl	__add_numbers                   ; -- Begin function _add_numbers
	.p2align	2
__add_numbers:                          ; @_add_numbers
	.cfi_startproc
; %bb.0:
	add	w0, w1, w0
	ret
	.cfi_endproc
                                        ; -- End function
.subsections_via_symbols
