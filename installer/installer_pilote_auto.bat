@echo off
rem ============================================================================
rem  Concorde NGR - OPTION pilote automatique (10 cles acf/_ott_*)  (batch pur, sans PowerShell)
rem  Donnees : acf_patch_pilote_auto.txt  (M cle valeur_NGR valeur_original)
rem  Installer : sauvegarde CONCORDE_FXP.acf.avant_pa_ngr + valeurs actuelles dans pa_ngr_restauration.txt
rem  Desinstaller : remet les valeurs NOTEES chez le client (pas forcement celles de Colimata)
rem  A lancer APRES installer.bat (sinon son mode 1 refuse : empreinte MD5 differente).
rem  Test seulement : variable NGR_XP = dossier X-Plane de test (pas de controle X-Plane ouvert)
rem ============================================================================
setlocal EnableExtensions DisableDelayedExpansion
title Concorde NGR - pilote automatique / autopilot
cd /d "%~dp0"
set "PATCH=%~dp0acf_patch_pilote_auto.txt"
set "L=FR"
if not exist "%PATCH%" (
  echo acf_patch_pilote_auto.txt manquant / missing
  goto :fin
)

echo.
echo  ===== CONCORDE NGR - PILOTE AUTOMATIQUE / AUTOPILOT (option) =====
echo  1 = Francais     2 = English
set "c="
set /p "c=Choix / Choice [1] : "
if "%c%"=="2" set "L=EN"

rem ---------- X-Plane doit etre ferme ----------
if not defined NGR_XP (
  tasklist /fi "imagename eq X-Plane.exe" 2>nul | find /i "X-Plane.exe" >nul && (
    call :msg "X-Plane est ouvert : fermez-le puis relancez installer_pilote_auto.bat." "X-Plane is running: close it and run installer_pilote_auto.bat again."
    goto :fin
  )
)

rem ---------- dossier X-Plane 12 ----------
set "XP="
if defined NGR_XP set "XP=%NGR_XP%"
if not defined XP if exist "%LOCALAPPDATA%\x-plane_install_12.txt" call :choisir_xp
if not defined XP (
  call :msg "Dossier X-Plane 12 introuvable. Tapez son chemin complet :" "X-Plane 12 folder not found. Type its full path:"
  set /p "XP=> "
)
if not defined XP goto :fin
if "%XP:~-1%"=="\" set "XP=%XP:~0,-1%"
if not exist "%XP%\Resources\plugins" (
  call :msg "Ce dossier n'est pas X-Plane 12 :" "This folder is not X-Plane 12:"
  echo   %XP%
  goto :fin
)
call :msg "X-Plane 12 :" "X-Plane 12:"
echo   %XP%

rem ---------- CONCORDE_FXP.acf ----------
set "ACF="
set /a na=0
for /f "delims=" %%f in ('dir /s /b "%XP%\Aircraft\CONCORDE_FXP.acf" 2^>nul') do (
  set "f=%%f"
  call :ajout_acf
)
if %na%==1 set "ACF=%ACF1%"
if %na% GTR 1 call :choisir_acf
if not defined ACF (
  call :msg "CONCORDE_FXP.acf introuvable. Tapez le chemin complet du fichier .acf :" "CONCORDE_FXP.acf not found. Type the full path of the .acf file:"
  set /p "ACF=> "
)
if not defined ACF goto :fin
if not exist "%ACF%" (
  call :msg "Fichier introuvable." "File not found."
  goto :fin
)
for %%f in ("%ACF%") do set "AC=%%~dpf"
set "RESTO=%AC%pa_ngr_restauration.txt"
set "TMPACF=%ACF%.pa_tmp"
call :msg "Avion :" "Aircraft:"
echo   %ACF%

rem ---------- menu ----------
:menu
echo.
call :etat
echo.
call :msg "  1 = Installer le pilote automatique NGR" "  1 = Install the NGR autopilot settings"
call :msg "  2 = Desinstaller - remettre les valeurs d'avant" "  2 = Uninstall - restore the previous values"
call :msg "  3 = Afficher l'etat" "  3 = Show the state"
call :msg "  0 = Quitter" "  0 = Quit"
set "m="
set /p "m=> "
if "%m%"=="1" goto :installer
if "%m%"=="2" goto :desinstaller
if "%m%"=="3" goto :menu
goto :fin

