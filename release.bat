@echo off
setlocal enabledelayedexpansion

:: Environment variables for headless tests and builds
set "SDL_VIDEODRIVER=dummy"
set "SDL_AUDIODRIVER=dummy"
set "BIG_RIG_HORIZON_NO_SPEECH=1"
set "title_bar==================================================="

:: Process command-line argument if provided
set "cli_mode="
if not "%~1"=="" (
    set "cli_mode=1"
    if "%~1"=="sync" goto run_sync
    if "%~1"=="test" goto run_tests
    if "%~1"=="build" goto run_build_cli
    if "%~1"=="notes" goto run_notes_cli
    if "%~1"=="all" goto run_all_cli
    if "%~1"=="status" goto run_git_status
    if "%~1"=="commit" goto run_git_commit_cli
    if "%~1"=="push" goto run_git_push
    if "%~1"=="tag" goto run_git_tag_cli
    if "%~1"=="version" goto run_version_cli
    goto usage
)

:menu
cls
echo %title_bar%
echo   Big Rig Horizon - Project ^& Release Manager
echo %title_bar%

:: Fetch current git branch
set "current_branch=Unknown"
for /f "usebackq tokens=*" %%i in (`git branch --show-current 2^>nul`) do set "current_branch=%%i"

:: Fetch current project version from pyproject.toml
set "current_version=Unknown"
for /f "usebackq tokens=*" %%i in (`call uv run python -c "import tomllib; print(tomllib.load(open('pyproject.toml', 'rb'))['project']['version'])" 2^>nul`) do set "current_version=%%i"

echo  Current Version : !current_version!
echo  Active Branch   : !current_branch!
echo %title_bar%
echo.
echo  [1] Sync dependencies (uv sync --group dev --group build)
echo  [2] Run test suite (pytest - headless)
echo  [3] Build standalone package (Nuitka compilation)
echo  [4] Generate release notes (from CHANGELOG.md)
echo  [5] Run complete release pipeline (Sync + Test + Build + Notes)
echo.
echo  [6] Git Status (Check branch status ^& modified files)
echo  [7] Git Stage ^& Commit (Save local changes)
echo  [8] Git Push (Upload local commits to remote)
echo  [9] Git Tag Release (Create and push release version tag)
echo.
echo  [10] Bump / Edit Version (Update pyproject.toml ^& sync environment)
echo  [11] Exit
echo.
set /p choice="Enter option (1-11): "

if "%choice%"=="1" goto run_sync
if "%choice%"=="2" goto run_tests
if "%choice%"=="3" goto run_build
if "%choice%"=="4" goto run_notes
if "%choice%"=="5" goto run_all
if "%choice%"=="6" goto run_git_status
if "%choice%"=="7" goto run_git_commit
if "%choice%"=="8" goto run_git_push
if "%choice%"=="9" goto run_git_tag
if "%choice%"=="10" goto run_version_edit
if "%choice%"=="11" goto end
echo [ERROR] Invalid choice.
echo.
pause
goto menu

:run_sync
echo.
echo %title_bar%
echo   Syncing dependencies
echo %title_bar%
call uv sync --group dev --group build
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Dependency sync failed.
    if defined cli_mode exit /b %ERRORLEVEL%
    pause
    goto menu
)
echo.
echo [SUCCESS] Dependency sync completed successfully.
echo.
if defined cli_mode exit /b 0
pause
goto menu

:run_tests
echo.
echo %title_bar%
echo   Running headless tests
echo %title_bar%
call uv run pytest
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Test suite failed.
    if defined cli_mode exit /b %ERRORLEVEL%
    pause
    goto menu
)
echo.
echo [SUCCESS] All tests passed!
echo.
if defined cli_mode exit /b 0
pause
goto menu

:run_build
echo.
echo %title_bar%
echo   Building standalone package
echo %title_bar%

:: Check for uncommitted changes
set "git_dirty="
for /f "usebackq tokens=*" %%i in (`git status --porcelain 2^>nul`) do set "git_dirty=%%i"
if not "!git_dirty!"=="" (
    echo [WARNING] You have uncommitted changes in your repository:
    git status -s
    echo.
    set /p proceed_dirty="Do you still want to compile this build? (y/n): "
    if /i not "!proceed_dirty!"=="y" (
        echo Build canceled.
        pause
        goto menu
    )
)

