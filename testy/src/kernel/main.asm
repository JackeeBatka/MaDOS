org 0x7C00
bits 16

%define ENDL 0x0D, 0x0A


start:
	jmp main

;
; Prints a string to da screen
; params:
;	- ds:si points to string
;


puts:
	; save regs we will modify
	push si
	push ax


.loop:
	lodsb		; loads next cahr in al
	or al, al	; verif if next char is null
	jz .done

	mov ah, 0x0e
	int 0x10
	jmp .loop

.done:
	pop ax
	pop si
	ret


main:
	; set up data segments
	mov ax, 0		;can't write to de/es directly
	mov ds, ax
	mov es, ax

	; setup stack
	mov ss, ax
	mov sp, 0x7C00 ; stack grows downwards from where we are loaded in mem
	

	mov si, msg_hello
	call puts

	hlt

.halt:
	jmp .halt


msg_hello: db 'Hello world!', 0


times 510-($-$$) db 0
dw 0AA55h