rem ========== INSTALLER ==========
:installer
if "%ETAT%"=="NGR" (
  call :msg "Deja installe : rien a faire." "Already installed: nothing to do."
  goto :menu
)
if not "%MANQ%"=="0" (
  call :msg "Des cles du pilote automatique manquent dans cet ACF : rien n'est fait." "Some autopilot keys are missing in this ACF: nothing is done."
  goto :menu
)
findstr /c:"!" "%ACF%" >nul && (
  call :msg "Cet ACF contient le caractere ! : impossible en batch. Voir LISTE_DES_MODIFICATIONS.txt." "This ACF contains the ! character: not possible in batch. See LIST_OF_CHANGES.txt."
  goto :menu
)
call :ask "Modifier les 10 reglages du pilote automatique de cet ACF ?" "Change the 10 autopilot settings of this ACF?"
if errorlevel 1 goto :menu
if exist "%RESTO%" move /y "%RESTO%" "%RESTO%.ancien" >nul
rem valeurs actuelles du client -> fichier de restauration (format : M cle valeur)
>"%RESTO%" echo # pa_ngr_restauration.txt - valeurs AVANT installation du pilote automatique NGR - ne pas effacer
for /f "usebackq tokens=1,2" %%a in ("%PATCH%") do if "%%a"=="M" (
  for /f "tokens=3" %%v in ('findstr /b /c:"P %%b " "%ACF%"') do >>"%RESTO%" echo M %%b %%v
)
if exist "%ACF%.avant_pa_ngr" (
  call :msg "Sauvegarde CONCORDE_FXP.acf.avant_pa_ngr deja presente : conservee." "Backup CONCORDE_FXP.acf.avant_pa_ngr already present: kept."
) else (
  copy /y "%ACF%" "%ACF%.avant_pa_ngr" >nul
  call :msg "Sauvegarde : CONCORDE_FXP.acf.avant_pa_ngr" "Backup: CONCORDE_FXP.acf.avant_pa_ngr"
)
call :appliquer "%PATCH%" <nul
if errorlevel 1 goto :fin
call :etat
if not "%ETAT%"=="NGR" (
  call :msg "ERREUR : verification ratee. Remettez CONCORDE_FXP.acf.avant_pa_ngr a la place de CONCORDE_FXP.acf." "ERROR: check failed. Put CONCORDE_FXP.acf.avant_pa_ngr back in place of CONCORDE_FXP.acf."
  goto :fin
)
call :msg "OK : pilote automatique NGR installe et verifie - 10 cles." "OK: NGR autopilot installed and checked - 10 keys."
goto :menu

rem ========== DESINSTALLER ==========
:desinstaller
if not exist "%RESTO%" (
  call :msg "Pas de fichier pa_ngr_restauration.txt : rien a remettre." "No pa_ngr_restauration.txt file: nothing to restore."
  goto :menu
)
call :ask "Remettre les reglages du pilote automatique d'avant l'installation ?" "Restore the autopilot settings from before the install?"
if errorlevel 1 goto :menu
call :appliquer "%RESTO%" <nul
if errorlevel 1 goto :fin
set /a ko=0
for /f "usebackq tokens=1,2,3" %%a in ("%RESTO%") do if "%%a"=="M" (
  findstr /b /x /c:"P %%b %%c" "%ACF%" >nul || set /a ko+=1
)
if not "%ko%"=="0" (
  call :msg "ERREUR : verification ratee. Remettez CONCORDE_FXP.acf.avant_pa_ngr a la place de CONCORDE_FXP.acf." "ERROR: check failed. Put CONCORDE_FXP.acf.avant_pa_ngr back in place of CONCORDE_FXP.acf."
  goto :fin
)
del "%RESTO%"
if exist "%RESTO%.ancien" del "%RESTO%.ancien"
if exist "%ACF%.avant_pa_ngr" del "%ACF%.avant_pa_ngr"
call :msg "OK : reglages d'avant remis et verifies." "OK: previous settings restored and checked."
goto :menu

