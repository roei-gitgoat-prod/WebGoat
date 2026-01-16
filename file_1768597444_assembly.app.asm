section .data
    banner db '========================================', 10
           db '  ASSEMBLY FILE MANAGER v1.0', 10
           db '========================================', 10, 0

    menu db 10, '1. Login', 10
         db '2. Read File', 10
         db '3. Write Log', 10
         db '4. Admin Panel', 10
         db '5. Buffer Overflow Demo', 10
         db '9. Exit', 10
         db 'Choice: ', 0

    admin_menu db 10, '=== ADMIN PANEL ===', 10
               db '1. Delete File', 10
               db '2. Execute Command', 10
               db '3. View System File', 10
               db '9. Back', 10
               db 'Admin Choice: ', 0

    prompt_user db 'Username: ', 0
    prompt_role db 'Role (user/admin): ', 0
    prompt_file db 'File path: ', 0
    prompt_log db 'Log file: ', 0
    prompt_msg db 'Message: ', 0
    prompt_cmd db 'Command: ', 0

    login_success db 'Login successful', 10, 0
    access_denied db 'Access denied', 10, 0
    file_not_found db 'File not found', 10, 0
    operation_complete db 'Operation completed', 10, 0

    current_user db 32 dup(0)
    current_role db 16 dup(0)
    file_buffer db 1024 dup(0)
    input_buffer db 256 dup(0)
    small_buffer db 64 dup(0)

section .bss
    choice resb 2

section .text
    global _start

_start:
    call print_banner

main_loop:
    call print_menu
    call get_input
    call parse_choice

    cmp al, '1'
    je do_login
    cmp al, '2'
    je do_read_file
    cmp al, '3'
    je do_write_log
    cmp al, '4'
    je do_admin_panel
    cmp al, '5'
    je do_buffer_overflow
    cmp al, '9'
    je exit_program
    jmp main_loop

do_login:
    mov rsi, prompt_user
    call print_string
    mov rsi, current_user
    mov rdx, 32
    call read_input

    mov rsi, prompt_role
    call print_string
    mov rsi, current_role
    mov rdx, 16
    call read_input

    mov rsi, login_success
    call print_string
    jmp main_loop

do_read_file:
    mov rsi, prompt_file
    call print_string
    mov rsi, input_buffer
    mov rdx, 256
    call read_input

    call open_and_read_file
    jmp main_loop

do_write_log:
    mov rsi, prompt_log
    call print_string
    mov rsi, input_buffer
    mov rdx, 256
    call read_input

    mov rsi, prompt_msg
    call print_string
    mov rsi, file_buffer
    mov rdx, 1024
    call read_input

    call write_to_log
    jmp main_loop

do_admin_panel:
    call check_admin_access
    test rax, rax
    jz access_denied_msg

admin_loop:
    mov rsi, admin_menu
    call print_string
    call get_input
    call parse_choice

    cmp al, '1'
    je admin_delete
    cmp al, '2'
    je admin_execute
    cmp al, '3'
    je admin_view_system
    cmp al, '9'
    je main_loop
    jmp admin_loop

admin_delete:
    mov rsi, prompt_file
    call print_string
    mov rsi, input_buffer
    mov rdx, 256
    call read_input

    call delete_file_unsafe
    jmp admin_loop

admin_execute:
    mov rsi, prompt_cmd
    call print_string
    mov rsi, input_buffer
    mov rdx, 256
    call read_input

    call execute_command_unsafe
    jmp admin_loop

admin_view_system:
    mov rsi, prompt_file
    call print_string
    mov rsi, input_buffer
    mov rdx, 256
    call read_input

    call view_system_file
    jmp admin_loop

do_buffer_overflow:
    mov rsi, prompt_msg
    call print_string

    mov rsi, small_buffer
    mov rdx, 1024
    call read_input

    mov rsi, operation_complete
    call print_string
    jmp main_loop

access_denied_msg:
    mov rsi, access_denied
    call print_string
    jmp main_loop

exit_program:
    mov rax, 60
    xor rdi, rdi
    syscall

print_banner:
    mov rsi, banner
    call print_string
    ret

print_menu:
    mov rsi, menu
    call print_string
    ret

print_string:
    push rax
    push rdi
    push rdx

    xor rcx, rcx
find_length:
    cmp byte [rsi + rcx], 0
    je print_it
    inc rcx
    jmp find_length

print_it:
    mov rax, 1
    mov rdi, 1
    mov rdx, rcx
    syscall

    pop rdx
    pop rdi
    pop rax
    ret

get_input:
    mov rax, 0
    mov rdi, 0
    mov rsi, choice
    mov rdx, 2
    syscall
    ret

read_input:
    push rdi
    push rax

    mov rax, 0
    mov rdi, 0
    syscall

    pop rax
    pop rdi
    ret

parse_choice:
    mov al, [choice]
    ret

check_admin_access:
    mov rsi, current_role
    mov rdi, admin_string
    call string_compare
    ret

open_and_read_file:
    push rbp
    mov rbp, rsp

    mov rax, 2
    mov rdi, input_buffer
    mov rsi, 0
    syscall

    cmp rax, 0
    js file_error

    mov rdi, rax
    mov rax, 0
    mov rsi, file_buffer
    mov rdx, 1024
    syscall

    mov rax, 1
    mov rdi, 1
    mov rsi, file_buffer
    syscall

    jmp operation_done

file_error:
    mov rsi, file_not_found
    call print_string

operation_done:
    pop rbp
    ret

write_to_log:
    mov rax, 2
    mov rdi, input_buffer
    mov rsi, 1025
    syscall

    cmp rax, 0
    js operation_done

    mov rdi, rax
    mov rax, 1
    mov rsi, file_buffer
    call get_string_length
    mov rdx, rcx
    syscall

    mov rax, 3
    syscall

    mov rsi, operation_complete
    call print_string
    ret

delete_file_unsafe:
    mov rax, 87
    mov rdi, input_buffer
    syscall

    mov rsi, operation_complete
    call print_string
    ret

execute_command_unsafe:
    mov rax, 59
    mov rdi, shell_path
    mov rsi, shell_args
    mov rdx, 0
    syscall

    mov rsi, operation_complete
    call print_string
    ret

view_system_file:
    call open_and_read_file
    ret

string_compare:
    push rsi
    push rdi

compare_loop:
    mov al, [rsi]
    mov bl, [rdi]
    cmp al, bl
    jne not_equal

    test al, al
    jz equal

    inc rsi
    inc rdi
    jmp compare_loop

not_equal:
    xor rax, rax
    jmp compare_done

equal:
    mov rax, 1

compare_done:
    pop rdi
    pop rsi
    ret

get_string_length:
    xor rcx, rcx
length_loop:
    cmp byte [rsi + rcx], 0
    je length_done
    inc rcx
    jmp length_loop
length_done:
    ret

section .data
    admin_string db 'admin', 0
    shell_path db '/bin/sh', 0
    shell_args dq shell_path, shell_flag, input_buffer, 0
    shell_flag db '-c', 0