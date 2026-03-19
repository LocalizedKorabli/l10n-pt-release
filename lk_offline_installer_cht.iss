#define MyAppName "澪刻繁體中文化離綫包"
#define MyAppInstallerName "澪刻繁體中文化離綫包"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "澪刻在地化"
#define MyAppPublisherURL "https://github.com/LocalizedKorabli"
#define MyAppSupportURL "https://github.com/OpenKorabli"

[Setup]
AppName={#MyAppName}
AppVersion=26.4.8844532.0
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppPublisherURL}
AppSupportURL={#MyAppSupportURL}
WizardImageFile=assets\wizard_zh.bmp
WizardSmallImageFile=assets\wizard_zh_small.bmp
DisableWelcomePage=no
DefaultDirName={tmp}
DisableDirPage=yes
DisableProgramGroupPage=yes
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
Uninstallable=no
SetupIconFile=assets\logo.ico
VersionInfoDescription={#MyAppName}

[Files]
Source: "Localizations\cht\*"; DestDir: "{tmp}\mods\res_mods"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "Shared\*"; DestDir: "{tmp}\mods"; Flags: ignoreversion recursesubdirs createallsubdirs

[Languages]
Name: "cht"; MessagesFile: "InstallerL10n\ChineseTraditional.isl"; InfoBeforeFile: "assets\welcome_cht.txt"; LicenseFile: "assets\license_cht.txt";
//Name: "english"; MessagesFile: "compiler:Default.isl"; InfoBeforeFile: "assets\welcome_en.txt"; LicenseFile: "assets\license.txt";
//Name: "russian"; MessagesFile: "compiler:Languages\Russian.isl"; InfoBeforeFile: "assets\welcome_ru.txt"; LicenseFile: "assets\license_ru.txt";

[CustomMessages]
cht.ErrorColon=錯誤：
cht.InvalidPreferencesError=無法讀取設定檔「%1」。%n請確保您已正確安裝 GameCenter。%n
cht.InstalledToDirsBelow=已安裝至以下目錄：%n%1
cht.BuildDirsNotFound=雖然已偵測到您的遊戲安裝路徑，但未能找到有效的遊戲版本資料夾。%n請檢查遊戲是否已完整安裝。
cht.ContactUsForHelp=如果您無法自行解決安裝問題，請加入澪刻在地化Discord群組（https://discord.gg/3d9k2mkWy4）以尋求協助。

[Code]
function GetInstallRootFromRegistry(): String;
begin
  if RegQueryStringValue(HKEY_CURRENT_USER, 'Software\Classes\lgc\DefaultIcon', '', Result) then
  begin
    if Pos(',', Result) > 0 then
      Result := Copy(Result, 1, Pos(',', Result) - 1);
    Result := ExtractFilePath(Result);
    Log('Registry path resolved to: ' + Result);
  end
  else
  begin
    Result := 'C:\ProgramData\Lesta\GameCenter\';
    Log('Registry key not found. Using fallback: ' + Result);
  end;
end;

function CheckGameInfo(filePath: String): Boolean;
var
  Lines: TArrayOfString;
  i: Integer;
  s: String;
begin
  Result := False;
  if not LoadStringsFromFile(filePath, Lines) then Exit;
  for i := 0 to GetArrayLength(Lines) - 1 do
  begin
    s := Trim(Lines[i]);
    if Pos('<id>', s) > 0 then
    begin
      StringChange(s, '<id>', '');
      StringChange(s, '</id>', '');
      if s = 'MK.RPT.PRODUCTION' then
      begin
        Result := True;
        Exit;
      end;
    end;
  end;
end;

function ExtractWorkingDirs(xmlPath: String; var dirs: TArrayOfString): Boolean;
var
  Lines: TArrayOfString;
  i, count: Integer;
  dir, msg: String;
begin
  Result := False;
  count := 0;
  msg := CustomMessage('ErrorColon');
  if not LoadStringsFromFile(xmlPath, Lines) then 
  begin
    msg := msg + FmtMessage(CustomMessage('InvalidPreferencesError'), [xmlPath]);
    MsgBox(
      msg,
      mbCriticalError,
      MB_OK
    )
    Exit;
  end;
  for i := 0 to GetArrayLength(Lines) - 1 do
  begin
    dir := Trim(Lines[i]);
    if Pos('<working_dir>', dir) > 0 then
    begin
      StringChange(dir, '<working_dir>', '');
      StringChange(dir, '</working_dir>', '');
      if FileExists(dir + '\game_info.xml') then
      begin
        if CheckGameInfo(dir + '\game_info.xml') then
        begin
          SetArrayLength(dirs, count + 1);
          dirs[count] := dir;
          count := count + 1;
        end;
      end;
    end;
  end;
  Result := count > 0;
end;

function IsNumericDir(name: String): Boolean;
var i: Integer;
begin
  Result := True;
  for i := 1 to Length(name) do
    if (name[i] < '0') or (name[i] > '9') then
    begin
      Result := False;
      Break;
    end;
end;

function DirHasResSubdir(path: String): Boolean;
begin
  Result := DirExists(path + '\res');
end;

procedure GetTopTwoValidNumericBinDirs(basePath: String; var dir1, dir2: String);
var
  binPath: String;
  FindRec: TFindRec;
  n, max1, max2: Integer;
  cur: String;
begin
  max1 := -1;
  max2 := -1;
  dir1 := '';
  dir2 := '';
  binPath := basePath + '\bin';
  if not DirExists(binPath) then Exit;

  if FindFirst(binPath + '\*', FindRec) then
  begin
    try
      repeat
        if ((FindRec.Attributes and FILE_ATTRIBUTE_DIRECTORY) <> 0) and
           (FindRec.Name <> '.') and (FindRec.Name <> '..') and IsNumericDir(FindRec.Name) then
        begin
          cur := binPath + '\' + FindRec.Name;
          if DirHasResSubdir(cur) then
          begin
            n := StrToInt(FindRec.Name);
            if n > max1 then
            begin
              max2 := max1;
              dir2 := dir1;
              max1 := n;
              dir1 := FindRec.Name;
            end
            else if n > max2 then
            begin
              max2 := n;
              dir2 := FindRec.Name;
            end;
          end;
        end;
      until not FindNext(FindRec);
    finally
      FindClose(FindRec);
    end;
  end;
end;

procedure CopyDirectoryTree(const SourceDir, TargetDir: string);
var
  FindRec: TFindRec;
  SourcePath, TargetPath: string;
begin
  if FindFirst(SourceDir + '\*', FindRec) then
  begin
    try
      repeat
        SourcePath := SourceDir + '\' + FindRec.Name;
        TargetPath := TargetDir + '\' + FindRec.Name;
        if FindRec.Attributes and FILE_ATTRIBUTE_DIRECTORY <> 0 then
        begin
          if (FindRec.Name <> '.') and (FindRec.Name <> '..') then
          begin
            ForceDirectories(TargetPath);
            CopyDirectoryTree(SourcePath, TargetPath); // recursive
          end;
        end
        else
        begin
          Log('Copying file: ' + SourcePath + ' -> ' + TargetPath);
          CopyFile(SourcePath, TargetPath, False);
        end;
      until not FindNext(FindRec);
    finally
      FindClose(FindRec);
    end;
  end;
end;


procedure CurStepChanged(CurStep: TSetupStep);
var
  basePath, xmlPath: String;
  gameDirs: TArrayOfString;
  i: Integer;
  d1, d2, target1, target2: String;
  installedDirs: String;
  msg: String;
begin
  if CurStep = ssPostInstall then
  begin
    installedDirs := '';
    basePath := GetInstallRootFromRegistry();
    xmlPath := basePath + 'preferences.xml';
    if ExtractWorkingDirs(xmlPath, gameDirs) then
    begin
      for i := 0 to GetArrayLength(gameDirs) - 1 do
      begin
        Log('Found valid working_dir: ' + gameDirs[i]);
        GetTopTwoValidNumericBinDirs(gameDirs[i], d1, d2);
        if d1 <> '' then
        begin
          target1 := gameDirs[i] + '\bin\' + d1;
          Log('Installing to: ' + target1);
          ForceDirectories(target1);
          CopyDirectoryTree(ExpandConstant('{tmp}\mods'), target1);
          installedDirs := installedDirs + target1 + #13#10;
        end;
        if d2 <> '' then
        begin
          target2 := gameDirs[i] + '\bin\' + d2;
          Log('Installing to: ' + target2);
          ForceDirectories(target2);
          CopyDirectoryTree(ExpandConstant('{tmp}\mods'), target2);
          installedDirs := installedDirs + target2 + #13#10;
        end;
      end;
      if installedDirs <> '' then
      begin
        installedDirs := Trim(installedDirs);
        msg := FmtMessage(CustomMessage('InstalledToDirsBelow'), [installedDirs]);
        MsgBox(
          msg, 
          mbInformation, 
          MB_OK
        );
      end
      else
      begin
        msg := CustomMessage('BuildDirsNotFound');
        MsgBox(
          msg, 
          mbError, 
          MB_OK
        );
      end;
    end
    else
      begin
      msg := CustomMessage('ContactUsForHelp');
      MsgBox(
        msg,
        mbCriticalError,
        MB_OK
      );
    end;
  end;
end;

