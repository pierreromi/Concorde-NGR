@echo off
rem ============================================================================
rem  Concorde NGR - installation / uninstall  (batch pur, sans PowerShell)
rem  Donnees : acf_patch.txt (genere par outils\generer_installeur_acf.py)
rem  Detail de tout ce qui est fait : LISTE_DES_MODIFICATIONS.txt / LIST_OF_CHANGES.txt
rem  Test seulement : variable NGR_XP = dossier X-Plane de test (pas de controle X-Plane ouvert)
rem ============================================================================
setlocal EnableExtensions DisableDelayedExpansion
title Concorde NGR
cd /d "%~dp0"
set "HERE=%~dp0"
set "PKG=%~dp0.."
set "PATCH=%~dp0acf_patch.txt"
set "L=FR"
if not exist "%PATCH%" (
  echo acf_patch.txt manquant / missing
  goto :fin
)
for /f "usebackq tokens=1,2" %%a in ("%PATCH%") do (
  if "%%a"=="O" set "MD5_ORIG=%%b"
  if "%%a"=="H" set "MD5_NEW=%%b"
)

echo.
echo  ===== CONCORDE NGR =====
echo  1 = Francais     2 = English
set "c="
set /p "c=Choix / Choice [1] : "
if "%c%"=="2" set "L=EN"

