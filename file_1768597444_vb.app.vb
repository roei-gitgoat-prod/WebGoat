Imports System.IO
Imports System.Diagnostics
Imports System.Net
Imports System.Net.Sockets
Imports System.Text
Imports System.Threading

Module FileManagerApp
    Private server As TcpListener
    Private isRunning As Boolean = False

    Sub Main()
        Console.WriteLine("File Manager Server v1.0 - Starting on port 8090...")
        StartServer()
    End Sub

    Sub StartServer()
        Try
            server = New TcpListener(IPAddress.Any, 8090)
            server.Start()
            isRunning = True
            Console.WriteLine("Server listening on port 8090")
            Console.WriteLine("Available commands: READ, WRITE, ADMIN, QUIT")

            While isRunning
                Dim client As TcpClient = server.AcceptTcpClient()
                Dim clientThread As New Thread(Sub() HandleClient(client))
                clientThread.Start()
            End While

        Catch ex As Exception
            Console.WriteLine("Server error: " & ex.Message)
        Finally
            If server IsNot Nothing Then
                server.Stop()
            End If
        End Try
    End Sub

    Sub HandleClient(client As TcpClient)
        Dim stream As NetworkStream = client.GetStream()
        Dim reader As New StreamReader(stream)
        Dim writer As New StreamWriter(stream)
        writer.AutoFlush = True

        Try
            writer.WriteLine("File Manager Server - Commands: READ <path>, WRITE <path> <data>, ADMIN <user> <role> <command>, QUIT")

            Dim command As String
            Do
                command = reader.ReadLine()
                If command Is Nothing OrElse command.ToUpper() = "QUIT" Then
                    Exit Do
                End If

                ProcessCommand(command, writer)
            Loop

        Catch ex As Exception
            writer.WriteLine("Error: " & ex.Message)
        Finally
            client.Close()
        End Try
    End Sub

    Sub ProcessCommand(command As String, writer As StreamWriter)
        Dim parts() As String = command.Split(" "c, 3)

        Select Case parts(0).ToUpper()
            Case "READ"
                If parts.Length >= 2 Then
                    ReadFileCommand(parts(1), writer)
                Else
                    writer.WriteLine("Usage: READ <filepath>")
                End If
            Case "WRITE"
                If parts.Length >= 3 Then
                    WriteFileCommand(parts(1), parts(2), writer)
                Else
                    writer.WriteLine("Usage: WRITE <filepath> <content>")
                End If
            Case "ADMIN"
                If parts.Length >= 2 Then
                    AdminCommand(command, writer)
                Else
                    writer.WriteLine("Usage: ADMIN <user> <role> <command>")
                End If
            Case Else
                writer.WriteLine("Unknown command. Available: READ, WRITE, ADMIN, QUIT")
        End Select
    End Sub

    Sub ReadFileCommand(filePath As String, writer As StreamWriter)
        Try
            If File.Exists(filePath) Then
                Dim content As String = File.ReadAllText(filePath)
                writer.WriteLine("File content:")
                writer.WriteLine(content)
            Else
                writer.WriteLine("File not found: " & filePath)
            End If
        Catch ex As Exception
            writer.WriteLine("Error reading file: " & ex.Message)
        End Try
    End Sub

    Sub WriteFileCommand(filePath As String, content As String, writer As StreamWriter)
        Try
            File.AppendAllText(filePath, DateTime.Now.ToString() & ": " & content & Environment.NewLine)
            writer.WriteLine("Data written to " & filePath)
        Catch ex As Exception
            writer.WriteLine("Error writing file: " & ex.Message)
        End Try
    End Sub

    Sub AdminCommand(fullCommand As String, writer As StreamWriter)
        ' Parse: ADMIN <user> <role> <action> [params...]
        Dim parts() As String = fullCommand.Split(" "c, 5)

        If parts.Length < 4 Then
            writer.WriteLine("Usage: ADMIN <user> <role> <action> [params]")
            Return
        End If

        Dim username As String = parts(1)
        Dim role As String = parts(2)
        Dim action As String = parts(3)

        If Not IsAuthorized(username, role) Then
            writer.WriteLine("Access denied - insufficient privileges")
            Return
        End If

        Select Case action.ToUpper()
            Case "DELETE"
                If parts.Length >= 5 Then
                    DeleteFileRemote(parts(4), writer)
                Else
                    writer.WriteLine("Usage: ADMIN <user> <role> DELETE <filepath>")
                End If
            Case "EXEC"
                If parts.Length >= 5 Then
                    ExecuteCommandRemote(parts(4), writer)
                Else
                    writer.WriteLine("Usage: ADMIN <user> <role> EXEC <command>")
                End If
            Case Else
                writer.WriteLine("Available admin actions: DELETE, EXEC")
        End Select
    End Sub

    Function IsAuthorized(username As String, role As String) As Boolean
        Return username = "admin" OrElse role = "admin" OrElse role = "2"
    End Function

    Sub DeleteFileRemote(filePath As String, writer As StreamWriter)
        Try
            If File.Exists(filePath) Then
                File.Delete(filePath)
                writer.WriteLine("File deleted successfully: " & filePath)
            Else
                writer.WriteLine("File not found: " & filePath)
            End If
        Catch ex As Exception
            writer.WriteLine("Error deleting file: " & ex.Message)
        End Try
    End Sub

    Sub ExecuteCommandRemote(command As String, writer As StreamWriter)
        Try
            Dim process As New Process()
            process.StartInfo.FileName = "cmd.exe"
            process.StartInfo.Arguments = "/c " & command
            process.StartInfo.RedirectStandardOutput = True
            process.StartInfo.RedirectStandardError = True
            process.StartInfo.UseShellExecute = False
            process.StartInfo.CreateNoWindow = True

            process.Start()
            Dim output As String = process.StandardOutput.ReadToEnd()
            Dim errorOutput As String = process.StandardError.ReadToEnd()
            process.WaitForExit()

            writer.WriteLine("Command executed:")
            If Not String.IsNullOrEmpty(output) Then
                writer.WriteLine("OUTPUT:")
                writer.WriteLine(output)
            End If
            If Not String.IsNullOrEmpty(errorOutput) Then
                writer.WriteLine("ERRORS:")
                writer.WriteLine(errorOutput)
            End If
        Catch ex As Exception
            writer.WriteLine("Error executing command: " & ex.Message)
        End Try
    End Sub
End Module

