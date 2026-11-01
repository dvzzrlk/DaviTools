!ifdef BUILD_UNINSTALLER
  Var uninstallCleanupStatus
  Var uninstallCleanupExitCode
!endif

!macro customUnInit
  StrCpy $uninstallCleanupStatus "1"
  ${ifNot} ${isUpdated}
    ${if} $installMode == "all"
      SetShellVarContext current
    ${endif}

    CreateDirectory "$PLUGINSDIR"
    ClearErrors
    CopyFiles /SILENT "$INSTDIR\resources\uninstall-cleanup.ps1" "$PLUGINSDIR"
    IfErrors uninstallCleanupPrepareFailed
    ExecWait '"$SYSDIR\WindowsPowerShell\v1.0\powershell.exe" -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$PLUGINSDIR\uninstall-cleanup.ps1" -Mode Prepare -AppDataPath "$APPDATA" -TargetsFile "$PLUGINSDIR\uninstall-targets.txt"' $uninstallCleanupStatus
uninstallCleanupPrepareFailed:

    ${if} $installMode == "all"
      SetShellVarContext all
    ${endif}
  ${endif}
!macroend

!macro customUnInstall
  ${ifNot} ${isUpdated}
    ${if} $installMode == "all"
      SetShellVarContext current
    ${endif}

    ${if} $uninstallCleanupStatus == "0"
      ExecWait '"$SYSDIR\WindowsPowerShell\v1.0\powershell.exe" -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$PLUGINSDIR\uninstall-cleanup.ps1" -Mode Cleanup -AppDataPath "$APPDATA" -TargetsFile "$PLUGINSDIR\uninstall-targets.txt"' $uninstallCleanupExitCode
      ${if} $uninstallCleanupExitCode != 0
        MessageBox MB_OK|MB_ICONEXCLAMATION "Cleanup of some custom backups or files failed. Check the configured paths before removing them manually."
      ${endif}
    ${else}
      MessageBox MB_OK|MB_ICONEXCLAMATION "Could not prepare cleanup of custom backups or files. Installed files and default data will be removed; check external folders manually."
    ${endif}

    ${if} $installMode == "all"
      SetShellVarContext all
    ${endif}
  ${endif}
!macroend
