

[org 0x7c00]
[bits 16]

start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7c00
    mov [boot_drive], dl
    sti

    mov si, boot_msg
    call print_string

show_menu:
    mov si, menu_msg
    call print_string

wait_for_key:
    mov ah, 0
    int 0x16
    cmp al, '1'
    je option_1
    cmp al, '2'
    je option_2
    jmp wait_for_key

option_1:
    mov si, opt1_msg
    call print_string

    mov ah, 0x02
    mov al, 4
    mov ch, 0
    mov dh, 0
    mov cl, 2
    mov bx, 0x7e00
    mov dl, [boot_drive]
    int 0x13
    jc disk_error

    jmp 0x7e00

option_2:
    mov si, opt2_msg
    call print_string
    jmp $

disk_error:
    mov si, disk_err_msg
    call print_string
    jmp $

print_string:
    mov ah, 0x0e
.loop:
    lodsb
    or al, al
    jz .done
    int 0x10
    jmp .loop
.done:
    ret

boot_msg     db 'LarpOS v0.1.5', 13, 10, 0
menu_msg     db '1-Start  2-Shutdown', 13, 10, 0
opt1_msg     db 'Starting...', 13, 10, 0
opt2_msg     db 'Halted.', 0
disk_err_msg db 'Disk Read Error!', 13, 10, 0
boot_drive   db 0

times 510-($-$$) db 0
dw 0xaa55

[bits 16]

stage2_start:
    cli

    in al, 0x92
    or al, 2
    out 0x92, al

    lgdt [gdt32_descriptor]

    mov eax, cr0
    or eax, 1
    mov cr0, eax

    jmp 0x08:protected_mode_entry

gdt32_start:
    dq 0
    dw 0xFFFF, 0x0000
    db 0x00, 10011010b, 11001111b, 0x00
    dw 0xFFFF, 0x0000
    db 0x00, 10010010b, 11001111b, 0x00
gdt32_end:

gdt32_descriptor:
    dw gdt32_end - gdt32_start - 1
    dd gdt32_start

[bits 32]
protected_mode_entry:
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov esp, 0x90000

    mov edi, 0x1000
    mov ecx, 3072
    xor eax, eax
    rep stosd

    mov eax, cr4
    or eax, (1 << 5)
    mov cr4, eax

    mov dword [0x1000], 0x2003
    mov dword [0x1004], 0
    mov dword [0x2000], 0x3003
    mov dword [0x2004], 0
    mov dword [0x3000], 0x0083
    mov dword [0x3004], 0

    mov eax, 0x1000
    mov cr3, eax

    mov ecx, 0xC0000080
    rdmsr
    or eax, (1 << 8)
    wrmsr

    mov eax, cr0
    or eax, (1 << 31)
    mov cr0, eax

    lgdt [gdt64_descriptor]
    jmp 0x08:long_mode_entry

gdt64_start:
    dq 0
    dw 0x0000, 0x0000
    db 0x00, 10011010b, 10100000b, 0x00
    dw 0x0000, 0x0000
    db 0x00, 10010010b, 0x00, 0x00
gdt64_end:

gdt64_descriptor:
    dw gdt64_end - gdt64_start - 1
    dq gdt64_start

[bits 64]
long_mode_entry:
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov rsp, 0x90000

    call kernel_main
    jmp $

VGA_BASE    equ 0xb8000
VGA_COLS    equ 80
VGA_ROWS    equ 25
COLOR_WHITE equ 0x0f
COLOR_GREEN equ 0x0a
COLOR_CYAN  equ 0x0b
COLOR_RED   equ 0x0c
COLOR_GRAY  equ 0x08

cursor_x: dq 0
cursor_y: dq 1

vga_putchar:
    push rbx
    push rcx
    push rdx
    push rdi

    cmp al, 13
    je .carriage_return
    cmp al, 10
    je .newline
    cmp al, 8
    je .backspace

    mov rbx, [cursor_y]
    imul rbx, VGA_COLS
    add rbx, [cursor_x]
    imul rbx, 2
    add rbx, VGA_BASE
    mov [rbx], al
    mov [rbx+1], ah

    inc qword [cursor_x]
    cmp qword [cursor_x], VGA_COLS
    jl .done
    mov qword [cursor_x], 0
    inc qword [cursor_y]
    jmp .scroll_check

.carriage_return:
    mov qword [cursor_x], 0
    jmp .done

