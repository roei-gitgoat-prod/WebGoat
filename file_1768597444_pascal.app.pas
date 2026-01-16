program pascal_app;

uses
  SysUtils, Classes, Process, Sockets;

type
  TUser = record
    Username: string;
    UserRole: string;
    IsLoggedIn: Boolean;
  end;

var
  CurrentUser: TUser;
  MenuChoice: Integer;
  AdminChoice: Integer;
  ServerSocket: TInetSocket;
  ClientSocket: TSocket;

procedure DisplayBanner;
begin
  WriteLn('=======================================');
  WriteLn('  PASCAL FILE MANAGER v1.0');
  WriteLn('=======================================');
end;

procedure UserLogin;
var
  Username, Role: string;
begin
  Write('Enter username: ');
  ReadLn(Username);
  Write('Enter user role (user/admin): ');
  ReadLn(Role);

  CurrentUser.Username := Username;
  CurrentUser.UserRole := Role;
  CurrentUser.IsLoggedIn := True;

  WriteLn('Login successful for ', Username, ' with role ', Role);
end;

procedure ReadUserFile;
var
  FilePath: string;
  FileHandle: TextFile;
  Line: string;
begin
  Write('Enter file path to read: ');
  ReadLn(FilePath);

  try
    AssignFile(FileHandle, FilePath);
    Reset(FileHandle);

    WriteLn('File contents:');
    while not EOF(FileHandle) do
    begin
      ReadLn(FileHandle, Line);
      WriteLn(Line);
    end;

    CloseFile(FileHandle);
  except
    on E: Exception do
      WriteLn('Error reading file: ', E.Message);
  end;
end;

procedure WriteLogFile;
var
  LogPath, LogMessage: string;
  LogFile: TextFile;
begin
  Write('Enter log file path: ');
  ReadLn(LogPath);
  Write('Enter log message: ');
  ReadLn(LogMessage);

  try
    AssignFile(LogFile, LogPath);
    Append(LogFile);
    WriteLn(LogFile, FormatDateTime('yyyy-mm-dd hh:nn:ss', Now), ': ', LogMessage);
    CloseFile(LogFile);
    WriteLn('Log written to ', LogPath);
  except
    on E: Exception do
      WriteLn('Error writing log: ', E.Message);
  end;
end;

function CheckAdminAccess: Boolean;
begin
  Result := (CurrentUser.UserRole = 'admin') or
            (CurrentUser.UserRole = 'administrator') or
            (CurrentUser.Username = 'admin');
end;

procedure DeleteUserFile;
var
  FilePath, Confirmation: string;
begin
  if not CheckAdminAccess then
  begin
    WriteLn('Access denied - admin privileges required');
    Exit;
  end;

  Write('Enter file path to delete: ');
  ReadLn(FilePath);
  Write('Confirm deletion (yes/no): ');
  ReadLn(Confirmation);

  if LowerCase(Confirmation) = 'yes' then
  begin
    try
      DeleteFile(FilePath);
      WriteLn('File ', FilePath, ' deleted successfully');
    except
      on E: Exception do
        WriteLn('Error deleting file: ', E.Message);
    end;
  end
  else
    WriteLn('File deletion cancelled');
end;

procedure ExecuteSystemCommand;
var
  Command: string;
  Process: TProcess;
  OutputStream: TStringList;
begin
  if not CheckAdminAccess then
  begin
    WriteLn('Access denied - admin privileges required');
    Exit;
  end;

  Write('Enter system command: ');
  ReadLn(Command);

  try
    Process := TProcess.Create(nil);
    Process.CommandLine := Command;
    Process.Options := Process.Options + [poWaitOnExit, poUsePipes];
    Process.Execute;

    OutputStream := TStringList.Create;
    OutputStream.LoadFromStream(Process.Output);

    WriteLn('Command output:');
    WriteLn(OutputStream.Text);

    OutputStream.Free;
    Process.Free;
  except
    on E: Exception do
      WriteLn('Command execution failed: ', E.Message);
  end;
end;

procedure ViewSensitiveFile;
var
  SensitivePath: string;
  FileHandle: TextFile;
  Line: string;
