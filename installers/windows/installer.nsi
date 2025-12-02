; Echoelmusic Windows Installer
; NSIS Script

!include "MUI2.nsh"
!include "FileFunc.nsh"

; ============================================
; General Settings
; ============================================

Name "Echoelmusic"
OutFile "Echoelmusic-Windows-Setup.exe"
InstallDir "$PROGRAMFILES64\Echoelmusic"
InstallDirRegKey HKLM "Software\Echoelmusic" "Install_Dir"
RequestExecutionLevel admin

; ============================================
; Interface Settings
; ============================================

!define MUI_ABORTWARNING
!define MUI_ICON "..\..\Resources\icon.ico"
!define MUI_UNICON "..\..\Resources\icon.ico"
!define MUI_WELCOMEFINISHPAGE_BITMAP "..\..\Resources\installer-banner.bmp"

; ============================================
; Pages
; ============================================

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE "..\..\LICENSE"
!insertmacro MUI_PAGE_COMPONENTS
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "English"

; ============================================
; Installer Sections
; ============================================

Section "Echoelmusic Standalone" SecStandalone
    SectionIn RO  ; Required

    SetOutPath "$INSTDIR"
    File "..\..\Sources\Desktop\build\Release\Echoelmusic_Standalone.exe"

    ; Create shortcuts
    CreateDirectory "$SMPROGRAMS\Echoelmusic"
    CreateShortcut "$SMPROGRAMS\Echoelmusic\Echoelmusic.lnk" "$INSTDIR\Echoelmusic_Standalone.exe"
    CreateShortcut "$DESKTOP\Echoelmusic.lnk" "$INSTDIR\Echoelmusic_Standalone.exe"

    ; Write uninstaller
    WriteUninstaller "$INSTDIR\Uninstall.exe"

    ; Registry
    WriteRegStr HKLM "Software\Echoelmusic" "Install_Dir" "$INSTDIR"
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Echoelmusic" "DisplayName" "Echoelmusic"
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Echoelmusic" "UninstallString" '"$INSTDIR\Uninstall.exe"'
SectionEnd

Section "VST3 Plugin" SecVST3
    SetOutPath "$COMMONFILES64\VST3"
    File /r "..\..\Sources\Desktop\build\Release\Echoelmusic.vst3"
SectionEnd

Section "CLAP Plugin" SecCLAP
    SetOutPath "$COMMONFILES64\CLAP"
    File "..\..\Sources\Desktop\build\Release\Echoelmusic.clap"
SectionEnd

; ============================================
; Descriptions
; ============================================

LangString DESC_SecStandalone ${LANG_ENGLISH} "Echoelmusic Standalone Application"
LangString DESC_SecVST3 ${LANG_ENGLISH} "VST3 Plugin for DAWs (Ableton, FL Studio, Cubase, etc.)"
LangString DESC_SecCLAP ${LANG_ENGLISH} "CLAP Plugin for DAWs (Bitwig, Reaper, etc.)"

!insertmacro MUI_FUNCTION_DESCRIPTION_BEGIN
    !insertmacro MUI_DESCRIPTION_TEXT ${SecStandalone} $(DESC_SecStandalone)
    !insertmacro MUI_DESCRIPTION_TEXT ${SecVST3} $(DESC_SecVST3)
    !insertmacro MUI_DESCRIPTION_TEXT ${SecCLAP} $(DESC_SecCLAP)
!insertmacro MUI_FUNCTION_DESCRIPTION_END

; ============================================
; Uninstaller
; ============================================

Section "Uninstall"
    ; Remove files
    Delete "$INSTDIR\Echoelmusic_Standalone.exe"
    Delete "$INSTDIR\Uninstall.exe"
    RMDir "$INSTDIR"

    ; Remove plugins
    RMDir /r "$COMMONFILES64\VST3\Echoelmusic.vst3"
    Delete "$COMMONFILES64\CLAP\Echoelmusic.clap"

    ; Remove shortcuts
    Delete "$SMPROGRAMS\Echoelmusic\Echoelmusic.lnk"
    RMDir "$SMPROGRAMS\Echoelmusic"
    Delete "$DESKTOP\Echoelmusic.lnk"

    ; Remove registry
    DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Echoelmusic"
    DeleteRegKey HKLM "Software\Echoelmusic"
SectionEnd
