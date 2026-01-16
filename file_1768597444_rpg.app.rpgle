**FREE

ctl-opt main(main) decedit('0,') datfmt(*iso);

dcl-f DISPLAY workstn sfile(sfl01:rrn01);

dcl-ds userSession template qualified;
  username char(20);
  userLevel char(10);
  isLoggedIn ind;
end-ds;

dcl-s currentUser likeds(userSession);
dcl-s fileName varchar(256);
dcl-s filePath varchar(512);
dcl-s fileData varchar(32000);
dcl-s adminCommand varchar(100);
dcl-s rrn01 packed(4: 0);

dcl-proc main;
  dcl-pi *n end-pi;

  dow '1' = '1';
    exfmt MAINMENU;

    select;
      when menuOption = '1';
        performLogin();
      when menuOption = '2';
        readFileData();
      when menuOption = '3';
        if checkAdminAccess();
          adminPanel();
        else;
          message = 'Access denied - admin only';
        endif;
      when menuOption = '4';
        writeLogFile();
      when menuOption = '9';
        leave;
    endsl;
  enddo;

end-proc;

dcl-proc performLogin;
  dcl-pi *n end-pi;

  exfmt LOGINSCR;

  currentUser.username = %trim(loginUser);
  currentUser.userLevel = %trim(userLevel);

  if currentUser.username <> '';
    currentUser.isLoggedIn = *on;
    message = 'Login successful for ' + %trim(currentUser.username);
  else;
    message = 'Login failed';
  endif;

end-proc;

dcl-proc readFileData;
  dcl-pi *n end-pi;

  dcl-s inputFile varchar(256);
  dcl-s fullPath varchar(512);
  dcl-s fileHandle int(10);
  dcl-s bytesRead int(10);
  dcl-s buffer char(1024);

  exfmt FILEREAD;

  inputFile = %trim(fileToRead);

  fullPath = '/QSYS.LIB/QGPL.LIB/' + inputFile;

  monitor;
    fileHandle = open(%trim(fullPath): O_RDONLY);
    if fileHandle >= 0;
      bytesRead = read(fileHandle: %addr(buffer): %size(buffer));
      if bytesRead > 0;
        fileContent = %subst(buffer: 1: bytesRead);
        message = 'File read successfully';
      else;
        message = 'Error reading file';
      endif;
      callp close(fileHandle);
    else;
      message = 'Could not open file';
    endif;
  on-error;
    message = 'File operation error';
  endmon;

end-proc;

dcl-proc checkAdminAccess;
  dcl-pi *n ind end-pi;

  if currentUser.userLevel = 'ADMIN' or
     currentUser.userLevel = 'SYSADM' or
     currentUser.username = 'ADMIN';
    return *on;
  endif;

  return *off;

end-proc;

dcl-proc adminPanel;
  dcl-pi *n end-pi;

  dow '1' = '1';
    exfmt ADMINMENU;

    select;
      when adminOption = '1';
        deleteUserFile();
      when adminOption = '2';
        executeSystemCommand();
      when adminOption = '9';
        leave;
    endsl;
  enddo;

end-proc;

dcl-proc deleteUserFile;
  dcl-pi *n end-pi;

  dcl-s targetFile varchar(256);
  dcl-s deleteCommand varchar(512);

  exfmt DELETESCREEN;

  targetFile = %trim(fileToDelete);
  deleteCommand = 'DLTF FILE(' + targetFile + ')';

  monitor;
    system(deleteCommand);
    message = 'File ' + targetFile + ' deleted successfully';
  on-error;
    message = 'Error deleting file';
  endmon;

end-proc;

dcl-proc executeSystemCommand;
  dcl-pi *n end-pi;

  dcl-s sysCommand varchar(256);
  dcl-s cmdResult int(10);

  exfmt COMMANDSCREEN;

  sysCommand = %trim(systemCommand);

  monitor;
    cmdResult = system(sysCommand);
    if cmdResult = 0;
      message = 'Command executed successfully';
    else;
      message = 'Command execution failed';
    endif;
  on-error;
    message = 'System command error';
  endmon;

end-proc;

dcl-proc writeLogFile;
  dcl-pi *n end-pi;

  dcl-s logFileName varchar(256);
  dcl-s logMessage varchar(512);
  dcl-s logPath varchar(512);
  dcl-s fileHandle int(10);
  dcl-s logEntry varchar(1024);

  exfmt LOGSCREEN;

  logFileName = %trim(logFile);
  logMessage = %trim(logText);

  logPath = '/tmp/' + logFileName;
  logEntry = %char(%timestamp()) + ': ' + logMessage + x'0D25';

  monitor;
    fileHandle = open(%trim(logPath): O_WRONLY + O_CREAT + O_APPEND:
                      S_IRUSR + S_IWUSR);
    if fileHandle >= 0;
      write(fileHandle: %addr(logEntry): %len(%trim(logEntry)));
      callp close(fileHandle);
      message = 'Log written to ' + logPath;
    else;
      message = 'Could not create log file';
    endif;
  on-error;
    message = 'Log write error';
  endmon;

end-proc;

dcl-pr system int(10) extproc('system');
  command pointer value options(*string);
end-pr;

dcl-pr open int(10) extproc('open');
  path pointer value options(*string);
  flags int(10) value;
  mode int(10) value options(*nopass);
end-pr;

dcl-pr read int(10) extproc('read');
  handle int(10) value;
  buffer pointer value;
  bytes int(10) value;
end-pr;

dcl-pr write int(10) extproc('write');
  handle int(10) value;
  buffer pointer value;
  bytes int(10) value;
end-pr;

dcl-pr close int(10) extproc('close');
  handle int(10) value;
end-pr;

dcl-c O_RDONLY 0;
dcl-c O_WRONLY 1;
dcl-c O_CREAT 64;
dcl-c O_APPEND 8;
dcl-c S_IRUSR 256;
dcl-c S_IWUSR 128;