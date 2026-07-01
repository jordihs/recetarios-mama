; Instalador de Recetarios de Mamá para Windows
; Requiere Inno Setup 6.x  —  https://jrsoftware.org/isinfo.php
;
; Compilar desde la raíz del repositorio:
;   iscc build\installer.iss
; O usar el script auxiliar:
;   powershell -File build\build-windows.ps1 -BuildInstaller
;
; Prerequisito: el directorio dist\recetarios-mama\ debe existir ya
; (generado por build-windows.ps1 sin el flag -BuildInstaller).

#define AppName    "Recetarios de Mamá"
; AppVersion puede sobreescribirse desde la línea de comandos:
;   ISCC.exe /DAppVersion=1.2.3 installer.iss
#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif
#define AppExeName "recetarios.exe"
#define AppDefaultDir "C:\recetarios-mama"

[Setup]
AppId={{A3B4C5D6-E7F8-9012-BCDE-F12345678901}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher=Recetarios de Mamá
DefaultDirName={#AppDefaultDir}
DisableDirPage=no
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
OutputDir=..\dist
OutputBaseFilename=recetarios-mama-setup
SetupIconFile=..\frontend\windows\runner\resources\app_icon.ico
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ShowLanguageDialog=no
LanguageDetectionMethod=none
PrivilegesRequired=admin
MinVersion=10.0.17763
UninstallDisplayIcon={app}\{#AppExeName}
CloseApplications=yes

[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"

[Files]
Source: "..\dist\recetarios-mama\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"

[Run]
Filename: "{app}\{#AppExeName}"; Description: "Iniciar {#AppName}"; Flags: nowait postinstall skipifsilent