rem ============================ SOUS-PROGRAMMES ============================
rem :etat -> ETAT = NGR / ORIGINAL / AUTRE, MANQ = nombre de cles absentes ; affiche les 10 valeurs
:etat
set /a nn=0, no=0, MANQ=0, tot=0
call :msg "Pilote automatique - cle : valeur actuelle / NGR / original" "Autopilot - key: current value / NGR / original"
for /f "usebackq tokens=1,2,3,4" %%a in ("%PATCH%") do if "%%a"=="M" call :etat1 "%%b" "%%c" "%%d"
set "ETAT=AUTRE"
if %nn%==%tot% set "ETAT=NGR"
if %no%==%tot% set "ETAT=ORIGINAL"
if "%ETAT%"=="NGR" call :msg "  ** PILOTE AUTOMATIQUE NGR INSTALLE" "  ** NGR AUTOPILOT INSTALLED"
if "%ETAT%"=="ORIGINAL" call :msg "  ** reglages d'origine Colimata" "  ** original Colimata settings"
if "%ETAT%"=="AUTRE" call :msg "  ** autres reglages - mod, reglage perso ou melange" "  ** other settings - mod, own tuning or mixed"
if exist "%RESTO%" call :msg "  fichier de restauration present : %RESTO%" "  restore file present: %RESTO%"
goto :eof
:etat1
set /a tot+=1
set "cur="
for /f "tokens=3" %%v in ('findstr /b /c:"P %~1 " "%ACF%"') do set "cur=%%v"
if not defined cur (
  set /a MANQ+=1
  echo   %~1 : ABSENT / MISSING
  goto :eof
)
if "%cur%"=="%~2" set /a nn+=1
if "%cur%"=="%~3" set /a no+=1
echo   %~1 : %cur% / %~2 / %~3
goto :eof

rem :appliquer FICHIER  (lignes "M cle valeur") -> ACF ; controle du nombre de lignes
:appliquer
call :msg "Modification de l'ACF en cours, patientez jusqu'a une minute..." "Modifying the ACF, please wait up to one minute..."
set "MAP=%~1"
setlocal EnableDelayedExpansion
for /f "usebackq tokens=1,2,3" %%a in ("%MAP%") do if "%%a"=="M" set "M[%%b]=%%c"
(
  for /f "delims=" %%L in ('findstr /n "^" "%ACF%"') do (
    set "line=%%L"
    set "line=!line:*:=!"
    if "!line:~0,2!"=="P " (
      for /f "tokens=2" %%k in ("!line!") do if defined M[%%k] set "line=P %%k !M[%%k]!"
    )
    echo(!line!
  )
) > "%TMPACF%"
endlocal
set "n1=" & set "n2="
for /f %%n in ('find /c /v "" ^< "%ACF%"') do set "n1=%%n"
for /f %%n in ('find /c /v "" ^< "%TMPACF%"') do set "n2=%%n"
if not "%n1%"=="%n2%" (
  del "%TMPACF%" 2>nul
  call :msg "ERREUR : fichier produit incomplet, l'ACF n'a PAS ete modifie." "ERROR: incomplete output, the ACF was NOT modified."
  exit /b 1
)
move /y "%TMPACF%" "%ACF%" >nul
exit /b 0

:msg
if "%L%"=="EN" (echo(%~2) else (echo(%~1)
goto :eof

rem :ask "question fr" "question en"  -> errorlevel 0 = oui, 1 = non
:ask
set "r="
if "%L%"=="EN" (set /p "r=%~2 [Y/N] : ") else (set /p "r=%~1 [O/N] : ")
if /i "%r%"=="O" exit /b 0
if /i "%r%"=="Y" exit /b 0
exit /b 1

:choisir_xp
set /a nx=0
for /f "usebackq delims=" %%d in ("%LOCALAPPDATA%\x-plane_install_12.txt") do (
  set "d=%%d"
  call :ajout_xp
)
if %nx%==1 set "XP=%XP1%"
if %nx% GTR 1 (
  call :msg "Plusieurs X-Plane 12 :" "Several X-Plane 12:"
  for /l %%i in (1,1,%nx%) do call echo   %%i = %%XP%%i%%
  set "k="
  set /p "k=> "
)
if %nx% GTR 1 call set "XP=%%XP%k%%%"
goto :eof
:ajout_xp
set "d=%d:/=\%"
if "%d:~-1%"=="\" set "d=%d:~0,-1%"
if not exist "%d%\Resources\plugins" goto :eof
set /a nx+=1
set "XP%nx%=%d%"
goto :eof

:ajout_acf
if /i not "%f:~-4%"==".acf" goto :eof
set /a na+=1
set "ACF%na%=%f%"
goto :eof
:choisir_acf
call :msg "Plusieurs CONCORDE_FXP.acf :" "Several CONCORDE_FXP.acf:"
for /l %%i in (1,1,%na%) do call echo   %%i = %%ACF%%i%%
set "k="
set /p "k=> "
call set "ACF=%%ACF%k%%%"
goto :eof

:fin
echo.
pause
endlocal
exit /b 0
