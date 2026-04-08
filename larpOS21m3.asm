org 0x7c00
use16

start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7c00
    mov [boot_drive], dl
    sti

    mov ah, 0x00
    mov al, 0x03
    int 0x10

    mov ah, 0x01
    mov cx, 0x2000
    int 0x10

    mov si, boot_msg
    call print_rm

show_menu:
    mov si, menu_msg
    call print_rm

wait_key:
    mov ah, 0x00
    int 0x16
    cmp al, '1'
    je boot_kernel
    cmp al, '2'
    je halt_sys
    jmp wait_key

halt_sys:
    mov si, halt_msg
    call print_rm
    jmp $

boot_kernel:
    mov ah, 0x02
    mov al, 15
    mov ch, 0
    mov dh, 0
    mov cl, 2
    mov bx, 0x7e00
    mov dl, [boot_drive]
    int 0x13

    cli
    in al, 0x92
    or al, 2
    out 0x92, al

    lgdt [gdt_descriptor]
    mov eax, cr0
    or eax, 1
    mov cr0, eax
    jmp 0x08:pm_entry

print_rm:
    mov ah, 0x0e
.loop:
    lodsb
    or al, al
    jz .done
    int 0x10
    jmp .loop
.done:
    ret

boot_msg db 'LarpOS 2.1 Bootloader', 13, 10, 0
menu_msg db '1-Start Netherlarps Terminal', 13, 10, 0
halt_msg db 'Halted.', 0
boot_drive db 0

times 510-($-start) db 0
dw 0xaa55

use16
gdt_start:
    dq 0
    dw 0xFFFF, 0x0000
    db 0x00, 10011010b, 11001111b, 0x00
    dw 0xFFFF, 0x0000
    db 0x00, 10010010b, 11001111b, 0x00
gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1
    dd gdt_start

use32
pm_entry:
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov ss, ax
    mov esp, 0x90000

    call draw_desktop
    call draw_shadow
    call draw_window
    call draw_titlebar
    call draw_title_text
    call draw_banner

keyboard_loop:
    in al, 0x64
    test al, 1
    jz keyboard_loop

    in al, 0x60
    test al, 0x80
    jnz keyboard_loop

    cmp al, 0x1C
    je handle_enter
    cmp al, 0x0E
    je handle_backspace

    and eax, 0xFF
    mov al, [keymap + eax]
    or al, al
    jz keyboard_loop

    call print_char_pm
    jmp keyboard_loop

handle_enter:
    mov ecx, [buffer_index]
    mov byte [input_buffer + ecx], 0
    cmp ecx, 0
    je .done_cmd

    mov esi, input_buffer
    mov edi, cmd_help
    call strcmp
    cmp eax, 1
    je .do_help

    mov esi, input_buffer
    mov edi, cmd_clear
    call strcmp
    cmp eax, 1
    je .do_clear

    mov esi, input_buffer
    mov edi, cmd_uname
    call strcmp
    cmp eax, 1
    je .do_uname

    mov esi, input_buffer
    mov edi, cmd_pwd
    call strcmp
    cmp eax, 1
    je .do_pwd

    mov esi, input_buffer
    mov edi, cmd_ls
    call strcmp
    cmp eax, 1
    je .do_ls

    mov esi, input_buffer
    mov edi, cmd_lsblk
    call strcmp
    cmp eax, 1
    je .do_lsblk

    mov esi, input_buffer
    mov edi, cmd_cat
    call strcmp
    cmp eax, 1
    je .do_cat

    mov esi, input_buffer
    mov edi, cmd_echo
    call strcmp
    cmp eax, 1
    je .do_echo

    mov esi, input_buffer
    mov edi, cmd_reboot
    call strcmp
    cmp eax, 1
    je .do_reboot

    mov dword [cursor_x], 12
    inc dword [cursor_y]
    call check_scroll
    mov esi, out_err
    mov ah, 0x0C
    call print_string_pm
    jmp .done_cmd

.do_help:
    mov dword [cursor_x], 12
    inc dword [cursor_y]
    call check_scroll
    mov esi, out_help
    mov ah, 0x0A
    call print_string_pm
    jmp .done_cmd

.do_clear:
    call draw_window
    mov dword [cursor_x], 12
    mov dword [cursor_y], 5
    jmp .done_cmd

.do_uname:
    mov dword [cursor_x], 12
    inc dword [cursor_y]
    call check_scroll
    mov esi, out_uname
    mov ah, 0x0B
    call print_string_pm
    jmp .done_cmd

