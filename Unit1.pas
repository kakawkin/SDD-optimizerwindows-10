unit Unit1;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Registry;

type
  TForm1 = class(TForm)
    CheckBox1: TCheckBox;
    CheckBox2: TCheckBox;
    CheckBox3: TCheckBox;
    CheckBox4: TCheckBox;
    CheckBox5: TCheckBox;
    CheckBox6: TCheckBox;
    Button1: TButton;
    CheckBox7: TCheckBox;
    CheckBox8: TCheckBox;
    Label1: TLabel;
    Label2: TLabel;
    procedure FormCreate(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  Form1: TForm1;

implementation

{$R *.dfm}

function HibernateAllowed: Boolean;
 type
   TIsPwrHibernateAllowed = function: Boolean;
   stdcall;
 var
   hPowrprof: HMODULE;
   IsPwrHibernateAllowed: TIsPwrHibernateAllowed;
 begin
   Result := False;
   hPowrprof := LoadLibrary('powrprof.dll');
   if hPowrprof <> 0 then
   begin
     try
       @IsPwrHibernateAllowed := GetProcAddress(hPowrprof, 'IsPwrHibernateAllowed');
       if @IsPwrHibernateAllowed <> nil then
       begin
         Result := IsPwrHibernateAllowed;
       end;
     finally
       FreeLibrary(hPowrprof);
     end;
   end;
 end;

function GetDosOutput(CommandLine: string; Work: string = 'C:\'): string;  { Run a DOS program and retrieve its output dynamically while it is running. }
var
  SecAtrrs: TSecurityAttributes;
  StartupInfo: TStartupInfo;
  ProcessInfo: TProcessInformation;
  StdOutPipeRead, StdOutPipeWrite: THandle;
  WasOK: Boolean;
  pCommandLine: array[0..255] of AnsiChar;
  BytesRead: Cardinal;
  WorkDir: string;
  Handle: Boolean;
begin
  Result := '';
  with SecAtrrs do begin
    nLength := SizeOf(SecAtrrs);
    bInheritHandle := True;
    lpSecurityDescriptor := nil;
  end;
  CreatePipe(StdOutPipeRead, StdOutPipeWrite, @SecAtrrs, 0);
  try
    with StartupInfo do
    begin
      FillChar(StartupInfo, SizeOf(StartupInfo), 0);
      cb := SizeOf(StartupInfo);
      dwFlags := STARTF_USESHOWWINDOW or STARTF_USESTDHANDLES;
      wShowWindow := SW_HIDE;
      hStdInput := GetStdHandle(STD_INPUT_HANDLE); // don't redirect stdin
      hStdOutput := StdOutPipeWrite;
      hStdError := StdOutPipeWrite;
    end;
    WorkDir := Work;
    Handle := CreateProcess(nil, PChar('cmd.exe /C ' + CommandLine),
                            nil, nil, True, 0, nil,
                            PChar(WorkDir), StartupInfo, ProcessInfo);
    CloseHandle(StdOutPipeWrite);
    if Handle then
      try
        repeat
          WasOK := ReadFile(StdOutPipeRead, pCommandLine, 255, BytesRead, nil);

          if BytesRead > 0 then
          begin
            pCommandLine[BytesRead] := #0;
            Result := Result + pCommandLine;
          end;
        until not WasOK or (BytesRead = 0);
        WaitForSingleObject(ProcessInfo.hProcess, INFINITE);
      finally
        CloseHandle(ProcessInfo.hThread);
        CloseHandle(ProcessInfo.hProcess);
      end;
  finally
    CloseHandle(StdOutPipeRead);
  end;
end;

procedure TForm1.Button1Click(Sender: TObject);
var tmp:string;
    Reg : TRegistry;
begin
  if checkbox1.Checked=true then tmp:=GetDosOutput('fsutil behavior set disabledeletenotify 0');
  if checkbox2.Checked=true then
   begin
     Reg := TRegistry.Create;
     Reg.RootKey:=HKEY_LOCAL_MACHINE;
     Reg.OpenKey('SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters',true);
     Reg.WriteInteger('EnablePrefetcher',0);
     Reg.WriteInteger('EnableSuperfetch',0);
     Reg.CloseKey;
     Reg.Free;
   end;
  if checkbox3.Checked=true then tmp:=GetDosOutput('sc config SysMain start=disabled');
  if checkbox4.Checked=true then tmp:=GetDosOutput('sc config WSearch start=disabled');
  if checkbox5.Checked=true then
    begin
      Reg := TRegistry.Create;
      Reg.RootKey:=HKEY_LOCAL_MACHINE;
      Reg.OpenKey('SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management',true);
      Reg.WriteInteger('ClearPageFileAtShutdown',0);
      reg.CloseKey;
      reg.Free;
    end;
  if checkbox6.Checked=true then
    begin
      Reg := TRegistry.Create;
      Reg.RootKey:=HKEY_LOCAL_MACHINE;
      Reg.OpenKey('SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management',true);
      Reg.WriteInteger('LargeSystemCache',0);
      reg.CloseKey;
      reg.Free;
    end;
  if checkbox7.Enabled=true then tmp:=GetDosOutput('powercfg /h off');
  if checkbox8.Enabled=true then
    begin
      Reg := TRegistry.Create;
      Reg.RootKey:=HKEY_CURRENT_USER;
      Reg.OpenKey('Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy',true);
      Reg.WriteInteger('01',00000001);
      Reg.WriteInteger('1024',00000001);
      Reg.WriteInteger('2048',00000007);
      reg.CloseKey;
      reg.Free;
    end;
end;

procedure TForm1.Button2Click(Sender: TObject);
begin
  if HibernateAllowed=true then showmessage('1');


end;

procedure TForm1.FormCreate(Sender: TObject);
var list:TStringList;
    s:string;
    Reg : TRegistry;
    i:integer;
begin
  //---***
  list:=TStringList.Create;
  list.Text:=GetDosOutput('fsutil behavior query disabledeletenotify'); s:=list.Strings[0];
  if s[28]='0' then CheckBox1.Enabled:=false;
  list.Free;
  //---***
  Reg := TRegistry.Create;
  Reg.RootKey:=HKEY_LOCAL_MACHINE;
  Reg.OpenKeyReadOnly('SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters');
  i:= Reg.ReadInteger('EnablePrefetcher');
  if i=0 then CheckBox2.Enabled:=false;
  Reg.CloseKey;
  Reg.Free;
  //---***
  list:=TStringList.Create;
  list.Text:=GetDosOutput('sc query SysMain'); s:=list.Strings[3]; if not(Pos('1',s)=0) then CheckBox3.Enabled:=false;
  list.Text:=GetDosOutput('sc query WSearch'); s:=list.Strings[3]; if not(Pos('1',s)=0) then CheckBox4.Enabled:=false;
  list.Free;
  //---***
  Reg := TRegistry.Create;
  Reg.RootKey:=HKEY_LOCAL_MACHINE;
  Reg.OpenKeyReadOnly('SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management');
  i:= Reg.ReadInteger('LargeSystemCache');
  if i=0 then CheckBox5.Enabled:=false;
  i:= Reg.ReadInteger('ClearPageFileAtShutdown');
  if i=0 then CheckBox6.Enabled:=false;
  reg.CloseKey;
  reg.Free;
  ///---***
  if HibernateAllowed=false then checkbox7.Enabled:=false;
  ///---***
  Reg := TRegistry.Create;
  Reg.RootKey:=HKEY_CURRENT_USER;
  if Reg.OpenKeyReadOnly('Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy') then
    begin
      if Reg.ValueExists('01') then
        begin
          i:=Reg.ReadInteger('01');
          if i=1 then checkbox8.Enabled:=false;
        end;
    end;
  //---***
  if GetUserDefaultLCID<>1049 then
    begin
      CheckBox1.Caption:='Activate TRIM';
      CheckBox2.Caption:='Disable Prefetch è Superfetch';
      CheckBox3.Caption:='Disable Superfetch service';
      CheckBox4.Caption:='Disable Windows Search service';
      CheckBox5.Caption:='Disable LargeSystemCache';
      CheckBox6.Caption:='Disable ClearPageFileAtShutdown';
      CheckBox7.Caption:='Disable hibernation';
      CheckBox8.Caption:='Enable Disk Cleanup';
      Button1.Caption:='Start';
      Label1.Caption:='If one of the options is not active, you already have this tweak in the system.';
    end;

end;

end.
