; Script generated for Cyber Owl 2.0
; Placed in Root Directory to avoid being deleted by build scripts

[Setup]
AppName=Cyber Owl
AppVersion=2.0
AppPublisher=Cyber Owl Defense System
DefaultDirName={autopf}\Cyber Owl
DefaultGroupName=Cyber Owl
OutputDir=dist
OutputBaseFilename=CyberOwl_Installer_Complete
SetupIconFile=main_login_system\main_login_system\windows\runner\resources\app_icon.ico
Compression=lzma2
SolidCompression=yes
PrivilegesRequired=admin
ArchitecturesInstallIn64BitMode=x64
Password=CyberOwl4
Encryption=yes
WizardStyle=modern
WizardResizable=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Dirs]
Name: "{app}"; Permissions: users-full

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; 1. Copy the App Icon explicitly
Source: "main_login_system\main_login_system\windows\runner\resources\app_icon.ico"; DestDir: "{app}"; Flags: ignoreversion

; 2. Copy the User Customization Guide
Source: "USER_CUSTOMIZATION_GUIDE.md"; DestDir: "{app}"; Flags: ignoreversion

; 3. Copy the entire Setup content from the Staging Folder (CyberOwl_setup)
; NOTE: Ensure 'CyberOwl_setup' is populated (run build_installer.py or sync files) before compiling this.
Source: "CyberOwl_setup\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs; Excludes: "*.iss,*.zip,*.pyc,__pycache__,.git,node_modules,CyberOwl_Complete_Installer.iss"

[Icons]
; Desktop Shortcut
Name: "{autodesktop}\Cyber Owl"; Filename: "{app}\bin\main_login_system.exe"; IconFilename: "{app}\app_icon.ico"; Tasks: desktopicon

; Start Menu Shortcuts
Name: "{group}\Cyber Owl"; Filename: "{app}\bin\main_login_system.exe"; IconFilename: "{app}\app_icon.ico"
Name: "{group}\Uninstall Cyber Owl"; Filename: "{uninstallexe}"

[Run]
; Auto-launch after installation
Filename: "{app}\bin\main_login_system.exe"; Description: "{cm:LaunchProgram,Cyber Owl}"; Flags: nowait postinstall skipifsilent

[Code]
function InitializeUninstall(): Boolean;
var
  PasswordForm: TSetupForm;
  PasswordLabel: TNewStaticText;
  PasswordEdit: TNewEdit;
  OKButton: TNewButton;
  CancelButton: TNewButton;
begin
  Result := False;
  
  // Create a modal form
  PasswordForm := TSetupForm.Create(nil);
  try
    PasswordForm.ClientWidth := 400;
    PasswordForm.ClientHeight := 150;
    PasswordForm.Caption := 'Uninstall Protection';
    PasswordForm.Position := poScreenCenter;
    
    PasswordLabel := TNewStaticText.Create(PasswordForm);
    PasswordLabel.Parent := PasswordForm;
    PasswordLabel.Top := 20;
    PasswordLabel.Left := 20;
    PasswordLabel.Width := PasswordForm.ClientWidth - 40;
    PasswordLabel.Caption := 'Please enter the administrative password to uninstall Cyber Owl:';
    
    PasswordEdit := TNewEdit.Create(PasswordForm);
    PasswordEdit.Parent := PasswordForm;
    PasswordEdit.Top := PasswordLabel.Top + PasswordLabel.Height + 16;
    PasswordEdit.Left := 20;
    PasswordEdit.Width := PasswordForm.ClientWidth - 40;
    PasswordEdit.PasswordChar := '*';
    PasswordEdit.Text := '';
    
    OKButton := TNewButton.Create(PasswordForm);
    OKButton.Parent := PasswordForm;
    OKButton.Top := PasswordForm.ClientHeight - 40;
    OKButton.Left := PasswordForm.ClientWidth - 180;
    OKButton.Width := 75;
    OKButton.Height := 25;
    OKButton.Caption := 'OK';
    OKButton.ModalResult := mrOK;
    OKButton.Default := True;
    
    CancelButton := TNewButton.Create(PasswordForm);
    CancelButton.Parent := PasswordForm;
    CancelButton.Top := OKButton.Top;
    CancelButton.Left := OKButton.Left + 90;
    CancelButton.Width := 75;
    CancelButton.Height := 25;
    CancelButton.Caption := 'Cancel';
    CancelButton.ModalResult := mrCancel;
    CancelButton.Cancel := True;
    
    PasswordForm.ActiveControl := PasswordEdit;
    
    if PasswordForm.ShowModal() = mrOK then
    begin
       if PasswordEdit.Text = 'CyberOwl4' then
       begin
         Result := True;
       end
       else
       begin
         MsgBox('Incorrect password. Uninstall canceled.', mbCriticalError, MB_OK);
         Result := False;
       end;
    end;
  finally
    PasswordForm.Free;
  end;
end;