.do_pwd:
    mov dword [cursor_x], 12
    inc dword [cursor_y]
    call check_scroll
    mov esi, out_pwd
    mov ah, 0x0B
    call print_string_pm
    jmp .done_cmd

.do_ls:
    mov dword [cursor_x], 12
    inc dword [cursor_y]
    call check_scroll
    mov esi, out_ls
    mov ah, 0x0B
    call print_string_pm
    jmp .done_cmd

.do_lsblk:
    mov dword [cursor_x], 12
    inc dword [cursor_y]
    call check_scroll
    mov esi, out_lsblk
    mov ah, 0x0B
    call print_string_pm
    jmp .done_cmd

.do_cat:
    mov dword [cursor_x], 12
    inc dword [cursor_y]
    call check_scroll
    mov esi, out_cat
    mov ah, 0x0B
    call print_string_pm
    jmp .done_cmd

.do_echo:
    mov dword [cursor_x], 12
    inc dword [cursor_y]
    call check_scroll
    mov esi, out_echo
    mov ah, 0x0C
    call print_string_pm
    jmp .done_cmd

.do_reboot:
    mov al, 0xFE
    out 0x64, al
    jmp $

.done_cmd:
    mov dword [buffer_index], 0
    mov dword [cursor_x], 12
    inc dword [cursor_y]
    call check_scroll
    mov esi, prompt
    mov ah, 0x0A
    call print_string_pm
    jmp keyboard_loop

handle_backspace:
    cmp dword [cursor_x], 38
    jle keyboard_loop
    cmp dword [buffer_index], 0
    jle .skip_buf
    dec dword [buffer_index]
.skip_buf:
    dec dword [cursor_x]
    mov al, ' '
    push ebx
    push edx
    push edi
    mov ebx, [cursor_y]
    mov edx, [cursor_x]
    mov edi, 0xb8000
    imul ebx, 80
    add ebx, edx
    shl ebx, 1
    add edi, ebx
    mov [edi], al
    mov byte [edi+1], 0x0A
    pop edi
    pop edx
    pop ebx
    jmp keyboard_loop

print_char_pm:
    mov ecx, [buffer_index]
    cmp ecx, 63
    jge .skip_buf_char
    mov [input_buffer + ecx], al
    inc dword [buffer_index]
.skip_buf_char:
    push ebx
    push edx
    push edi
    mov ebx, [cursor_y]
    mov edx, [cursor_x]
    mov edi, 0xb8000
    imul ebx, 80
    add ebx, edx
    shl ebx, 1
    add edi, ebx
    mov [edi], al
    mov byte [edi+1], 0x0A
    inc dword [cursor_x]
    pop edi
    pop edx
    pop ebx
    ret

check_scroll:
    cmp dword [cursor_y], 20
    jl .done_scroll
    call draw_window
    mov dword [cursor_x], 12
    mov dword [cursor_y], 5
.done_scroll:
    ret

strcmp:
    push esi
    push edi
.loop_cmp:
    mov al, [esi]
    mov bl, [edi]
    cmp al, bl
    jne .diff
    or al, al
    jz .match
    inc esi
    inc edi
    jmp .loop_cmp
.diff:
    xor eax, eax
    jmp .done_cmp_res
.match:
    mov eax, 1
.done_cmp_res:
    pop edi
    pop esi
    ret

draw_rect:
    mov edi, 0xb8000
    mov eax, ebx
    imul eax, 80
    add eax, edx
    shl eax, 1
    add edi, eax
.row:
    push edi
    push ecx
.col:
    mov [edi], bp
    add edi, 2
    dec ecx
    jnz .col
    pop ecx
    pop edi
    add edi, 160
    dec esi
    jnz .row
    ret

draw_desktop:
    mov edx, 0
    mov ebx, 0
    mov ecx, 80
    mov esi, 25
    mov bp, 0x19B0
    call draw_rect
    ret

draw_shadow:
    mov edx, 12
    mov ebx, 5
    mov ecx, 60
    mov esi, 17
    mov bp, 0x08DB
    call draw_rect
    ret

draw_window:
    mov edx, 10
    mov ebx, 4
    mov ecx, 60
    mov esi, 17
    mov bp, 0x0F20
    call draw_rect
    ret

draw_titlebar:
    mov edx, 10
    mov ebx, 4
    mov ecx, 60
    mov esi, 1
    mov bp, 0x7020
    call draw_rect
    ret

print_string_pm:
    push eax
    push ebx
    push edx
    push edi