begin
  if not CheckAdminAccess then
  begin
    WriteLn('Access denied - admin privileges required');
    Exit;
  end;

  Write('Enter sensitive file path: ');
  ReadLn(SensitivePath);

  try
    AssignFile(FileHandle, SensitivePath);
    Reset(FileHandle);

    WriteLn('Sensitive file contents:');
    while not EOF(FileHandle) do
    begin
      ReadLn(FileHandle, Line);
      WriteLn(Line);
    end;

    CloseFile(FileHandle);
  except
    on E: Exception do
      WriteLn('Error reading sensitive file: ', E.Message);
  end;
end;

procedure AdminPanel;
begin
  repeat
    WriteLn;
    WriteLn('=== ADMIN PANEL ===');
    WriteLn('1. Delete User File');
    WriteLn('2. Execute System Command');
    WriteLn('3. View Sensitive File');
    WriteLn('9. Back to Main Menu');
    Write('Admin choice: ');
    ReadLn(AdminChoice);

    case AdminChoice of
      1: DeleteUserFile;
      2: ExecuteSystemCommand;
      3: ViewSensitiveFile;
      9: Break;
      else
        WriteLn('Invalid admin option');
    end;
  until AdminChoice = 9;
end;

procedure MainMenu;
begin
  DisplayBanner;

  repeat
    WriteLn;
    WriteLn('1. User Login');
    WriteLn('2. Read File');
    WriteLn('3. Write Log');
    WriteLn('4. Admin Panel');
    WriteLn('9. Exit');
    Write('Enter choice: ');
    ReadLn(MenuChoice);

    case MenuChoice of
      1: UserLogin;
      2: ReadUserFile;
      3: WriteLogFile;
      4: AdminPanel;
      9: WriteLn('Goodbye!');
      else
        WriteLn('Invalid choice');
    end;
  until MenuChoice = 9;
end;

procedure StartTCPServer;
var
  CommandLine, Response: string;
  Command: array[1..10] of string;
  ParamCount: Integer;
  i: Integer;