.newline:
    mov qword [cursor_x], 0
    inc qword [cursor_y]
    jmp .scroll_check

.backspace:
    cmp qword [cursor_x], 0
    je .done
    dec qword [cursor_x]
    mov rbx, [cursor_y]
    imul rbx, VGA_COLS
    add rbx, [cursor_x]
    imul rbx, 2
    add rbx, VGA_BASE
    mov byte [rbx], ' '
    mov byte [rbx+1], COLOR_WHITE
    jmp .done

.scroll_check:
    cmp qword [cursor_y], VGA_ROWS
    jl .done
    mov rdi, VGA_BASE
    mov rsi, VGA_BASE + (VGA_COLS * 2)
    mov rcx, VGA_COLS * (VGA_ROWS - 1)
.scroll_loop:
    mov ax, [rsi]
    mov [rdi], ax
    add rdi, 2
    add rsi, 2
    loop .scroll_loop
    mov rcx, VGA_COLS
.clear_last:
    mov word [rdi], 0x0f20
    add rdi, 2
    loop .clear_last
    dec qword [cursor_y]

.done:
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    ret

vga_print:
    push rax
    push rsi
.loop:
    lodsb
    or al, al
    jz .done
    call vga_putchar
    jmp .loop
.done:
    pop rsi
    pop rax
    ret

vga_println:
    call vga_print
    push rax
    mov ah, COLOR_WHITE
    mov al, 10
    call vga_putchar
    pop rax
    ret

vga_clear:
    push rdi
    push rcx
    mov rdi, VGA_BASE
    mov rcx, VGA_COLS * VGA_ROWS
.loop:
    mov word [rdi], 0x0f20
    add rdi, 2
    loop .loop
    mov qword [cursor_x], 0
    mov qword [cursor_y], 0
    pop rcx
    pop rdi
    ret

strcmp:
    push rsi
    push rdi
.loop:
    mov al, [rsi]
    mov bl, [rdi]
    cmp al, bl
    jne .not_equal
    or al, al
    jz .equal
    inc rsi
    inc rdi
    jmp .loop
.equal:
    pop rdi
    pop rsi
    xor al, al
    ret
.not_equal:
    pop rdi
    pop rsi
    mov al, 1
    ret

input_buffer: times 128 db 0
input_len:    dq 0

read_line:
    push rax
    push rbx
    push rdi

    mov qword [input_len], 0
    lea rdi, [input_buffer]

.read_loop:
    mov rax, 0
.wait_key:
    in al, 0x64
    test al, 1
    jz .wait_key

    in al, 0x60
    call scancode_to_ascii
    cmp al, 0
    je .read_loop

    cmp al, 13
    je .enter

    cmp al, 8
    je .backspace

    cmp qword [input_len], 127
    jge .read_loop

    mov [rdi], al
    inc rdi
    inc qword [input_len]

    mov ah, COLOR_WHITE
    call vga_putchar
    jmp .read_loop

.backspace:
    cmp qword [input_len], 0
    je .read_loop
    dec rdi
    dec qword [input_len]
    mov ah, COLOR_WHITE
    mov al, 8
    call vga_putchar
    jmp .read_loop

.enter:
    mov byte [rdi], 0
    mov ah, COLOR_WHITE
    mov al, 10
    call vga_putchar

    pop rdi
    pop rbx
    pop rax
    ret

scancode_to_ascii:
    test al, 0x80
    jnz .invalid

    cmp al, 0x3A
    jge .invalid

    lea rbx, [scancode_table]
    movzx rax, byte [rbx + rax]
    ret

.invalid:
    xor al, al
    ret

scancode_table:
    db 0,0,'1','2','3','4','5','6','7','8','9','0','-','=',8
    db 9,'q','w','e','r','t','y','u','i','o','p','[',']',13
    db 0,'a','s','d','f','g','h','j','k','l',';',"'",'`',0
    db '\','z','x','c','v','b','n','m',',','.','/',0,'*',0,' '

cmd_uname:   db 'uname', 0
cmd_clear:   db 'clear', 0
cmd_help:    db 'help', 0
cmd_color:   db 'color', 0
cmd_ls:      db 'ls', 0
cmd_pwd:     db 'pwd', 0
cmd_whoami:  db 'whoami', 0
cmd_cat:     db 'cat', 0
cmd_ascii:   db 'ascii', 0

