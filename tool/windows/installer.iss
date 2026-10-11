; Inno Setup script for the PocketTally Windows installer.
; Built in GitHub Actions, see .github/workflows/build.yml:
;   iscc /DAppVersion=0.7.0 /DSourceDir=...\Release /DOutputName=... installer.iss
;
; Installs for the current user only (no admin rights needed), so the
; in-app updater can run it silently.

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#ifndef SourceDir
  #define SourceDir "..\..\build\windows\x64\runner\Release"
#endif
#ifndef OutputName
  #define OutputName "pockettally-windows-setup"
#endif

[Setup]
; Never change AppId: Windows uses it to recognise updates of this app.
AppId={{AFDD84C0-6F74-49AB-B735-FC61A84F7023}
AppName=PocketTally
AppVersion={#AppVersion}
AppVerName=PocketTally {#AppVersion}
AppPublisher=Lumio Apps
AppPublisherURL=https://github.com/lumio-apps/pockettally
AppSupportURL=https://github.com/lumio-apps/pockettally/issues
AppUpdatesURL=https://github.com/lumio-apps/pockettally/releases
DefaultDirName={localappdata}\Programs\PocketTally
DisableDirPage=auto
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
OutputBaseFilename={#OutputName}
SetupIconFile=..\..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\pockettally.exe
UninstallDisplayName=PocketTally
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
; Close a running PocketTally before replacing its files.
CloseApplications=force
RestartApplications=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\PocketTally"; Filename: "{app}\pockettally.exe"
Name: "{autodesktop}\PocketTally"; Filename: "{app}\pockettally.exe"; Tasks: desktopicon

[Run]
; Also runs after a silent update from inside the app, so it opens again.
Filename: "{app}\pockettally.exe"; Description: "{cm:LaunchProgram,PocketTally}"; Flags: nowait postinstall