begin
  WriteLn('Starting TCP Server on port 8089...');

  try
    ServerSocket := TInetSocket.Create('0.0.0.0', 8089);
    ServerSocket.Listen;

    WriteLn('Pascal File Manager Server listening on port 8089');
    WriteLn('Commands: LOGIN <user> <role>, READ <path>, WRITE <path> <message>, ADMIN <action> [params]');

    while True do
    begin
      ClientSocket := ServerSocket.Accept;
      WriteLn('Client connected');

      Fpwrite(ClientSocket, 'Pascal File Manager - Commands: LOGIN, READ, WRITE, ADMIN, QUIT'#13#10, 67);

      repeat
        CommandLine := '';
        Fpread(ClientSocket, CommandLine[1], 255);
        CommandLine := Trim(CommandLine);

        if CommandLine = 'QUIT' then
          Break;

        ParamCount := 0;
        i := 1;
        while (i <= Length(CommandLine)) and (ParamCount < 10) do
        begin
          Inc(ParamCount);
          Command[ParamCount] := '';
          while (i <= Length(CommandLine)) and (CommandLine[i] <> ' ') do
          begin
            Command[ParamCount] := Command[ParamCount] + CommandLine[i];
            Inc(i);
          end;
          while (i <= Length(CommandLine)) and (CommandLine[i] = ' ') do
            Inc(i);
        end;

        if (ParamCount > 0) and (Command[1] = 'LOGIN') and (ParamCount >= 3) then
        begin
          CurrentUser.Username := Command[2];
          CurrentUser.UserRole := Command[3];
          CurrentUser.IsLoggedIn := True;
          Response := 'Login successful for ' + Command[2] + ' with role ' + Command[3] + #13#10;
          Fpwrite(ClientSocket, Response[1], Length(Response));
        end
        else if (ParamCount > 0) and (Command[1] = 'READ') and (ParamCount >= 2) then
        begin
          ProcessRemoteFileRead(Command[2]);
        end
        else if (ParamCount > 0) and (Command[1] = 'WRITE') and (ParamCount >= 3) then
        begin
          ProcessRemoteLogWrite(Command[2], Command[3]);
        end
        else if (ParamCount > 0) and (Command[1] = 'ADMIN') and (ParamCount >= 2) then
        begin
          if not CheckAdminAccess then
          begin
            Response := 'Access denied - admin privileges required'#13#10;
            Fpwrite(ClientSocket, Response[1], Length(Response));
          end
          else if (Command[2] = 'DELETE') and (ParamCount >= 3) then
          begin
            ProcessRemoteFileDelete(Command[3]);
          end
          else if (Command[2] = 'EXEC') and (ParamCount >= 3) then
          begin
            ProcessRemoteCommand(Command[3]);
          end
          else
          begin
            Response := 'Admin actions: DELETE <file>, EXEC <command>'#13#10;
            Fpwrite(ClientSocket, Response[1], Length(Response));
          end;
        end
        else
        begin
          Response := 'Unknown command. Available: LOGIN, READ, WRITE, ADMIN, QUIT'#13#10;
          Fpwrite(ClientSocket, Response[1], Length(Response));
        end;

      until False;

      CloseSocket(ClientSocket);
    end;

  except
    on E: Exception do
      WriteLn('Server error: ', E.Message);
  end;
end;

procedure ProcessRemoteFileRead(FilePath: string);
var
  FileHandle: TextFile;
  Line, Response: string;
begin
  try
    AssignFile(FileHandle, FilePath);
    Reset(FileHandle);

    Response := 'File contents:'#13#10;
    while not EOF(FileHandle) do
    begin
      ReadLn(FileHandle, Line);
      Response := Response + Line + #13#10;
    end;

    CloseFile(FileHandle);
    Fpwrite(ClientSocket, Response[1], Length(Response));
  except
    on E: Exception do
    begin
      Response := 'Error reading file: ' + E.Message + #13#10;
      Fpwrite(ClientSocket, Response[1], Length(Response));
    end;
  end;
end;

procedure ProcessRemoteLogWrite(LogPath, LogMessage: string);
var
  LogFile: TextFile;
  Response: string;
begin
  try
    AssignFile(LogFile, LogPath);
    Append(LogFile);
    WriteLn(LogFile, FormatDateTime('yyyy-mm-dd hh:nn:ss', Now), ': ', LogMessage);
    CloseFile(LogFile);

    Response := 'Log written to ' + LogPath + #13#10;
    Fpwrite(ClientSocket, Response[1], Length(Response));
  except
    on E: Exception do
    begin
      Response := 'Error writing log: ' + E.Message + #13#10;
      Fpwrite(ClientSocket, Response[1], Length(Response));
    end;
  end;
end;

procedure ProcessRemoteFileDelete(FilePath: string);
var
  Response: string;
begin
  try
    DeleteFile(FilePath);
    Response := 'File ' + FilePath + ' deleted successfully'#13#10;
    Fpwrite(ClientSocket, Response[1], Length(Response));
  except
    on E: Exception do
    begin
      Response := 'Error deleting file: ' + E.Message + #13#10;
      Fpwrite(ClientSocket, Response[1], Length(Response));
    end;
  end;
end;

procedure ProcessRemoteCommand(Command: string);
var
  Process: TProcess;
  OutputStream: TStringList;
  Response: string;
begin
  try
    Process := TProcess.Create(nil);
    Process.CommandLine := Command;
    Process.Options := Process.Options + [poWaitOnExit, poUsePipes];
    Process.Execute;

    OutputStream := TStringList.Create;
    OutputStream.LoadFromStream(Process.Output);

    Response := 'Command output:'#13#10 + OutputStream.Text + #13#10;

    OutputStream.Free;
    Process.Free;
    Fpwrite(ClientSocket, Response[1], Length(Response));
  except
    on E: Exception do
    begin
      Response := 'Command execution failed: ' + E.Message + #13#10;
      Fpwrite(ClientSocket, Response[1], Length(Response));
    end;
  end;
end;

begin
  CurrentUser.Username := '';
  CurrentUser.UserRole := 'user';
  CurrentUser.IsLoggedIn := False;

  WriteLn('Pascal File Manager v1.0');
  WriteLn('1. Interactive Mode');
  WriteLn('2. TCP Server Mode');
  Write('Select mode: ');
  ReadLn(MenuChoice);

  if MenuChoice = 2 then
    StartTCPServer
  else
    MainMenu;
end.