rem ---------- X-Plane doit etre ferme ----------
if not defined NGR_XP (
  tasklist /fi "imagename eq X-Plane.exe" 2>nul | find /i "X-Plane.exe" >nul && (
    call :msg "X-Plane est ouvert : fermez-le puis relancez installer.bat." "X-Plane is running: close it and run installer.bat again."
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
set "LOG=%AC%ngr_installe.txt"
set "TMPACF=%ACF%.ngr_tmp"
call :msg "Avion :" "Aircraft:"
echo   %ACF%

rem ---------- menu ----------
:menu
echo.
call :msg "  1 = Installation automatique - ACF original exact" "  1 = Automatic install - exact original ACF"
call :msg "  2 = Forcer cle par cle - autre version ou ACF deja modifie" "  2 = Force key by key - other version or already modified ACF"
call :msg "  3 = Copier les fichiers seulement - je modifie l'ACF a la main" "  3 = Copy the files only - I edit the ACF by hand"
call :msg "  4 = Desinstaller" "  4 = Uninstall"
call :msg "  5 = Quitter" "  5 = Quit"
set "m="
set /p "m=> "
if "%m%"=="1" goto :mode1
if "%m%"=="2" goto :mode2
if "%m%"=="3" goto :mode3
if "%m%"=="4" goto :desinstaller
if "%m%"=="5" goto :fin
goto :menu

rem ========== MODE 1 : automatique ==========
:mode1
call :md5 "%ACF%" CUR <nul
if /i "%CUR%"=="%MD5_NEW%" (
  call :msg "L'ACF est deja modifie par cette version : rien a faire." "The ACF is already modified by this version: nothing to do."
  call :ecran_cockpit <nul
  goto :plugin
)
if /i not "%CUR%"=="%MD5_ORIG%" (
  call :msg "Cet ACF n'est pas l'original exact de Colimata - autre version ou deja modifie." "This ACF is not the exact Colimata original - other version or already modified."
  call :msg "Choisissez 2 - forcer cle par cle - ou 3 - a la main, voir LISTE_DES_MODIFICATIONS.txt." "Choose 2 - force key by key - or 3 - by hand, see LIST_OF_CHANGES.txt."
  goto :menu
)
call :copier_fichiers <nul
call :sauver_acf <nul
set "ADDMISS=0"
call :patcher <nul
call :md5 "%TMPACF%" NEWH <nul
if /i not "%NEWH%"=="%MD5_NEW%" (
  del "%TMPACF%" 2>nul
  call :msg "ERREUR : resultat inattendu, l'ACF n'a PAS ete modifie." "ERROR: unexpected result, the ACF was NOT modified."
  goto :fin
)
move /y "%TMPACF%" "%ACF%" >nul
call :msg "ACF modifie et verifie - empreinte MD5 correcte." "ACF modified and verified - MD5 correct."
call :ecran_cockpit <nul
goto :plugin

rem ========== MODE 2 : forcer cle par cle ==========
:mode2
findstr /c:"!" "%ACF%" >nul && (
  call :msg "Cet ACF contient le caractere ! : impossible en batch. Faites-le a la main - option 3." "This ACF contains the ! character: not possible in batch. Do it by hand - option 3."
  goto :menu
)
set /a miss=0
for /f "usebackq tokens=1,2" %%a in ("%PATCH%") do if "%%a"=="M" (
  findstr /b /c:"P %%b " "%ACF%" >nul || (
    set /a miss+=1
    call :msg "  ligne absente :" "  missing line:"
    echo     P %%b
  )
)
set "NCOUNT="
for /f "tokens=3" %%v in ('findstr /b /c:"P _obja/count " "%ACF%"') do set "NCOUNT=%%v"
findstr /c:"ngb_mcdu_cadre.obj" "%ACF%" >nul && call :msg "  Tablette 3D deja declaree dans l'ACF : non ajoutee." "  3D tablet already declared in the ACF: not added."
if not defined NCOUNT (
  call :msg "  Ligne P _obja/count absente : la tablette sera a ajouter a la main." "  Line P _obja/count missing: the tablet must be added by hand."
)
set "ADDMISS=0"
if %miss% GTR 0 (
  call :msg "Des lignes attendues manquent dans cet ACF. Conseil : faire a la main - option 3." "Some expected lines are missing in this ACF. Advice: do it by hand - option 3."
  call :ask "Ajouter quand meme les lignes manquantes a la fin des proprietes ?" "Add the missing lines anyway at the end of the properties?"
  if errorlevel 1 (
    call :msg "Rien n'a ete modifie. Voir LISTE_DES_MODIFICATIONS.txt" "Nothing was changed. See LIST_OF_CHANGES.txt"
    call :ouvrir_liste
    goto :menu
  )
  set "ADDMISS=1"
)
call :ask "Modifier cet ACF maintenant ?" "Modify this ACF now?"
if errorlevel 1 goto :menu
call :copier_fichiers <nul
call :sauver_acf <nul
call :patcher <nul
for %%z in ("%TMPACF%") do if %%~zz LSS 1000 (
  del "%TMPACF%" 2>nul
  call :msg "ERREUR : fichier produit vide, l'ACF n'a PAS ete modifie." "ERROR: empty output, the ACF was NOT modified."
  goto :fin
)
move /y "%TMPACF%" "%ACF%" >nul
call :msg "ACF modifie cle par cle." "ACF modified key by key."
call :ecran_cockpit <nul
goto :plugin

rem ========== MODE 3 : a la main ==========
:mode3
call :ask "Copier la tablette 3D et les airfoils dans l'avion ? L'ACF n'est pas touche." "Copy the 3D tablet and the airfoils into the aircraft? The ACF is not touched."
if not errorlevel 1 call :copier_fichiers <nul
call :ouvrir_liste
goto :plugin

rem ========== PLUGIN ==========
:plugin
echo.
set "PL=%XP%\Resources\plugins"
if exist "%PL%\concorde_mcdu_ngb" (
  call :msg "Ancien plugin concorde_mcdu_ngb present : retirez-le d'abord, sinon conflit sur le port 8087. Plugin non copie." "Old plugin concorde_mcdu_ngb found: remove it first, otherwise port 8087 conflict. Plugin not copied."
  goto :fin
)
call :ask "Copier le plugin Concorde_NGR dans X-Plane 12\Resources\plugins ?" "Copy the Concorde_NGR plugin into X-Plane 12\Resources\plugins?"
if errorlevel 1 (
  call :msg "Plugin non copie : copiez le dossier Concorde_NGR a la main dans Resources\plugins." "Plugin not copied: copy the Concorde_NGR folder by hand into Resources\plugins."
  goto :fin
)
xcopy "%PKG%\Concorde_NGR" "%PL%\Concorde_NGR\" /e /i /y /q <nul >nul
if errorlevel 1 (
  call :msg "ERREUR pendant la copie du plugin." "ERROR while copying the plugin."
  goto :fin
)
>>"%LOG%" echo PLUGIN Concorde_NGR
call :msg "Plugin copie." "Plugin copied."
goto :fin

rem ========== DESINSTALLER ==========
:desinstaller
call :ask "Desinstaller : remettre l'ACF d'origine et retirer les fichiers ajoutes ?" "Uninstall: restore the original ACF and remove the added files?"
if errorlevel 1 goto :menu
if exist "%ACF%.originalconcorde" (
  move /y "%ACF%.originalconcorde" "%ACF%" >nul
  call :msg "ACF d'origine remis." "Original ACF restored."
) else (
  call :msg "Pas de sauvegarde .originalconcorde : ACF non touche." "No .originalconcorde backup: ACF not touched."
)
if exist "%LOG%" (
  for /f "usebackq tokens=1,*" %%a in ("%LOG%") do (
    if "%%a"=="ADD" del "%AC%%%b" 2>nul
    if "%%a"=="BAK" if exist "%AC%%%b.originalconcorde" move /y "%AC%%%b.originalconcorde" "%AC%%%b" >nul
  )
  del "%LOG%"
  call :msg "Fichiers ajoutes retires." "Added files removed."
)
if exist "%XP%\Resources\plugins\Concorde_NGR" (
  call :ask "Retirer aussi le plugin Concorde_NGR ?" "Also remove the Concorde_NGR plugin?"
  if not errorlevel 1 (
    rd /s /q "%XP%\Resources\plugins\Concorde_NGR"
    call :msg "Plugin retire." "Plugin removed."
  )
)
goto :fin

rem ============================ SOUS-PROGRAMMES ============================
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

:md5
set "%~2="
for /f "skip=1 delims=" %%h in ('certutil -hashfile "%~1" MD5 ^<nul 2^>nul') do (
  if not defined %~2 set "%~2=%%h"
)
call set "%~2=%%%~2: =%%"
goto :eof

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

:sauver_acf
if exist "%ACF%.originalconcorde" (
  call :msg "Sauvegarde CONCORDE_FXP.acf.originalconcorde deja presente : conservee." "Backup CONCORDE_FXP.acf.originalconcorde already present: kept."
) else (
  copy /y "%ACF%" "%ACF%.originalconcorde" >nul
  call :msg "Sauvegarde : CONCORDE_FXP.acf.originalconcorde" "Backup: CONCORDE_FXP.acf.originalconcorde"
)
goto :eof

:copier_fichiers
if not exist "%AC%airfoils" md "%AC%airfoils"
if not exist "%AC%objects\cockpit_v200" md "%AC%objects\cockpit_v200"
for %%f in ("%PKG%\CONCORDE_FXP\Airfoils\*.afl") do call :copie1 "%%~ff" "airfoils\%%~nxf"
for %%f in ("%PKG%\CONCORDE_FXP\objects\cockpit_v200\*.obj") do call :copie1 "%%~ff" "objects\cockpit_v200\%%~nxf"
goto :eof
rem :copie1 source chemin_relatif_dans_l_avion
:copie1
if exist "%AC%%~2" (
  fc /b "%~1" "%AC%%~2" >nul && goto :eof
  if not exist "%AC%%~2.originalconcorde" copy /y "%AC%%~2" "%AC%%~2.originalconcorde" >nul
  >>"%LOG%" echo BAK %~2
) else (
  >>"%LOG%" echo ADD %~2
)
copy /y "%~1" "%AC%%~2" >nul
echo   + %~2
goto :eof

:ouvrir_liste
if defined NGR_XP goto :eof
if "%L%"=="EN" (start "" notepad "%HERE%LIST_OF_CHANGES.txt") else (start "" notepad "%HERE%LISTE_DES_MODIFICATIONS.txt")
goto :eof

rem ---------- :ecran_cockpit  ecran MCDU dans CONCORDE_FXP_cockpit.obj (donnees : ecran_cockpit.txt) ----------
rem  4 sommets apres le dernier VT, 6 IDX apres le dernier IDX, bloc ANIM apres le dernier ANIM_end, POINT_COUNTS +4 / +6
rem  sauvegarde CONCORDE_FXP_cockpit.obj.originalconcorde + ligne BAK dans ngr_installe.txt (remis par Desinstaller)
:ecran_cockpit
set "CK=%AC%CONCORDE_FXP_cockpit.obj"
set "ECR=%HERE%ecran_cockpit.txt"
if not exist "%CK%" (
  call :msg "CONCORDE_FXP_cockpit.obj introuvable : ecran MCDU NON ajoute - voir LISTE_DES_MODIFICATIONS.txt." "CONCORDE_FXP_cockpit.obj not found: MCDU screen NOT added - see LIST_OF_CHANGES.txt."
  goto :eof
)
findstr /c:"ngb/mcdu/panel_enabled" "%CK%" >nul && (
  call :msg "Ecran MCDU deja present dans le cockpit : rien a ajouter." "MCDU screen already in the cockpit: nothing to add."
  goto :eof
)
findstr /c:"!" "%CK%" >nul && (
  call :msg "Le cockpit contient le caractere ! : ecran MCDU a ajouter a la main - voir LISTE_DES_MODIFICATIONS.txt." "The cockpit contains the ! character: add the MCDU screen by hand - see LIST_OF_CHANGES.txt."
  goto :eof
)
set "NV=" & set "NI=" & set "LVT=" & set "LIX=" & set "LAN="
for /f "tokens=2,5" %%a in ('findstr /b /c:"POINT_COUNTS" "%CK%"') do (set "NV=%%a" & set "NI=%%b")
for /f "delims=:" %%n in ('findstr /n /b /c:"VT" "%CK%"') do set "LVT=%%n"
for /f "delims=:" %%n in ('findstr /n /b /c:"IDX" "%CK%"') do set "LIX=%%n"
for /f "delims=:" %%n in ('findstr /n /c:"ANIM_end" "%CK%"') do set "LAN=%%n"
set "OKC=1"
for %%v in (NV NI LVT LIX LAN) do if not defined %%v set "OKC=0"
if "%OKC%"=="0" (
  call :msg "Cockpit de format inconnu : ecran MCDU NON ajoute - voir LISTE_DES_MODIFICATIONS.txt." "Unknown cockpit format: MCDU screen NOT added - see LIST_OF_CHANGES.txt."
  goto :eof
)
call :msg "Ajout de l'ecran MCDU dans le cockpit, patientez..." "Adding the MCDU screen to the cockpit, please wait..."
setlocal EnableDelayedExpansion
set /a i=0, NV4=NV+4, NI6=NI+6, I1=NV+1, I2=NV+2, I3=NV+3
(
  for /f "delims=" %%L in ('findstr /n "^" "%CK%"') do (
    set "line=%%L"
    set "line=!line:*:=!"
    set /a i+=1
    if "!line:~0,12!"=="POINT_COUNTS" for /f "tokens=1,3,4" %%p in ("!line!") do set "line=%%p	!NV4!	%%q	%%r	!NI6!"
    echo(!line!
    if !i!==%LVT% for /f "usebackq tokens=1,* delims= " %%a in ("%ECR%") do if "%%a"=="V" echo(%%b
    if !i!==%LIX% (
      echo(IDX	!NV!
      echo(IDX	!I1!
      echo(IDX	!I2!
      echo(IDX	!NV!
      echo(IDX	!I2!
      echo(IDX	!I3!
    )
    if !i!==%LAN% (
      for /f "usebackq tokens=1,* delims= " %%a in ("%ECR%") do if "%%a"=="A" echo(%%b
      echo(	TRIS	!NI! 6
      for /f "usebackq tokens=1,* delims= " %%a in ("%ECR%") do if "%%a"=="B" echo(%%b
    )
  )
) > "%CK%.ngr_tmp"
endlocal
set "n1=" & set "n2="
for /f %%n in ('find /c /v "" ^< "%CK%"') do set "n1=%%n"
for /f %%n in ('find /c /v "" ^< "%CK%.ngr_tmp"') do set "n2=%%n"
set /a n1+=22
findstr /c:"ngb/mcdu/panel_enabled" "%CK%.ngr_tmp" >nul || set "n2=0"
if not "%n1%"=="%n2%" (
  del "%CK%.ngr_tmp" 2>nul
  call :msg "ERREUR : ecran MCDU non ajoute, cockpit NON modifie." "ERROR: MCDU screen not added, cockpit NOT modified."
  goto :eof
)
if not exist "%CK%.originalconcorde" (
  copy /y "%CK%" "%CK%.originalconcorde" >nul
  >>"%LOG%" echo BAK CONCORDE_FXP_cockpit.obj
)
move /y "%CK%.ngr_tmp" "%CK%" >nul
call :msg "Ecran MCDU ajoute dans le cockpit - sauvegarde CONCORDE_FXP_cockpit.obj.originalconcorde." "MCDU screen added to the cockpit - backup CONCORDE_FXP_cockpit.obj.originalconcorde."
goto :eof

rem ---------- :patcher  ACF -> TMPACF (cles M, bloc tablette T, compteur) ----------
:patcher
call :msg "Modification de l'ACF en cours, patientez jusqu'a une minute..." "Modifying the ACF, please wait up to one minute..."
setlocal EnableDelayedExpansion
set /a nm=0, nt=0
for /f "usebackq tokens=1,2,*" %%a in ("%PATCH%") do (
  if "%%a"=="M" (
    set /a nm+=1
    set "MK!nm!=%%b"
    set "M[%%b]=%%c"
  )
  if "%%a"=="T" (
    set /a nt+=1
    set "T!nt!=%%b %%c"
  )
)
set "TABDO=1"
set "N="
for /f "tokens=3" %%v in ('findstr /b /c:"P _obja/count " "%ACF%"') do set "N=%%v"
if not defined N set "TABDO=0"
findstr /c:"ngb_mcdu_cadre.obj" "%ACF%" >nul && set "TABDO=0"
set "PFX=#"
set /a PL=1, N1=0
if "!TABDO!"=="1" (
  set /a N1=N+1, NP=N-1
  set "PFX=P _obja/!NP!/"
  set /a PL=10
  if !NP! GEQ 10 set /a PL=11
  if !NP! GEQ 100 set /a PL=12
)
set "inb=0"
set "done=0"
(
  for /f "delims=" %%L in ('findstr /n "^" "%ACF%"') do (
    set "line=%%L"
    set "line=!line:*:=!"
    if "!TABDO!!done!"=="10" (
      if "!line:~0,%PL%!"=="!PFX!" (
        set "inb=1"
      ) else if "!inb!"=="1" (
        call :tblock
        set "done=1"
      )
    )
    if "!line:~0,2!"=="P " (
      for /f "tokens=2" %%k in ("!line!") do (
        if defined M[%%k] (
          set "line=P %%k !M[%%k]!"
          set "S[%%k]=1"
        )
        if "%%k"=="_obja/count" if "!TABDO!"=="1" (
          if "!done!"=="0" (
            call :tblock
            set "done=1"
          )
          set "line=P _obja/count !N1!"
        )
      )
    )
    if "!line!"=="PROPERTIES_END" if "%ADDMISS%"=="1" call :manquants
    echo(!line!
  )
) > "%TMPACF%"
endlocal
goto :eof
:tblock
for /l %%i in (1,1,%nt%) do echo(P _obja/!N!/!T%%i!
goto :eof
:manquants
for /l %%i in (1,1,%nm%) do for /f %%y in ("!MK%%i!") do if not defined S[%%y] echo(P %%y !M[%%y]!
goto :eof

:fin
echo.
pause
endlocal
exit /b 0
