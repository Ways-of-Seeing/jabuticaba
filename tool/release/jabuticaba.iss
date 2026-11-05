; Instalador do jabuticaba para Windows (Inno Setup 6).
; Compilado pelo workflow de release: ISCC /DAppVersion=0.1.0 tool\release\jabuticaba.iss

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif

[Setup]
AppId={{4AF913BC-48E5-4F99-8E00-DB7A5200A631}
AppName=jabuticaba
AppVersion={#AppVersion}
AppPublisher=Ways of Seeing
AppPublisherURL=https://ways-of-seeing.github.io/jabuticaba/
AppSupportURL=https://github.com/Ways-of-Seeing/jabuticaba/issues
DefaultDirName={autopf}\jabuticaba
DefaultGroupName=jabuticaba
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=..\..
OutputBaseFilename=jabuticaba-windows-instalador
SetupIconFile=..\..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\jabuticaba.exe
LicenseFile=..\..\LICENSE
Compression=lzma2
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "brazilianportuguese"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\jabuticaba"; Filename: "{app}\jabuticaba.exe"
Name: "{autodesktop}\jabuticaba"; Filename: "{app}\jabuticaba.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\jabuticaba.exe"; Description: "{cm:LaunchProgram,jabuticaba}"; Flags: nowait postinstall skipifsilent