set /p tag="Enter tag/label override (e.g. nightly-20260623), or press Enter to use project version: "
echo.
if "%tag%"=="" (
    call uv run python tools/build_release.py
) else (
    call uv run python tools/build_release.py --tag "%tag%"
)
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Nuitka build failed.
    pause
    goto menu
)
echo.
echo [SUCCESS] Standalone package built successfully in dist/
echo.
pause
goto menu

:run_build_cli
echo.
echo %title_bar%
echo   Building standalone package (CLI)
echo %title_bar%
shift
set "build_args="
:build_args_loop
if "%~1"=="" goto run_build_execute
set "build_args=!build_args! %1"
shift
goto build_args_loop

:run_build_execute
call uv run python tools/build_release.py %build_args%
exit /b %ERRORLEVEL%

:run_notes
echo.
echo %title_bar%
echo   Generating release notes
echo %title_bar%
set /p note_type="Enter note type (stable or nightly): "
if /i "%note_type%"=="stable" (
    for /f "usebackq tokens=*" %%i in (`call uv run python -c "import tomllib; print(tomllib.load(open('pyproject.toml', 'rb'))['project']['version'])" 2^>nul`) do set "default_ver=%%i"
    set /p ver="Enter version number [default: !default_ver!]: "
    if "!ver!"=="" set "ver=!default_ver!"
    call uv run python tools/release_notes.py stable --version "!ver!" --output notes.md
) else (
    set /p prev_tag="Enter previous tag for nightly diff (optional): "
    if "!prev_tag!"=="" (
        call uv run python tools/release_notes.py nightly --output notes.md
    ) else (
        call uv run python tools/release_notes.py nightly --previous-tag "!prev_tag!" --output notes.md
    )
)
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Release notes generation failed.
    pause
    goto menu
)
echo.
echo [SUCCESS] Release notes written to notes.md
echo.
pause
goto menu

:run_notes_cli
echo.
echo %title_bar%
echo   Generating release notes (CLI)
echo %title_bar%
shift
set "notes_args="
:notes_args_loop
if "%~1"=="" goto run_notes_execute
set "notes_args=!notes_args! %1"
shift
goto notes_args_loop

:run_notes_execute
call uv run python tools/release_notes.py %notes_args%
exit /b %ERRORLEVEL%

:run_all
echo.
echo %title_bar%
echo   Full Release Pipeline
echo %title_bar%
echo.
echo [1/4] Syncing dependencies...
call uv sync --group dev --group build
if %ERRORLEVEL% neq 0 goto error_pipeline

echo [2/4] Running headless test suite...
call uv run pytest
if %ERRORLEVEL% neq 0 goto error_pipeline

echo [3/4] Building standalone package...
call uv run python tools/build_release.py
if %ERRORLEVEL% neq 0 goto error_pipeline

echo [4/4] Generating release notes...
for /f "usebackq tokens=*" %%i in (`call uv run python -c "import tomllib; print(tomllib.load(open('pyproject.toml', 'rb'))['project']['version'])"`) do set "pipeline_ver=%%i"
echo Automatically detected version: !pipeline_ver!
call uv run python tools/release_notes.py stable --version "!pipeline_ver!" --output notes.md
if %ERRORLEVEL% neq 0 (
    echo [WARNING] Failed to generate stable notes. Attempting nightly fallback...
    call uv run python tools/release_notes.py nightly --output notes.md
)
echo.
echo [SUCCESS] Full release pipeline completed successfully!
echo - Standalone package built in dist/
echo - Release notes generated in notes.md
echo.
if defined cli_mode exit /b 0
pause
goto menu

:run_all_cli
goto run_all

:error_pipeline
echo.
echo [ERROR] Pipeline failed during execution. Error code: %ERRORLEVEL%
if defined cli_mode exit /b %ERRORLEVEL%
pause
goto menu

:run_git_status
echo.
echo %title_bar%
echo   Git Status
echo %title_bar%
git status
echo.
if defined cli_mode exit /b 0
pause
goto menu

:run_git_commit
echo.
echo %title_bar%
echo   Git Stage ^& Commit
echo %title_bar%
set /p file_choice="Enter file path(s) to stage (e.g. src/file.py, press Enter for all '.'): "
if "!file_choice!"=="" set "file_choice=."
echo Staging files: !file_choice!...
git add !file_choice!
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Git add failed.
    pause
    goto menu
)
echo.
set /p commit_msg="Enter commit message: "
if "!commit_msg!"=="" (
    echo [ERROR] Commit message cannot be empty.
    pause
    goto menu
)
git commit -m "!commit_msg!"
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Git commit failed.
    pause
    goto menu
)
echo [SUCCESS] Changes committed successfully.
echo.
pause
goto menu

