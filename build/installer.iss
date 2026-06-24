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

[CustomMessages]
; Página: tipo de instalación
spanish.TipoInstalacion=Tipo de instalación
spanish.TipoInstalacionSub=Elija cómo desea instalar {#AppName}.
spanish.InstPredeterminada=Instalación predeterminada (recomendada)
spanish.InstPersonalizada=Instalación personalizada

; Página: opciones adicionales (solo instalación personalizada)
spanish.OpcionesTitle=Opciones adicionales
spanish.OpcionesSub=Seleccione las opciones que desea aplicar.
spanish.OptAtajo=Crear acceso directo en el Escritorio
spanish.OptImportar=Importar la biblioteca de recetas (biblioteca.recetarios)

; Mensajes durante la instalación
spanish.ImportandoDB=Importando la biblioteca de recetas, por favor espere...

[Files]
; Archivos de la aplicación
Source: "..\dist\recetarios-mama\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

; Base de datos de recetas — se elimina del directorio de instalación tras importar
Source: "..\database\biblioteca.recetarios"; DestDir: "{app}"; Flags: ignoreversion deleteafterinstall

; Script auxiliar de importación — se elimina tras la instalación
Source: "import_biblioteca.ps1"; DestDir: "{app}"; Flags: ignoreversion deleteafterinstall

[Icons]
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Check: ShouldCreateShortcut

[Run]
Filename: "{app}\{#AppExeName}"; Description: "Iniciar {#AppName}"; Flags: nowait postinstall skipifsilent

[Code]

var
  TypePage:    TInputOptionWizardPage;
  OptionsPage: TInputOptionWizardPage;

{ ---------------------------------------------------------------- helpers }

function IsDefaultInstall: Boolean;
begin
  Result := TypePage.Values[0];
end;

function ShouldCreateShortcut: Boolean;
begin
  Result := IsDefaultInstall or OptionsPage.Values[0];
end;

function ShouldImportDB: Boolean;
begin
  Result := IsDefaultInstall or OptionsPage.Values[1];
end;

{ ---------------------------------------------------------------- wizard setup }

procedure InitializeWizard;
begin
  { Página "Tipo de instalación" — aparece justo después de la bienvenida }
  TypePage := CreateInputOptionPage(
    wpWelcome,
    CustomMessage('TipoInstalacion'),
    CustomMessage('TipoInstalacionSub'),
    '', False, False);
  TypePage.Add(CustomMessage('InstPredeterminada'));
  TypePage.Add(CustomMessage('InstPersonalizada'));
  TypePage.Values[0] := True;

  { Página "Opciones adicionales" — aparece solo en instalación personalizada,
    insertada tras la página de selección de directorio }
  OptionsPage := CreateInputOptionPage(
    wpSelectDir,
    CustomMessage('OpcionesTitle'),
    CustomMessage('OpcionesSub'),
    '', False, True);
  OptionsPage.Add(CustomMessage('OptAtajo'));
  OptionsPage.Add(CustomMessage('OptImportar'));
  OptionsPage.Values[0] := True;
  OptionsPage.Values[1] := True;
end;

{ En instalación predeterminada se omiten la selección de carpeta y las opciones }
function ShouldSkipPage(PageID: Integer): Boolean;
begin
  Result := IsDefaultInstall and
            ((PageID = wpSelectDir) or (PageID = OptionsPage.ID));
end;

{ ---------------------------------------------------------------- installation step }

procedure CurStepChanged(CurStep: TSetupStep);
var
  ResultCode: Integer;
  PsArgs:     String;
begin
  if (CurStep = ssPostInstall) and ShouldImportDB then
  begin
    WizardForm.StatusLabel.Caption := CustomMessage('ImportandoDB');
    WizardForm.Update;

    PsArgs := Format(
      '-NonInteractive -ExecutionPolicy Bypass -File "%s"' +
      ' -BackendExe "%s" -DbFile "%s" -DataDir "%s"',
      [ExpandConstant('{app}\import_biblioteca.ps1'),
       ExpandConstant('{app}\backend\recetarios.exe'),
       ExpandConstant('{app}\biblioteca.recetarios'),
       ExpandConstant('{localappdata}\recetarios-mama')]);

    Exec('powershell.exe', PsArgs, '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  end;
end;