uname_str:   db 'LarpOS 0.1.5 garpland x86_64', 0
help_str:    db 'Komutlar: ls, pwd, whoami, cat, clear, uname, color, ascii', 0
unknown_str: db 'Bilinmeyen komut. "help" yazin.', 0
color_str:   db 'Renk degistirildi!', 0
ls_str:      db 'bin  dev  etc  home  proc  usr', 0
pwd_str:     db '/home/garodaemon', 0
whoami_str:  db 'garodaemon', 0
cat_str:     db 'LarpOS POSIX-like shell test file.', 0
ascii_str:   db 'Larp OS 0.1.5', 0

shell_color: db COLOR_GREEN

process_command:
    push rsi
    push rdi

    lea rsi, [input_buffer]
    lea rdi, [cmd_uname]
    call strcmp
    je .do_uname

    lea rsi, [input_buffer]
    lea rdi, [cmd_clear]
    call strcmp
    je .do_clear

    lea rsi, [input_buffer]
    lea rdi, [cmd_help]
    call strcmp
    je .do_help

    lea rsi, [input_buffer]
    lea rdi, [cmd_color]
    call strcmp
    je .do_color

    lea rsi, [input_buffer]
    lea rdi, [cmd_ls]
    call strcmp
    je .do_ls

    lea rsi, [input_buffer]
    lea rdi, [cmd_pwd]
    call strcmp
    je .do_pwd

    lea rsi, [input_buffer]
    lea rdi, [cmd_whoami]
    call strcmp
    je .do_whoami

    lea rsi, [input_buffer]
    lea rdi, [cmd_cat]
    call strcmp
    je .do_cat

    lea rsi, [input_buffer]
    lea rdi, [cmd_ascii]
    call strcmp
    je .do_ascii

    lea rsi, [unknown_str]
    mov ah, COLOR_RED
    call vga_println
    jmp .done

.do_uname:
    lea rsi, [uname_str]
    mov ah, COLOR_CYAN
    call vga_println
    jmp .done

.do_clear:
    call vga_clear
    jmp .done

.do_help:
    lea rsi, [help_str]
    mov ah, COLOR_WHITE
    call vga_println
    jmp .done

; I hate my life

.do_ls:
    lea rsi, [ls_str]
    mov ah, COLOR_CYAN
    call vga_println
    jmp .done

.do_pwd:
    lea rsi, [pwd_str]
    mov ah, COLOR_WHITE
    call vga_println
    jmp .done

.do_whoami:
    lea rsi, [whoami_str]
    mov ah, COLOR_GREEN
    call vga_println
    jmp .done

.do_cat:
    lea rsi, [cat_str]
    mov ah, COLOR_WHITE
    call vga_println
    jmp .done

.do_ascii:
    lea rsi, [ascii_str]
    mov ah, COLOR_WHITE
    call vga_println
    jmp .done

.do_color:
    cmp byte [shell_color], COLOR_GREEN
    je .set_white
    mov byte [shell_color], COLOR_GREEN
    jmp .color_done
.set_white:
    mov byte [shell_color], COLOR_WHITE
.color_done:
    lea rsi, [color_str]
    mov ah, COLOR_CYAN
    call vga_println

.done:
    pop rdi
    pop rsi
    ret

kernel_main:
    call vga_clear

    lea rsi, [banner1]
    mov ah, COLOR_CYAN
    call vga_println

    lea rsi, [banner2]
    mov ah, COLOR_CYAN
    call vga_println

    lea rsi, [banner3]
    mov ah, COLOR_WHITE
    call vga_println

    lea rsi, [banner4]
    mov ah, COLOR_GRAY
    call vga_println

    lea rsi, [empty_str]
    mov ah, COLOR_WHITE
    call vga_println

shell_loop:
    lea rsi, [prompt]
    movzx rax, byte [shell_color]
    mov ah, al
    call vga_print

    call read_line

    cmp qword [input_len], 0
    je shell_loop

    call process_command

    jmp shell_loop

banner1:    db '  _                 ____  ____  ', 0
banner2:    db ' | |    __ _ _ __ |  _ \/ __ \ ', 0
banner3:    db ' | |   / _` | `__|| |_) | |  | |', 0
banner4:    db ' |_|   \__,_|_|   |____/ \____/ v0.1.5', 0
empty_str:  db '', 0
prompt:     db 'garodaemon@larpos:~$ ', 0









