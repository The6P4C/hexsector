; not important, see comment on `section .bss` line for reason
section .text
GRID_WIDTH equ 6
GRID_HEIGHT equ 5

_start:
	; correct data segment for load address of 0x7C00
	mov ax, 0x7C0
	mov ds, ax

	; initialize video mode
	mov ax, 0x000D
	int 0x10

	mov bl, 0b0000

	mov dx, 0
.draw_row:

	mov cx, 0
.draw_column:
	call draw_map_cell

	inc cx
	cmp cx, GRID_WIDTH
	jl .draw_column

	inc dx
	cmp dx, GRID_HEIGHT
	jl .draw_row

	mov word [cursor_x], 0
	mov word [cursor_y], 0

.input_loop:
	; draw current cursor
	mov ax, 0x0002
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
	cmp al, 'x'
	je .input_discover_count
	cmp al, 'X'
	je .input_discover_blue
	jmp .input_loop

.input_up:
	cmp word [cursor_y], 0
	je .done
	dec word [cursor_y]
	jmp .done
.input_down:
	cmp word [cursor_y], GRID_HEIGHT - 1
	je .done
	inc word [cursor_y]
	jmp .done
.input_left:
	cmp word [cursor_x], 0
	je .done
	dec word [cursor_x]
	jmp .done
.input_right:
	cmp word [cursor_x], GRID_WIDTH - 1
	je .done
	inc word [cursor_x]
	jmp .done
.input_discover_count:
	mov cx, word [cursor_x]
	mov dx, word [cursor_y]
	call get_map_cell
	and ah, 0b111
	cmp ah, 0x7
	jl .did_discover
	jmp .done
.input_discover_blue:
	mov cx, word [cursor_x]
	mov dx, word [cursor_y]
	call get_map_cell
	and ah, 0b111
	cmp ah, 0x7
	je .did_discover
	jmp .done
.did_discover:
	mov bl, 0b1000
	call draw_map_cell
	jmp .done

.done:
	jmp .input_loop

	jmp $

; cx - hex coord x
; dx - hex coord y
draw_map_cell:
	call get_map_cell
	cmp ah, CELL_EMPTY
	je .cell_empty
	or ah, bl
	test ah, 0b1000
	jz .cell_undiscovered
	and ah, 0b111
	cmp ah, CELL_BLUE
	je .cell_blue
	mov ah, 0x7
	jmp .draw

.cell_empty:
	mov ah, 0x0
	jmp .draw

.cell_undiscovered:
	mov ah, 0xC
	jmp .draw

.cell_blue:
	mov ah, 0xB
	jmp .draw

.draw:
	mov al, 0xF
	jmp draw_hex_at ; will ret for us

; cx - hex coord x
; dx - hex coord y
; returns: ah - map cell value
get_map_cell:
	push cx
	push di

	; convert x/y to map offset
	; ax - byte offset, cl - nibble offset
	mov ax, dx
	shl ax, 1
	add ax, dx
	shl ax, 1
	add ax, cx
	shr ax, 1
	setc cl
	shl cl, 2

	; retrieve byte from map
	mov di, map
	push ax
	mov ah, 0
	mov di, map
	add di, ax
	pop ax
	mov ah, [di]

	; retrieve nibble from byte
	shr ah, cl
	and ah, 0xF

	pop di
	pop cx
	ret

draw_hex_at_cursor:
	mov cx, word [cursor_x]
	mov dx, word [cursor_y]
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

	add cx, 20
	add dx, 20

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
	cmp di, hexagon + (HEXAGON_HEIGHT * 2)
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

%define X(a, b) (((b) << 4) | (a))
CELL_BLUE equ 0x7
CELL_EMPTY equ 0xF
CELL_DISCOVERED equ 0x8
map:
	db X(CELL_EMPTY, CELL_EMPTY), X(CELL_BLUE, CELL_EMPTY), X(CELL_EMPTY, CELL_EMPTY)
	db X(2 | CELL_DISCOVERED, CELL_BLUE), X(3, CELL_BLUE), X(2 | CELL_DISCOVERED, CELL_EMPTY)
	db X(CELL_BLUE, CELL_BLUE), X(5 | CELL_DISCOVERED, CELL_BLUE), X(CELL_BLUE, CELL_EMPTY)
	db X(2 | CELL_DISCOVERED, CELL_EMPTY), X(CELL_BLUE, CELL_EMPTY), X(2 | CELL_DISCOVERED, CELL_EMPTY)
	db X(CELL_EMPTY, CELL_EMPTY), X(1 | CELL_DISCOVERED, CELL_EMPTY), X(CELL_EMPTY, CELL_EMPTY)

times (512 - 2) - ($ - _start) db 0x00
db 0x55
db 0xAA

; not important, stops nasm putting the reserved space in the floppy image
section .bss
saved_cx: resw 1

cursor_x: resw 1
cursor_y: resw 1
