with Ada.Text_IO; use Ada.Text_IO;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Command_Line;
with GNAT.OS_Lib;

procedure Ada_App is

   type User_Record is record
      Username  : Unbounded_String;
      User_Role : Unbounded_String;
      Is_Logged : Boolean := False;
   end record;

   Current_User : User_Record;
   Menu_Choice  : Integer;
   Admin_Choice : Integer;

   procedure Display_Banner is
   begin
      Put_Line ("==========================================");
      Put_Line ("  ADA FILE MANAGER v1.0");
      Put_Line ("==========================================");
   end Display_Banner;

   procedure User_Login is
      Username_Input : String (1 .. 50);
      Role_Input     : String (1 .. 20);
      Username_Last  : Natural;
      Role_Last      : Natural;
   begin
      Put ("Enter username: ");
      Get_Line (Username_Input, Username_Last);
      Put ("Enter user role (user/admin): ");
      Get_Line (Role_Input, Role_Last);

      Current_User.Username := To_Unbounded_String (Username_Input (1 .. Username_Last));
      Current_User.User_Role := To_Unbounded_String (Role_Input (1 .. Role_Last));
      Current_User.Is_Logged := True;

      Put_Line ("Login successful for " & To_String (Current_User.Username) &
                " with role " & To_String (Current_User.User_Role));
   end User_Login;

   procedure Read_File_Content is
      File_Path_Input : String (1 .. 256);
      File_Path_Last  : Natural;
      Input_File      : File_Type;
      Line_Buffer     : String (1 .. 1024);
      Line_Last       : Natural;
   begin
      Put ("Enter file path: ");
      Get_Line (File_Path_Input, File_Path_Last);

      begin
         Open (Input_File, In_File, File_Path_Input (1 .. File_Path_Last));

         Put_Line ("File contents:");
         while not End_Of_File (Input_File) loop
            Get_Line (Input_File, Line_Buffer, Line_Last);
            Put_Line (Line_Buffer (1 .. Line_Last));
         end loop;

         Close (Input_File);
      exception
         when Name_Error =>
            Put_Line ("Error: File not found - " & File_Path_Input (1 .. File_Path_Last));
         when others =>
            Put_Line ("Error reading file");
      end;
   end Read_File_Content;

   procedure Write_Log_Entry is
      Log_Path_Input  : String (1 .. 256);
      Log_Msg_Input   : String (1 .. 512);
      Log_Path_Last   : Natural;
      Log_Msg_Last    : Natural;
      Log_File        : File_Type;
   begin
      Put ("Enter log file path: ");
      Get_Line (Log_Path_Input, Log_Path_Last);
      Put ("Enter log message: ");
      Get_Line (Log_Msg_Input, Log_Msg_Last);

      begin
         Open (Log_File, Append_File, Log_Path_Input (1 .. Log_Path_Last));
         Put_Line (Log_File, "[LOG] " & Log_Msg_Input (1 .. Log_Msg_Last));
         Close (Log_File);
         Put_Line ("Log written to " & Log_Path_Input (1 .. Log_Path_Last));
      exception
         when Name_Error =>
            Create (Log_File, Out_File, Log_Path_Input (1 .. Log_Path_Last));
            Put_Line (Log_File, "[LOG] " & Log_Msg_Input (1 .. Log_Msg_Last));
            Close (Log_File);
            Put_Line ("Log file created and written to " & Log_Path_Input (1 .. Log_Path_Last));
         when others =>
            Put_Line ("Error writing to log file");
      end;
   end Write_Log_Entry;

   function Check_Admin_Access return Boolean is
      Role_String : String := To_String (Current_User.User_Role);
      User_String : String := To_String (Current_User.Username);
   begin
      if Role_String = "admin" or else
         Role_String = "administrator" or else
         User_String = "admin" then
         return True;
      else
         return False;
      end if;
   end Check_Admin_Access;

   procedure Delete_File_Unsafe is
      File_Path_Input : String (1 .. 256);
      File_Path_Last  : Natural;
      Confirm_Input   : String (1 .. 10);
      Confirm_Last    : Natural;
      Success         : Boolean;
   begin
      Put ("Enter file path to delete: ");
      Get_Line (File_Path_Input, File_Path_Last);
      Put ("Confirm deletion (yes/no): ");
      Get_Line (Confirm_Input, Confirm_Last);

      if Confirm_Input (1 .. Confirm_Last) = "yes" then
         GNAT.OS_Lib.Delete_File (File_Path_Input (1 .. File_Path_Last), Success);
         if Success then
            Put_Line ("File deleted successfully: " & File_Path_Input (1 .. File_Path_Last));
         else
            Put_Line ("Error deleting file: " & File_Path_Input (1 .. File_Path_Last));
         end if;
      else
         Put_Line ("File deletion cancelled");
      end if;
   end Delete_File_Unsafe;

   procedure Execute_System_Command is
      Command_Input : String (1 .. 512);
      Command_Last  : Natural;
      Result        : Integer;
   begin
      Put ("Enter system command: ");
      Get_Line (Command_Input, Command_Last);

      Put_Line ("Executing command: " & Command_Input (1 .. Command_Last));
      Result := GNAT.OS_Lib.Spawn (Program_Name => "/bin/sh",
                                   Args => (new String'("-c"),
                                           new String'(Command_Input (1 .. Command_Last))));

      if Result = 0 then
         Put_Line ("Command executed successfully");
      else
         Put_Line ("Command execution failed with code" & Integer'Image (Result));
      end if;
   end Execute_System_Command;

   procedure View_Sensitive_File is
      File_Path_Input : String (1 .. 256);
      File_Path_Last  : Natural;
      Sensitive_File  : File_Type;
      Line_Buffer     : String (1 .. 1024);
      Line_Last       : Natural;
   begin
      Put ("Enter sensitive file path: ");
      Get_Line (File_Path_Input, File_Path_Last);

      begin
         Open (Sensitive_File, In_File, File_Path_Input (1 .. File_Path_Last));

         Put_Line ("Sensitive file contents:");
         while not End_Of_File (Sensitive_File) loop
            Get_Line (Sensitive_File, Line_Buffer, Line_Last);
            Put_Line (Line_Buffer (1 .. Line_Last));
         end loop;

         Close (Sensitive_File);
      exception
         when Name_Error =>
            Put_Line ("Error: Sensitive file not found - " & File_Path_Input (1 .. File_Path_Last));
         when others =>
            Put_Line ("Error reading sensitive file");
      end;
   end View_Sensitive_File;

   procedure Admin_Panel is
   begin
      loop
         New_Line;
         Put_Line ("=== ADMIN PANEL ===");
         Put_Line ("1. Delete File");
         Put_Line ("2. Execute System Command");
         Put_Line ("3. View Sensitive File");
         Put_Line ("9. Back to Main Menu");
         Put ("Admin choice: ");
         Get (Admin_Choice);
         Skip_Line;

         case Admin_Choice is
            when 1 => Delete_File_Unsafe;
            when 2 => Execute_System_Command;
            when 3 => View_Sensitive_File;
            when 9 => exit;
            when others => Put_Line ("Invalid admin option");
         end case;
      end loop;
   end Admin_Panel;

begin
   Display_Banner;

   loop
      New_Line;
      Put_Line ("1. User Login");
      Put_Line ("2. Read File");
      Put_Line ("3. Write Log");
      Put_Line ("4. Admin Panel");
      Put_Line ("9. Exit");
      Put ("Enter choice: ");
      Get (Menu_Choice);
      Skip_Line;

      case Menu_Choice is
         when 1 => User_Login;
         when 2 => Read_File_Content;
         when 3 => Write_Log_Entry;
         when 4 =>
            if Check_Admin_Access then
               Admin_Panel;
            else
               Put_Line ("Access denied - admin privileges required");
            end if;
         when 9 =>
            Put_Line ("Goodbye!");
            exit;
         when others =>
            Put_Line ("Invalid choice");
      end case;
   end loop;

end Ada_App;