.loop_str:
    lodsb
    or al, al
    jz .done_str
    mov ebx, [cursor_y]
    mov edx, [cursor_x]
    mov edi, 0xb8000
    imul ebx, 80
    add ebx, edx
    shl ebx, 1
    add edi, ebx
    mov [edi], al
    mov [edi+1], ah
    inc dword [cursor_x]
    jmp .loop_str
.done_str:
    pop edi
    pop edx
    pop ebx
    pop eax
    ret

print_string_fixed:
    mov edi, 0xb8000
    mov eax, ebx
    imul eax, 80
    add eax, edx
    shl eax, 1
    add edi, eax
.loop_fix:
    lodsb
    or al, al
    jz .done_fix
    mov [edi], al
    mov [edi+1], ah
    add edi, 2
    jmp .loop_fix
.done_fix:
    ret

draw_title_text:
    mov esi, term_title
    mov edx, 36
    mov ebx, 4
    mov ah, 0x70
    call print_string_fixed
    ret

draw_banner:
    mov esi, banner1
    mov edx, 12
    mov ebx, 6
    mov ah, 0x0A
    call print_string_fixed

    mov esi, banner2
    mov edx, 12
    mov ebx, 7
    mov ah, 0x0A
    call print_string_fixed

    mov esi, banner3
    mov edx, 12
    mov ebx, 8
    mov ah, 0x0A
    call print_string_fixed

    mov esi, banner4
    mov edx, 12
    mov ebx, 9
    mov ah, 0x0F
    call print_string_fixed

    mov dword [cursor_x], 12
    mov dword [cursor_y], 11
    mov esi, prompt
    mov ah, 0x0A
    call print_string_pm
    ret

term_title db 'Terminal', 0
banner1    db '  _                 ____  ____', 0
banner2    db ' | |    __ _ _ __ |  _ \/ __ \', 0
banner3    db ' | |   / _` | `__|| |_) | |  | |', 0
banner4    db ' |_|   \__,_|_|   |____/ \____/ 2.1', 0
prompt     db 'garodaemon@netherlarps:~$ ', 0

cmd_help   db 'help', 0
cmd_uname  db 'uname', 0
cmd_pwd    db 'pwd', 0
cmd_ls     db 'ls', 0
cmd_lsblk  db 'lsblk', 0
cmd_cat    db 'cat', 0
cmd_echo   db 'echo', 0
cmd_reboot db 'reboot', 0
cmd_clear  db 'clear', 0

out_help   db 'cmds: help clear uname pwd ls lsblk cat echo reboot', 0
out_uname  db 'LarpOS 2.1 Netherlarps (x86_32)', 0
out_pwd    db '/home/garodaemon', 0
out_ls     db 'boot.bin  kernel.asm  secret.txt', 0
out_lsblk  db 'fd0: 1.44MB Floppy Drive (Boot)', 0
out_cat    db 'LarpOS cat larping denemesi', 0
out_echo   db 'echo: parser not ready!', 0
out_err    db 'Command not found.', 0

cursor_x dd 38
cursor_y dd 11
buffer_index dd 0
input_buffer: times 64 db 0

keymap:
    db 0, 27, '1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '-', '=', 8, 9
    db 'q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p', '[', ']', 13, 0, 'a', 's'
    db 'd', 'f', 'g', 'h', 'j', 'k', 'l', ';', 39, '`', 0, '\', 'z', 'x', 'c', 'v'
    db 'b', 'n', 'm', ',', '.', '/', 0, '*', 0, ' ', 0, 0, 0, 0, 0, 0
    db 0, 0, 0, 0, 0, 0, 0, '7', '8', '9', '-', '4', '5', '6', '+', '1'
    db '2', '3', '0', '.', 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0

keymap_shift:
    db 0, 27, '!', '@', '#', '$', '%', '^', '&', '*', '(', ')', '_', '+', 8, 9
    db 'Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P', '{', '}', 13, 0, 'A', 'S'
    db 'D', 'F', 'G', 'H', 'J', 'K', 'L', ':', 34, '~', 0, '|', 'Z', 'X', 'C', 'V'
    db 'B', 'N', 'M', '<', '>', '?', 0, '*', 0, ' ', 0, 0, 0, 0, 0, 0
    db 0, 0, 0, 0, 0, 0, 0, '7', '8', '9', '-', '4', '5', '6', '+', '1'
    db '2', '3', '0', '.', 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
 
shift_status db 0
ctrl_status  db 0
alt_status   db 0
caps_lock    db 0

times 65536-($-start) db 0
