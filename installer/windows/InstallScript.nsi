; OrcaForCubicon Windows installer (NSIS)
; Ported from the legacy VS-solution installer to the unified CMake build.
; Input paths are overridable via makensis /D defines (absolute paths preferred);
; defaults assume the standard repo layout with makensis run from this file's dir.
;
;   /DSTAGE_DIR=<dir>        staged app payload to package (orca-slicer.exe + resources + DLLs)
;   /DVERSION_HEADER=<file>  generated libslic3r_version.h (for CUBI_ORCA_VERSION)
;   /DBRANDING_DIR=<dir>     holds CubicreaterOrcaTitle.ico
;   /DLICENSE_FILE=<file>    license shown on the license page

!define PRODUCT_NAME "OrcaForCubicon"
!define APP_EXE "OrcaForCubicon.exe"

!ifndef STAGE_DIR
  !define STAGE_DIR "..\..\build\OrcaSlicer"
!endif
!ifndef VERSION_HEADER
  !define VERSION_HEADER "..\..\build\src\libslic3r\libslic3r_version.h"
!endif
!ifndef BRANDING_DIR
  !define BRANDING_DIR "..\..\cubicon\branding"
!endif
!ifndef LICENSE_FILE
  !define LICENSE_FILE "..\..\LICENSE.txt"
!endif

; Auto-extract version from the generated libslic3r_version.h (CUBI_ORCA_VERSION).
!searchparse /file "${VERSION_HEADER}" `#define CUBI_ORCA_VERSION "` PRODUCT_VERSION `"`
!ifndef PRODUCT_VERSION
  !error "Failed to parse CUBI_ORCA_VERSION from ${VERSION_HEADER}"
!endif

; VIProductVersion / FileVersion require a strict numeric X.X.X.X form, so
; derive a numeric-only version by stripping any pre-release suffix
; (e.g. "1.5.0-rc1" -> "1.5.0"). Display fields keep the full string.
!searchparse /noerrors "${PRODUCT_VERSION}" "" PRODUCT_VERSION_NUM "-"
!ifndef PRODUCT_VERSION_NUM
  !define PRODUCT_VERSION_NUM "${PRODUCT_VERSION}"
!endif

; Build timestamp (YYYYMMDD_HHMMSS) for the output filename. package_win.ps1 passes it via
; /DBUILD_STAMP so it matches wall-clock time; falls back to makensis compile time otherwise.
; The seconds-resolution stamp makes each filename unique (no manual revision bookkeeping).
!ifndef BUILD_STAMP
  !define /date BUILD_STAMP "%Y%m%d_%H%M%S"
!endif

!define PRODUCT_PUBLISHER "Cubicon"
!define PRODUCT_WEB_SITE "http://3dcubicon.com/"
!define PRODUCT_DIR_REGKEY "Software\Microsoft\Windows\CurrentVersion\App Paths\${APP_EXE}"
!define PRODUCT_UNINST_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PRODUCT_NAME}"
!define PRODUCT_UNINST_ROOT_KEY "HKLM"
!define PRODUCT_ENV_ROOT_KEY "HKCU"
!define PRODUCT_ENV_KEY "Software\${PRODUCT_NAME}"

VIProductVersion ${PRODUCT_VERSION_NUM}.0
VIAddVersionKey ProductName "OrcaForCubicon"
VIAddVersionKey CompanyName "Cubicon"
VIAddVersionKey LegalCopyright "Copyright(c) 2025. Cubicon"
VIAddVersionKey FileDescription "OrcaForCubicon Installer"
VIAddVersionKey FileVersion ${PRODUCT_VERSION_NUM}.0
VIAddVersionKey ProductVersion "${PRODUCT_VERSION}"

; Locate bundled includes/plugins relative to THIS .nsi (works from any CWD)
!addincludedir "${__FILEDIR__}\nsis_plugin"
!addplugindir  "${__FILEDIR__}\nsis_plugin"

!include "MUI.nsh"
!include "x64.nsh"
!include "nsProcess.nsh"
!include "FontReg.nsh"
!include "WinMessages.nsh"

!define MUI_ABORTWARNING
!define MUI_ICON "${BRANDING_DIR}\CubicreaterOrcaTitle.ico"
!define MUI_UNICON "${BRANDING_DIR}\CubicreaterOrcaTitle.ico"

!define MUI_LANGDLL_REGISTRY_ROOT "${PRODUCT_UNINST_ROOT_KEY}"
!define MUI_LANGDLL_REGISTRY_KEY "${PRODUCT_UNINST_KEY}"
!define MUI_LANGDLL_REGISTRY_VALUENAME "NSIS:Language"

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE "${LICENSE_FILE}"
!define MUI_LICENSEPAGE_RADIOBUTTONS
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES

!define MUI_FINISHPAGE_NOAUTOCLOSE
!define MUI_FINISHPAGE_RUN
!define MUI_FINISHPAGE_RUN_CHECKED
!define MUI_FINISHPAGE_RUN_FUNCTION "RunApplication"
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "Korean"
!insertmacro MUI_LANGUAGE "English"

Name "${PRODUCT_NAME} ${PRODUCT_VERSION}"
OutFile "${PRODUCT_NAME} Setup V${PRODUCT_VERSION}_${BUILD_STAMP}.exe"
InstallDir "$PROGRAMFILES64\${PRODUCT_NAME}"
ShowInstDetails show
ShowUnInstDetails show

Function RunApplication
  CreateShortCut "$TEMP\Shortcut.lnk" "$INSTDIR\${APP_EXE}"
  Exec '"$WINDIR\explorer.exe" "$TEMP\Shortcut.lnk"'
FunctionEnd

