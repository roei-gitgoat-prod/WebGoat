       IDENTIFICATION DIVISION.
       PROGRAM-ID. FILE-MANAGER-APP.
       AUTHOR. SECURITY-TESTER.
       DATE-WRITTEN. TODAY.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SOURCE-COMPUTER. IBM-PC.
       OBJECT-COMPUTER. IBM-PC.

       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT USER-FILE ASSIGN TO DYNAMIC WS-FILE-PATH
           ORGANIZATION IS LINE SEQUENTIAL.

           SELECT LOG-FILE ASSIGN TO DYNAMIC WS-LOG-PATH
           ORGANIZATION IS LINE SEQUENTIAL.

           SELECT ADMIN-FILE ASSIGN TO DYNAMIC WS-ADMIN-PATH
           ORGANIZATION IS LINE SEQUENTIAL.

       DATA DIVISION.
       FILE SECTION.
       FD  USER-FILE.
       01  USER-RECORD                PIC X(256).

       FD  LOG-FILE.
       01  LOG-RECORD                 PIC X(512).

       FD  ADMIN-FILE.
       01  ADMIN-RECORD               PIC X(256).

       WORKING-STORAGE SECTION.
       01  WS-MENU-CHOICE             PIC 9.
       01  WS-USER-NAME               PIC X(20).
       01  WS-USER-LEVEL              PIC X(10).
       01  WS-FILE-PATH               PIC X(256).
       01  WS-LOG-PATH                PIC X(256).
       01  WS-ADMIN-PATH              PIC X(256).
       01  WS-INPUT-DATA              PIC X(256).
       01  WS-COMMAND                 PIC X(256).
       01  WS-EOF-FLAG                PIC X VALUE 'N'.
       01  WS-FILE-STATUS             PIC XX.
       01  WS-ADMIN-OPTION            PIC 9.
       01  WS-TARGET-USER             PIC X(20).
       01  WS-DELETE-PATH             PIC X(256).
       01  WS-SYSTEM-CMD              PIC X(512).
       01  WS-LOG-MESSAGE             PIC X(256).
       01  WS-TIMESTAMP               PIC X(20).
       01  WS-ACCESS-GRANTED          PIC X VALUE 'N'.
       01  WS-SERVER-MODE             PIC 9 VALUE 1.
       01  WS-CLIENT-COMMAND          PIC X(256).
       01  WS-RESPONSE-MSG            PIC X(512).
       01  WS-COMMAND-TOKENS          OCCURS 10 TIMES PIC X(50).
       01  WS-TOKEN-COUNT             PIC 99.

       PROCEDURE DIVISION.
       MAIN-PROGRAM.
           PERFORM DISPLAY-BANNER
           DISPLAY "1. Interactive Mode"
           DISPLAY "2. TCP Server Mode"
           DISPLAY "Select mode: " WITH NO ADVANCING
           ACCEPT WS-SERVER-MODE

           IF WS-SERVER-MODE = 2
               PERFORM TCP-SERVER-MODE
           ELSE
               PERFORM MAIN-MENU UNTIL WS-MENU-CHOICE = 9
           END-IF
           STOP RUN.

       DISPLAY-BANNER.
           DISPLAY "========================================".
           DISPLAY "  COBOL FILE MANAGER v1.0  ".
           DISPLAY "========================================".

       MAIN-MENU.
           DISPLAY " ".
           DISPLAY "1. USER LOGIN".
           DISPLAY "2. READ FILE".
           DISPLAY "3. WRITE LOG".
           DISPLAY "4. ADMIN PANEL".
           DISPLAY "9. EXIT".
           DISPLAY "ENTER CHOICE: " WITH NO ADVANCING
           ACCEPT WS-MENU-CHOICE

           EVALUATE WS-MENU-CHOICE
               WHEN 1
                   PERFORM USER-LOGIN
               WHEN 2
                   PERFORM READ-USER-FILE
               WHEN 3
                   PERFORM WRITE-LOG-FILE
               WHEN 4
                   PERFORM ADMIN-ACCESS-CHECK
               WHEN 9
                   DISPLAY "GOODBYE!"
               WHEN OTHER
                   DISPLAY "INVALID OPTION"
           END-EVALUATE.

       USER-LOGIN.
           DISPLAY "ENTER USERNAME: " WITH NO ADVANCING
           ACCEPT WS-USER-NAME
           DISPLAY "ENTER USER LEVEL (USER/ADMIN): " WITH NO ADVANCING
           ACCEPT WS-USER-LEVEL
           DISPLAY "LOGIN SUCCESSFUL FOR " WS-USER-NAME.

       READ-USER-FILE.
           DISPLAY "ENTER FILE PATH: " WITH NO ADVANCING
           ACCEPT WS-FILE-PATH

           OPEN INPUT USER-FILE

           IF WS-FILE-STATUS = '00'
               PERFORM READ-FILE-CONTENTS
               CLOSE USER-FILE
           ELSE
               DISPLAY "ERROR OPENING FILE: " WS-FILE-STATUS
           END-IF.

       READ-FILE-CONTENTS.
           MOVE 'N' TO WS-EOF-FLAG
           PERFORM UNTIL WS-EOF-FLAG = 'Y'
               READ USER-FILE
                   AT END
                       MOVE 'Y' TO WS-EOF-FLAG
                   NOT AT END
                       DISPLAY "FILE CONTENT: " USER-RECORD
               END-READ
           END-PERFORM.

       WRITE-LOG-FILE.
           DISPLAY "ENTER LOG FILE PATH: " WITH NO ADVANCING
           ACCEPT WS-LOG-PATH
           DISPLAY "ENTER LOG MESSAGE: " WITH NO ADVANCING
           ACCEPT WS-LOG-MESSAGE

           MOVE FUNCTION CURRENT-DATE TO WS-TIMESTAMP
           STRING WS-TIMESTAMP ": " WS-LOG-MESSAGE
               DELIMITED BY SIZE INTO LOG-RECORD

           OPEN OUTPUT LOG-FILE
           IF WS-FILE-STATUS = '00'
               WRITE LOG-RECORD
               CLOSE LOG-FILE
               DISPLAY "LOG WRITTEN TO " WS-LOG-PATH
           ELSE
               DISPLAY "ERROR WRITING LOG: " WS-FILE-STATUS
           END-IF.

       ADMIN-ACCESS-CHECK.
           MOVE 'N' TO WS-ACCESS-GRANTED

           IF WS-USER-LEVEL = 'ADMIN' OR
              WS-USER-LEVEL = 'ADMINISTRATOR' OR
              WS-USER-NAME = 'ADMIN'
               MOVE 'Y' TO WS-ACCESS-GRANTED
           END-IF

           IF WS-ACCESS-GRANTED = 'Y'
               PERFORM ADMIN-MENU
           ELSE
               DISPLAY "ACCESS DENIED - ADMIN PRIVILEGES REQUIRED"
           END-IF.

       ADMIN-MENU.
           DISPLAY " ".
           DISPLAY "=== ADMIN PANEL ===".
           DISPLAY "1. DELETE USER FILE".
           DISPLAY "2. EXECUTE SYSTEM COMMAND".
           DISPLAY "3. VIEW SENSITIVE DATA".
           DISPLAY "9. BACK TO MAIN MENU".
           DISPLAY "ADMIN CHOICE: " WITH NO ADVANCING
           ACCEPT WS-ADMIN-OPTION

           EVALUATE WS-ADMIN-OPTION
               WHEN 1
                   PERFORM DELETE-USER-FILE
               WHEN 2
                   PERFORM EXECUTE-COMMAND
               WHEN 3
                   PERFORM VIEW-SENSITIVE-DATA
               WHEN 9
                   CONTINUE
               WHEN OTHER
                   DISPLAY "INVALID ADMIN OPTION"
           END-EVALUATE.

       DELETE-USER-FILE.
           DISPLAY "ENTER FILE PATH TO DELETE: " WITH NO ADVANCING
           ACCEPT WS-DELETE-PATH

           STRING "rm -f " WS-DELETE-PATH DELIMITED BY SIZE
               INTO WS-SYSTEM-CMD

           CALL 'SYSTEM' USING WS-SYSTEM-CMD
           DISPLAY "FILE DELETION ATTEMPTED: " WS-DELETE-PATH.

       EXECUTE-COMMAND.
           DISPLAY "ENTER SYSTEM COMMAND: " WITH NO ADVANCING
           ACCEPT WS-COMMAND

           CALL 'SYSTEM' USING WS-COMMAND
           DISPLAY "COMMAND EXECUTED: " WS-COMMAND.

       VIEW-SENSITIVE-DATA.
           DISPLAY "ENTER SENSITIVE FILE PATH: " WITH NO ADVANCING
           ACCEPT WS-ADMIN-PATH

           OPEN INPUT ADMIN-FILE
           IF WS-FILE-STATUS = '00'
               MOVE 'N' TO WS-EOF-FLAG
               PERFORM UNTIL WS-EOF-FLAG = 'Y'
                   READ ADMIN-FILE
                       AT END
                           MOVE 'Y' TO WS-EOF-FLAG
                       NOT AT END
                           DISPLAY "SENSITIVE DATA: " ADMIN-RECORD
                   END-READ
               END-PERFORM
               CLOSE ADMIN-FILE
           ELSE
               DISPLAY "ERROR ACCESSING SENSITIVE FILE"
           END-IF.

       TCP-SERVER-MODE.
           DISPLAY "COBOL TCP Server starting on port 8087..."
           DISPLAY "Commands: LOGIN <user> <role>, READ <path>, WRITE <path> <msg>, ADMIN <action> [params]"

           PERFORM SERVER-LOOP.

       SERVER-LOOP.
           DISPLAY "Waiting for client connection..."
           DISPLAY "Client connected (simulated)"

           PERFORM CLIENT-SESSION

           DISPLAY "Client disconnected"
           PERFORM SERVER-LOOP.

       CLIENT-SESSION.
           DISPLAY "COBOL File Manager - Commands: LOGIN, READ, WRITE, ADMIN, QUIT"

           PERFORM UNTIL WS-CLIENT-COMMAND = "QUIT"
               DISPLAY "Client command: " WITH NO ADVANCING
               ACCEPT WS-CLIENT-COMMAND

               PERFORM PARSE-CLIENT-COMMAND
               PERFORM PROCESS-CLIENT-COMMAND
           END-PERFORM.

       PARSE-CLIENT-COMMAND.
           MOVE 1 TO WS-TOKEN-COUNT
           MOVE WS-CLIENT-COMMAND TO WS-COMMAND-TOKENS(1).

       PROCESS-CLIENT-COMMAND.
           IF WS-COMMAND-TOKENS(1) = "LOGIN"
               MOVE "testuser" TO WS-USER-NAME
               MOVE "admin" TO WS-USER-LEVEL
               DISPLAY "Login successful for user with admin role"
           ELSE IF WS-COMMAND-TOKENS(1) = "READ"
               PERFORM REMOTE-READ-FILE
           ELSE IF WS-COMMAND-TOKENS(1) = "WRITE"
               PERFORM REMOTE-WRITE-LOG
           ELSE IF WS-COMMAND-TOKENS(1) = "ADMIN"
               PERFORM CHECK-ADMIN-ACCESS
               IF WS-ACCESS-GRANTED = 'Y'
                   PERFORM REMOTE-ADMIN-ACTION
               ELSE
                   DISPLAY "Access denied - admin privileges required"
               END-IF
           ELSE
               DISPLAY "Unknown command. Available: LOGIN, READ, WRITE, ADMIN, QUIT"
           END-IF.

       REMOTE-READ-FILE.
           DISPLAY "Enter file path: " WITH NO ADVANCING
           ACCEPT WS-FILE-PATH

           OPEN INPUT USER-FILE
           IF WS-FILE-STATUS = '00'
               DISPLAY "File contents:"
               MOVE 'N' TO WS-EOF-FLAG
               PERFORM UNTIL WS-EOF-FLAG = 'Y'
                   READ USER-FILE
                       AT END
                           MOVE 'Y' TO WS-EOF-FLAG
                       NOT AT END
                           DISPLAY USER-RECORD
                   END-READ
               END-PERFORM
               CLOSE USER-FILE
           ELSE
               DISPLAY "Error reading file"
           END-IF.

       REMOTE-WRITE-LOG.
           DISPLAY "Enter log path: " WITH NO ADVANCING
           ACCEPT WS-LOG-PATH
           DISPLAY "Enter message: " WITH NO ADVANCING
           ACCEPT WS-LOG-MESSAGE

           OPEN OUTPUT LOG-FILE
           IF WS-FILE-STATUS = '00'
               WRITE LOG-RECORD FROM WS-LOG-MESSAGE
               CLOSE LOG-FILE
               DISPLAY "Log written successfully"
           ELSE
               DISPLAY "Error writing log"
           END-IF.

       REMOTE-ADMIN-ACTION.
           DISPLAY "Enter admin action (DELETE/EXEC): " WITH NO ADVANCING
           ACCEPT WS-COMMAND

           IF WS-COMMAND = "DELETE"
               DISPLAY "Enter file to delete: " WITH NO ADVANCING
               ACCEPT WS-DELETE-PATH
               DISPLAY "File deleted: " WS-DELETE-PATH
           ELSE IF WS-COMMAND = "EXEC"
               DISPLAY "Enter command: " WITH NO ADVANCING
               ACCEPT WS-SYSTEM-CMD
               CALL 'SYSTEM' USING WS-SYSTEM-CMD
               DISPLAY "Command executed: " WS-SYSTEM-CMD
           END-IF.