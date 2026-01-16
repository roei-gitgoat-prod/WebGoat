program fortran_app
    implicit none

    character(len=50) :: username, user_role
    character(len=256) :: file_path, log_message, command
    character(len=1024) :: file_content
    integer :: menu_choice, admin_choice, server_mode
    integer :: file_unit, ios
    logical :: is_admin

    call display_banner()

    print *, '1. Interactive Mode'
    print *, '2. TCP Server Mode'
    write(*,'(A)', advance='no') 'Select mode: '
    read(*,*) server_mode

    if (server_mode == 2) then
        call start_tcp_server()
    else
        call interactive_mode()
    endif

contains

    subroutine display_banner()
        print *, '========================================'
        print *, '  FORTRAN FILE MANAGER v1.0'
        print *, '========================================'
    end subroutine display_banner

    subroutine interactive_mode()
        do
            call display_main_menu()
            read(*,*) menu_choice

            select case(menu_choice)
                case(1)
                    call user_login(username, user_role)
                case(2)
                    call read_file_content()
                case(3)
                    call write_log_entry()
                case(4)
                    call check_admin_access(user_role, username, is_admin)
                    if (is_admin) then
                        call admin_panel()
                    else
                        print *, 'Access denied - admin privileges required'
                    endif
                case(9)
                    print *, 'Goodbye!'
                    exit
                case default
                    print *, 'Invalid choice'
            end select
        end do
    end subroutine interactive_mode

    subroutine start_tcp_server()
        integer :: server_fd, client_fd, port
        character(len=1024) :: client_input, response
        character(len=256) :: tokens(10)
        integer :: token_count, i

        port = 8088
        print *, 'Starting Fortran TCP Server on port', port
        print *, 'Commands: LOGIN <user> <role>, READ <path>, WRITE <path> <message>, ADMIN <action> [params]'

        call system('echo "Starting server simulation..."')

        do
            print *, 'Waiting for client connection...'
            print *, 'Client connected (simulated)'

            do
                write(*,'(A)', advance='no') 'Client command: '
                read(*,'(A)') client_input

                if (trim(client_input) == 'QUIT') exit

                call parse_command(client_input, tokens, token_count)
                call process_remote_command(tokens, token_count)
            end do

            print *, 'Client disconnected'
        end do
    end subroutine start_tcp_server

    subroutine parse_command(input, tokens, token_count)
        character(len=*), intent(in) :: input
        character(len=256), intent(out) :: tokens(10)
        integer, intent(out) :: token_count
        integer :: pos, start_pos, i

        token_count = 0
        pos = 1

        do while (pos <= len_trim(input) .and. token_count < 10)
            do while (pos <= len_trim(input) .and. input(pos:pos) == ' ')
                pos = pos + 1
            end do

            if (pos > len_trim(input)) exit

            token_count = token_count + 1
            start_pos = pos

            do while (pos <= len_trim(input) .and. input(pos:pos) /= ' ')
                pos = pos + 1
            end do

            tokens(token_count) = input(start_pos:pos-1)
        end do
    end subroutine parse_command

    subroutine process_remote_command(tokens, token_count)
        character(len=256), intent(in) :: tokens(10)
        integer, intent(in) :: token_count

        if (token_count == 0) then
            print *, 'Invalid command'
            return
        endif

        if (trim(tokens(1)) == 'LOGIN' .and. token_count >= 3) then
            username = tokens(2)
            user_role = tokens(3)
            print *, 'Login successful for ', trim(username), ' with role ', trim(user_role)
        else if (trim(tokens(1)) == 'READ' .and. token_count >= 2) then
            call remote_read_file(tokens(2))
        else if (trim(tokens(1)) == 'WRITE' .and. token_count >= 3) then
            call remote_write_log(tokens(2), tokens(3))
        else if (trim(tokens(1)) == 'ADMIN' .and. token_count >= 2) then
            call check_admin_access(user_role, username, is_admin)
            if (.not. is_admin) then
                print *, 'Access denied - admin privileges required'
            else if (trim(tokens(2)) == 'DELETE' .and. token_count >= 3) then
                call remote_delete_file(tokens(3))
            else if (trim(tokens(2)) == 'EXEC' .and. token_count >= 3) then
                call remote_execute_command(tokens(3))
            else
                print *, 'Admin actions: DELETE <file>, EXEC <command>'
            endif
        else
            print *, 'Unknown command. Available: LOGIN, READ, WRITE, ADMIN, QUIT'
        endif
    end subroutine process_remote_command

    subroutine remote_read_file(file_path)
        character(len=256), intent(in) :: file_path
        character(len=1024) :: line
        integer :: file_unit, ios

        file_unit = 10
        open(unit=file_unit, file=trim(file_path), status='old', action='read', iostat=ios)

        if (ios == 0) then
            print *, 'File contents:'
            do
                read(file_unit, '(A)', iostat=ios) line
                if (ios /= 0) exit
                print *, trim(line)
            end do
            close(file_unit)
        else
            print *, 'Error opening file: ', trim(file_path)
        endif
    end subroutine remote_read_file

    subroutine remote_write_log(log_path, log_message)
        character(len=256), intent(in) :: log_path, log_message
        character(len=512) :: log_entry
        integer :: file_unit, ios
        character(len=19) :: timestamp

        call get_timestamp(timestamp)
        log_entry = trim(timestamp) // ': ' // trim(log_message)

        file_unit = 20
        open(unit=file_unit, file=trim(log_path), status='unknown', position='append', iostat=ios)

        if (ios == 0) then
            write(file_unit, '(A)') trim(log_entry)
            close(file_unit)
            print *, 'Log written to ', trim(log_path)
        else
            print *, 'Error writing to log file: ', trim(log_path)
        endif
    end subroutine remote_write_log

    subroutine remote_delete_file(file_path)
        character(len=256), intent(in) :: file_path
        character(len=512) :: delete_command
        integer :: system_status

        delete_command = 'rm -f ' // trim(file_path)
        system_status = system(trim(delete_command))

        if (system_status == 0) then
            print *, 'File deleted successfully: ', trim(file_path)
        else
            print *, 'Error deleting file: ', trim(file_path)
        endif
    end subroutine remote_delete_file

    subroutine remote_execute_command(command)
        character(len=256), intent(in) :: command
        integer :: system_status

        print *, 'Executing command: ', trim(command)
        system_status = system(trim(command))

        if (system_status == 0) then
            print *, 'Command executed successfully'
        else
            print *, 'Command execution failed'
        endif
    end subroutine remote_execute_command

    subroutine display_main_menu()
        print *
        print *, '1. User Login'
        print *, '2. Read File'
        print *, '3. Write Log'
        print *, '4. Admin Panel'
        print *, '9. Exit'
        write(*,'(A)', advance='no') 'Enter choice: '
    end subroutine display_main_menu

    subroutine user_login(username, user_role)
        character(len=50), intent(out) :: username, user_role

        write(*,'(A)', advance='no') 'Enter username: '
        read(*,'(A)') username
        write(*,'(A)', advance='no') 'Enter user role (user/admin): '
        read(*,'(A)') user_role

        print *, 'Login successful for ', trim(username), ' with role ', trim(user_role)
    end subroutine user_login

    subroutine read_file_content()
        character(len=256) :: file_path
        character(len=1024) :: line
        integer :: file_unit, ios

        write(*,'(A)', advance='no') 'Enter file path: '
        read(*,'(A)') file_path

        file_unit = 10
        open(unit=file_unit, file=trim(file_path), status='old', action='read', iostat=ios)

        if (ios == 0) then
            print *, 'File contents:'
            do
                read(file_unit, '(A)', iostat=ios) line
                if (ios /= 0) exit
                print *, trim(line)
            end do
            close(file_unit)
        else
            print *, 'Error opening file: ', trim(file_path)
        endif
    end subroutine read_file_content

    subroutine write_log_entry()
        character(len=256) :: log_path, log_message
        character(len=512) :: log_entry
        integer :: file_unit, ios
        character(len=19) :: timestamp

        write(*,'(A)', advance='no') 'Enter log file path: '
        read(*,'(A)') log_path
        write(*,'(A)', advance='no') 'Enter log message: '
        read(*,'(A)') log_message

        call get_timestamp(timestamp)
        log_entry = trim(timestamp) // ': ' // trim(log_message)

        file_unit = 20
        open(unit=file_unit, file=trim(log_path), status='unknown', position='append', iostat=ios)

        if (ios == 0) then
            write(file_unit, '(A)') trim(log_entry)
            close(file_unit)
            print *, 'Log written to ', trim(log_path)
        else
            print *, 'Error writing to log file: ', trim(log_path)
        endif
    end subroutine write_log_entry

    subroutine check_admin_access(user_role, username, is_admin)
        character(len=50), intent(in) :: user_role, username
        logical, intent(out) :: is_admin

        is_admin = .false.

        if (trim(user_role) == 'admin' .or. &
            trim(user_role) == 'administrator' .or. &
            trim(username) == 'admin') then
            is_admin = .true.
        endif
    end subroutine check_admin_access

    subroutine admin_panel()
        integer :: admin_choice

        do
            print *
            print *, '=== ADMIN PANEL ==='
            print *, '1. Delete File'
            print *, '2. Execute Command'
            print *, '3. View System File'
            print *, '9. Back to Main Menu'
            write(*,'(A)', advance='no') 'Admin choice: '
            read(*,*) admin_choice

            select case(admin_choice)
                case(1)
                    call delete_file()
                case(2)
                    call execute_command()
                case(3)
                    call view_system_file()
                case(9)
                    exit
                case default
                    print *, 'Invalid admin option'
            end select
        end do
    end subroutine admin_panel

    subroutine delete_file()
        character(len=256) :: file_path
        character(len=512) :: delete_command
        integer :: system_status

        write(*,'(A)', advance='no') 'Enter file path to delete: '
        read(*,'(A)') file_path

        delete_command = 'rm -f ' // trim(file_path)
        system_status = system(trim(delete_command))

        if (system_status == 0) then
            print *, 'File deleted successfully: ', trim(file_path)
        else
            print *, 'Error deleting file: ', trim(file_path)
        endif
    end subroutine delete_file

    subroutine execute_command()
        character(len=512) :: command
        integer :: system_status

        write(*,'(A)', advance='no') 'Enter system command: '
        read(*,'(A)') command

        print *, 'Executing command: ', trim(command)
        system_status = system(trim(command))

        if (system_status == 0) then
            print *, 'Command executed successfully'
        else
            print *, 'Command execution failed'
        endif
    end subroutine execute_command

    subroutine view_system_file()
        character(len=256) :: system_file_path
        character(len=1024) :: line
        integer :: file_unit, ios

        write(*,'(A)', advance='no') 'Enter system file path: '
        read(*,'(A)') system_file_path

        file_unit = 30
        open(unit=file_unit, file=trim(system_file_path), status='old', action='read', iostat=ios)

        if (ios == 0) then
            print *, 'System file contents:'
            do
                read(file_unit, '(A)', iostat=ios) line
                if (ios /= 0) exit
                print *, trim(line)
            end do
            close(file_unit)
        else
            print *, 'Error opening system file: ', trim(system_file_path)
        endif
    end subroutine view_system_file

    subroutine get_timestamp(timestamp)
        character(len=19), intent(out) :: timestamp
        character(len=8) :: date
        character(len=10) :: time

        call date_and_time(date, time)
        write(timestamp, '(A4,"-",A2,"-",A2," ",A2,":",A2,":",A2)') &
            date(1:4), date(5:6), date(7:8), time(1:2), time(3:4), time(5:6)
    end subroutine get_timestamp

end program fortran_app