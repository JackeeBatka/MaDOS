org 0x7C00
bits 16

%define ENDL 0x0D, 0x0A


;
; FAT12 header
;
jmp short start
nop

bdb_oem: 					db 'MSWIN4.1', 			; 8bytes
bdb_bytes_per_sector: 		dw 512					
bdb_sectors_per_cluster: 	db 1					 
bdb_reserved_sectors: 		dw 1					
bdb_fat_count:				db 2
bdb_dir_entries_count: 		dw 0E0h
bdb_total_sectors:			dw 2880					; 2880 *512 = 1.44MB
bdb_media_descriptor_type:	db 0F0h					; 3.5 in floppy
bdb_sectors_per_fat:		dw 9					; 9 sectors/fat
bdb_sectors_per_track:		dw 18					
bdb_heads:					dw 2
bdb_hidden_sectors:			dd 0
bdb_large_sector_count:		dd 0

;extended boot record
ebr_drive_number:			db 0					; 0x00 floppy, 0x80 hdd, ...
							db 0 					;reserved
ebr_signature:				db 29h
ebr_volume_id:				db 12h, 34h, 56h, 78h
ebr_volume_label:			db 'Jinixuv DOS'		; 11 bytes, padded with spaces
ebr_system_id:				db 'FAT12   '			; 8 bytes








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
	push bx


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
	
	; read from the floppy
	; BIOS should set DL to drive num
	mov [ebr_drive_number], dl

	mov ax, 1
	mov cl, 1
	mov bx, 0x7E00
	call disk_read

	;print hello world
	mov si, msg_hello
	call puts
	cli 
	hlt


;
; Error handlers
;

floppy_error:
	mov si, msg_read_failed
	call puts
	jmp wait_key_and_reboot
	
wait_key_and_reboot:
	mov ah, 0
	int 16h								; wait for keypress
	jmp 0FFFFh:0						; jump to beginning of BIOS, should reboot

.halt:
	cli 								; disabe interrupts, so the CPU cant get out of "halt" state
	hlt


;
; Disk routines
;

;
; Converts LBA add to CHS add
; Params:
;	- ax: LBA addr
; Returns
;	- cx [bits 0-5]: sec num
;	- cx [bits 6-15]: cyl
;	- dh: head
;

lba_to_chs:
	push ax
	push dx

	xor dx, dx							; dx = 0
	div word [bdb_sectors_per_track]	; ax = LBA / SetPerTrack
										; dx = LBA % SecPerTrack

	inc dx								; dx = (LBA % SecPerTrack + 1) = sector
	mov cx, dx							; cx = sector

	xor dx, dx							; dx = 0
	div word [bdb_heads]				; ax = (LBA / SecPerTrack + 1) / Heads = ccl
										; dx = (LBA / SecPerTrack + 1) % Heads = head
	mov dh, dl							; dh = head
	mov ch, al							; ch = cyl (low 8 bits)
	shl ah, 6							
	or cl, ah							; put upper 2 bits of cyl in CL

	pop ax								
	mov dl, al							; restore DL
	pop ax								
	ret


;
; Reads sec from a disk
; Params:
;	- ax: LBA addr
;	- cl: num of sec to read (<= 128)
;	- dl: drive num
;	- es:bx: mem addr where to store read data
;
disk_read:

	push ax								; save registers
	push bx
	push cx
	push dx
	push di						

	push cx								; temp save CL
	call lba_to_chs						; compute CHS
	pop ax								; AL = num of sec to read

	mov ah, 02h
	mov di, 3							; retry count
	
.retry:
	pusha								; save all regs, we dont know what bios modify
	stc									; set carry flag, some BIOS dont set it
	int 13h								; carry flag cleared = succes
	jnc .done							; jump if carry not set

	;read fail
	popa
	call disk_reset

	dec di
	test di, di
	jnz .retry

.fail:
	; after all att fail
	call floppy_error
.done:
	popa


	pop di
	pop dx
	pop cx
	pop bx
	pop ax								; restore registers modfied
	ret

;
; Reset disk controller
; Params:
;	dl: drive num
;
disk_reset:
	pusha
	mov ah, 0
	stc
	int 13h
	jc floppy_error
	popa
	ret

msg_hello: db 'Hello world!', 0
msg_read_failed: db 'Floppy read failed', ENDL, 0

times 510-($-$$) db 0
dw 0AA55h
