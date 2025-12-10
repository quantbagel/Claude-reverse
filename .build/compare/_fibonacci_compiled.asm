stp	x20, x19, [sp, #-0x20]!
stp	x29, x30, [sp, #0x10]
add	x29, sp, #0x10
cmp	w0, #0x2
b.ge	0x1c <ltmp0+0x1c>
mov	w19, #0x0               ; =0
b	0x44 <ltmp0+0x44>
mov	w19, #0x0               ; =0
mov	x20, x0
sub	w0, w20, #0x1
bl	0x0 <ltmp0>
mov	x8, x0
sub	w0, w20, #0x2
add	w19, w8, w19
cmp	w20, #0x3
mov	x20, x0
b.hi	0x24 <ltmp0+0x24>
add	w0, w0, w19
ldp	x29, x30, [sp, #0x10]
ldp	x20, x19, [sp], #0x20
ret