:run_git_commit_cli
shift
set "commit_msg=%~1"
if "!commit_msg!"=="" (
    echo [ERROR] No commit message specified.
    goto usage
)
echo Staging all changes...
git add .
git commit -m "!commit_msg!"
exit /b %ERRORLEVEL%

:run_git_push
echo.
echo %title_bar%
echo   Git Push to Origin
echo %title_bar%
for /f "usebackq tokens=*" %%i in (`git branch --show-current 2^>nul`) do set "current_branch=%%i"
echo Pushing branch '!current_branch!' to origin...
git push origin !current_branch!
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Git push failed.
    if defined cli_mode exit /b %ERRORLEVEL%
    pause
    goto menu
)
echo [SUCCESS] Pushed changes successfully!
echo.
if defined cli_mode exit /b 0
pause
goto menu

:run_git_tag
echo.
echo %title_bar%
echo   Git Tag Release
echo %title_bar%
for /f "usebackq tokens=*" %%i in (`call uv run python -c "import tomllib; print(tomllib.load(open('pyproject.toml', 'rb'))['project']['version'])" 2^>nul`) do set "default_ver=v%%i"
set /p tag_name="Enter tag name [default: !default_ver!]: "
if "!tag_name!"=="" set "tag_name=!default_ver!"
set /p tag_msg="Enter tag annotation message (optional): "

if "!tag_msg!"=="" (
    git tag !tag_name!
) else (
    git tag -a !tag_name! -m "!tag_msg!"
)
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Creating tag failed.
    pause
    goto menu
)
echo Pushing tag '!tag_name!' to origin...
git push origin !tag_name!
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Pushing tag failed.
    pause
    goto menu
)
echo [SUCCESS] Tag created and pushed successfully.
echo.
pause
goto menu

:run_git_tag_cli
shift
set "tag_name=%~1"
set "tag_msg=%~2"
if "!tag_name!"=="" (
    echo [ERROR] No tag name specified.
    goto usage
)
if "!tag_msg!"=="" (
    git tag !tag_name!
) else (
    git tag -a !tag_name! -m "!tag_msg!"
)
if %ERRORLEVEL% neq 0 exit /b %ERRORLEVEL%
git push origin !tag_name!
exit /b %ERRORLEVEL%

:run_version_edit
echo.
echo %title_bar%
echo   Bump / Edit Project Version
echo %title_bar%
for /f "usebackq tokens=*" %%i in (`call uv run python -c "import tomllib; print(tomllib.load(open('pyproject.toml', 'rb'))['project']['version'])" 2^>nul`) do set "current_ver=%%i"
echo Current Version: !current_ver!
echo.
set /p new_ver="Enter new version number (e.g. 1.7.0): "
if "!new_ver!"=="" (
    echo Edit canceled.
    pause
    goto menu
)

:: Update pyproject.toml using python script
call uv run python tools/set_version.py !new_ver!
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Failed to edit pyproject.toml.
    pause
    goto menu
)
echo.
echo Version updated in pyproject.toml to !new_ver!. Syncing environment...
call uv sync
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Sync failed after version update.
    pause
    goto menu
)
echo [SUCCESS] Version updated and environment synchronized!
echo.
pause
goto menu

:run_version_cli
shift
set "new_ver=%~1"
if "!new_ver!"=="" (
    echo [ERROR] No version number specified.
    goto usage
)
call uv run python tools/set_version.py %new_ver%
if %ERRORLEVEL% neq 0 exit /b %ERRORLEVEL%
call uv sync
exit /b %ERRORLEVEL%

:usage
echo Usage: release.bat [command] [args...]
echo.
echo Available Commands:
echo   sync                      Sync dev and build dependencies
echo   test                      Run headless test suite
echo   build [args...]           Compile standalone package (arguments forwarded to build_release.py)
echo   notes [args...]           Generate release notes (arguments forwarded to release_notes.py)
echo   all                       Run full pipeline (Sync, Test, Build, Notes)
echo   status                    Show git repository status
echo   commit "message"          Stage all files and commit with message
echo   push                      Push active branch to remote origin
echo   tag name ["message"]      Create a git release tag and push it
echo   version num               Directly set project version and run uv sync
echo.
exit /b 1

:end
exit /b 0