Function .onInit
  ; Close a running instance if present
  ${nsProcess::FindProcess} "${APP_EXE}" $R0
  ${If} $R0 == 0
    MessageBox MB_OKCANCEL|MB_ICONEXCLAMATION \
      "Application is already running. $\n$\nClick `OK` to close or `Cancel` to cancel install." \
      IDOK kill
    Abort
  kill:
    ${nsProcess::CloseProcess} "${APP_EXE}" $R0
    Sleep 2000
  ${Else}
    DetailPrint "${PRODUCT_NAME} was not found to be running"
  ${EndIf}
  ${nsProcess::Unload}

  ; Offer to uninstall a previous version
  ReadRegStr $R0 HKLM "${PRODUCT_UNINST_KEY}" "UninstallString"
  StrCmp $R0 "" done
  MessageBox MB_OKCANCEL|MB_ICONEXCLAMATION \
    "OrcaForCubicon is already installed. $\n$\nClick `OK` to remove the previous version or `Cancel` to cancel this upgrade." \
    IDOK uninst
  Abort
  uninst:
    ClearErrors
    ExecWait '$R0 _?=$INSTDIR'
    IfErrors no_remove_uninstaller done
    no_remove_uninstaller:
  done:
  !insertmacro MUI_LANGDLL_DISPLAY
FunctionEnd

Section "MainSection" SEC01
  SetShellVarContext all

  CreateDirectory "$SMPROGRAMS\${PRODUCT_NAME}"
  CreateShortCut "$SMPROGRAMS\${PRODUCT_NAME}\${PRODUCT_NAME} ${PRODUCT_VERSION}.lnk" "$INSTDIR\${APP_EXE}"
  CreateShortCut "$DESKTOP\${PRODUCT_NAME} ${PRODUCT_VERSION}.lnk" "$INSTDIR\${APP_EXE}"

  ; Remove previously installed bundled system presets so updated ones apply
  ReadEnvStr $0 "APPDATA"
  StrCpy $1 "$0\${PRODUCT_NAME}\system"
  RMDir /r "$1"

  SetOutPath "$INSTDIR\"
  SetOverwrite try
  File /nonfatal /r /x "*.obj" /x "*.log" /x "*.pdb" /x "*.pch" /x "*.ipdb" /x "*.ipch" /x "*.iobj" /x "*.lib" "${STAGE_DIR}\*.*"

  ; Visual C++ / UCRT runtime: shipped app-local by CopyRuntime.ps1; also run the
  ; official redistributable silently so the runtime is registered system-wide.
  SetOutPath "$INSTDIR\redist"
  File "${__FILEDIR__}\redist\vc_redist.x64.exe"
  DetailPrint "Installing Microsoft Visual C++ Runtime (this may take a moment)..."
  ClearErrors
  ExecWait '"$INSTDIR\redist\vc_redist.x64.exe" /install /quiet /norestart' $0
  DetailPrint "Visual C++ Runtime installer exit code: $0"
  Delete "$INSTDIR\redist\vc_redist.x64.exe"
  RMDir "$INSTDIR\redist"
  SetOutPath "$INSTDIR\"
SectionEnd

Section -AdditionalIcons
  SetOutPath $INSTDIR
  WriteIniStr "$INSTDIR\${PRODUCT_NAME}.url" "InternetShortcut" "URL" "${PRODUCT_WEB_SITE}"
  CreateShortCut "$SMPROGRAMS\${PRODUCT_NAME}\Website.lnk" "$INSTDIR\${PRODUCT_NAME}.url"
  CreateShortCut "$SMPROGRAMS\${PRODUCT_NAME}\Uninstall.lnk" "$INSTDIR\uninst.exe"
SectionEnd

Section -Post
  WriteUninstaller "$INSTDIR\uninst.exe"
  WriteRegStr ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "DisplayName" "$(^Name)"
  WriteRegStr ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "UninstallString" "$INSTDIR\uninst.exe"
  WriteRegStr ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "DisplayVersion" "${PRODUCT_VERSION}"
  WriteRegStr ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "URLInfoAbout" "${PRODUCT_WEB_SITE}"
  WriteRegStr ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "Publisher" "${PRODUCT_PUBLISHER}"
  WriteRegStr HKLM "${PRODUCT_DIR_REGKEY}" "" "$INSTDIR\${APP_EXE}"
SectionEnd

Function un.onUninstSuccess
  HideWindow
  MessageBox MB_ICONINFORMATION|MB_OK "You have successfully uninstalled $(^Name)."
FunctionEnd

Function un.onInit
  !insertmacro MUI_UNGETLANGUAGE
  MessageBox MB_ICONQUESTION|MB_YESNO|MB_DEFBUTTON2 "The previous OrcaForCubicon will be uninstalled. Continue?" IDYES +2
  Abort
FunctionEnd

Section Uninstall
  SetShellVarContext all
  Delete "$INSTDIR\${PRODUCT_NAME}.url"
  Delete "$SMPROGRAMS\${PRODUCT_NAME}\Uninstall.lnk"
  Delete "$SMPROGRAMS\${PRODUCT_NAME}\Website.lnk"
  Delete "$DESKTOP\${PRODUCT_NAME} ${PRODUCT_VERSION}.lnk"
  Delete "$SMPROGRAMS\${PRODUCT_NAME}\${PRODUCT_NAME} ${PRODUCT_VERSION}.lnk"
  RMDir "$SMPROGRAMS\${PRODUCT_NAME}"
  RMDir /r "$INSTDIR"
  DeleteRegKey ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}"
  DeleteRegKey ${PRODUCT_ENV_ROOT_KEY} "${PRODUCT_ENV_KEY}"
  DeleteRegKey HKLM "${PRODUCT_DIR_REGKEY}"
  SetAutoClose true
SectionEnd
