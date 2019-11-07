; not important, see comment on `section .bss` line for reason
section .text
GRID_WIDTH equ 40
GRID_HEIGHT equ 15

_start:
	; correct data segment for load address of 0x7C00
	mov ax, 0x7C0
	mov ds, ax

	; initialize video mode
	mov ax, 0x000D
	int 0x10

	mov ax, 0x000F

	mov dx, 0
.draw_row:

	mov cx, 0
.draw_column:
	call draw_hex_at

	inc cx
	cmp cx, GRID_WIDTH
	jl .draw_column

	inc dx
	cmp dx, GRID_HEIGHT
	jl .draw_row

	mov byte [cursor_x], 0x00
	mov byte [cursor_y], 0x00

.input_loop:
	; draw current cursor
	mov ax, 0x000C
	call draw_hex_at_cursor

	int 0x16
	push ax

	; clear previous cursor position
	mov ax, 0x000F
	call draw_hex_at_cursor

	pop ax

	cmp al, 'w'
	je .input_up
	cmp al, 's'
	je .input_down
	cmp al, 'a'
	je .input_left
	cmp al, 'd'
	je .input_right
	jmp .input_loop

.input_up:
	cmp byte [cursor_y], 0
	je .done
	dec byte [cursor_y]
	jmp .done
.input_down:
	cmp byte [cursor_y], GRID_HEIGHT - 1
	je .done
	inc byte [cursor_y]
	jmp .done
.input_left:
	cmp byte [cursor_x], 0
	je .done
	dec byte [cursor_x]
	jmp .done
.input_right:
	cmp byte [cursor_x], GRID_WIDTH - 1
	je .done
	inc byte [cursor_x]
	jmp .done

.done:
	jmp .input_loop

	jmp $

draw_hex_at_cursor:
	xor cx, cx
	xor dx, dx
	mov cl, byte [cursor_x]
	mov dl, byte [cursor_y]
	; fall through to draw_hex_at

; cx - hex coord x
; dx - hex coord y
; al - color
draw_hex_at:
	push cx
	push dx
	push ax

	; multiply x coord by 7
	mov ax, cx
	shl cx, 1
	add ax, cx
	shl cx, 1
	add ax, cx
	mov cx, ax

	; multiply y coord by 10
	shl dx, 1
	mov ax, dx
	shl ax, 2
	add ax, dx
	mov dx, ax

	test cx, 1
	jz .draw
	add dx, 5

.draw:
	pop ax
	call draw_hex

	pop dx
	pop cx
	ret

; cx - top left x
; dx - top left y
; al - outer color, ah - inner color (ah = 0x00 means don't change)
draw_hex:
	pusha

	mov word [saved_cx], cx
	mov di, hexagon

.draw_lines:
	mov bx, word [di]
	mov si, 0

.draw_line:
	push ax
	test bx, 1
	jnz .do_draw
	test si, si
	jz .dont_draw
	cmp ah, 0x00
	je .dont_draw
	mov al, ah

.do_draw:
	mov si, 1
	push bx
	mov ah, 0x0C ; write graphics pixel
	mov bh, 0 ; page number
	int 0x10
	pop bx

.dont_draw:
	pop ax
	inc cx

	shr bx, 1
	test bx, bx ; are there still pixels in the line?
	jnz .draw_line

	mov cx, word [saved_cx]
	inc dx

	add di, 2
	cmp di, hexagon + ((HEXAGON_HEIGHT + 1) * 2)
	jne .draw_lines

	popa
	ret

HEXAGON_HEIGHT equ 10
hexagon:
	dw 0b00011111000
	dw 0b00110001100
	dw 0b01100000110
	dw 0b11000000011
	dw 0b10000000001
	dw 0b10000000001
	dw 0b11000000011
	dw 0b01100000110
	dw 0b00110001100
	dw 0b00011111000

times (512 - 2) - ($ - _start) db 0x00
db 0x55
db 0xAA

; not important, stops nasm putting the reserved space in the floppy image
section .bss
saved_cx: resw 1

cursor_x: resb 1
cursor_y: resb 1
