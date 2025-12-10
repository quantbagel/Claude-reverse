]!
stp x29, x30, [var_10h]
cmp w0, 2
mov w19, 0
mov w19, 0
mov x20, x0
sub w0, w20, 1
bl sym._fibonacci
mov x8, x0
sub w0, w20, 2
add w19, w8, w19
cmp w20, 3
mov x20, x0
add w0, w0, w19
ldp x29, x30, [var_10h]
ret
