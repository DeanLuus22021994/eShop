@echo off
setlocal enabledelayedexpansion
set "LOGFILE=%~dp0cleanup_error.log"
set "SUCCESS_FLAG=%TEMP%\cleanup_success_%RANDOM%.tmp"
set "PATHS_FILE=%TEMP%\paths_%RANDOM%.tmp"

:: Clear screen and show header
cls
echo Scanning for bin and obj folders...
echo.

:: Collect all paths first
> "%PATHS_FILE%" (
    for /d /r %%d in (bin) do if /i "%%~nxd"=="bin" echo %%d
    for /d /r %%d in (obj) do if /i "%%~nxd"=="obj" echo %%d
)

:: Count total folders
set /a count=0
for /f %%a in ('type "%PATHS_FILE%" ^| find /c /v ""') do set count=%%a

:: Display paths with counter
echo Found %count% folders to delete:
echo.
set /a current=0
for /f "delims=" %%a in (%PATHS_FILE%) do (
    set /a current+=1
    echo [!current!/%count%] %%a
)
echo.

:: Prompt for confirmation
echo Press any key to proceed with deletion, or close window to cancel...
pause > nul

:: Proceed with deletion after confirmation
> nul 2>&1 (
    :: Using multiple threads for parallel processing
    start /b cmd /c "for /f "delims=" %%a in (%PATHS_FILE%) do if exist "%%a\*" rd /s /q "%%a""
    
    :: Wait for background processes
    timeout /t 2 /nobreak > nul
    
    :: Verify deletions
    set "error_count=0"
    for /f "delims=" %%a in (%PATHS_FILE%) do (
        if exist "%%a" set /a "error_count+=1"
    )
    
    if !error_count! equ 0 (
        :: Signal success by creating flag file
        echo 1 > "%SUCCESS_FLAG%"
        exit /b 0
    ) else (
        exit /b 1
    )
) || (
    :: If any error occurred
    echo ERROR - ANY KEY TO OPEN LOG FILE
    
    :: Create detailed error log
    echo Error occurred during cleanup at %DATE% %TIME% > "%LOGFILE%"
    echo Current Directory: %CD% >> "%LOGFILE%"
    echo. >> "%LOGFILE%"
    echo Failed to delete the following folders: >> "%LOGFILE%"
    
    :: Log failed deletions
    for /f "delims=" %%a in (%PATHS_FILE%) do (
        if exist "%%a" (
            echo %%a >> "%LOGFILE%"
            echo Access check: >> "%LOGFILE%"
            icacls "%%a" >> "%LOGFILE%" 2>&1
            echo. >> "%LOGFILE%"
        )
    )
    
    pause > nul
    start notepad "%LOGFILE%"
    del "%SUCCESS_FLAG%" 2>nul
    exit /b 1
)

:: Check for success and display message
if exist "%SUCCESS_FLAG%" (
    cls
    echo SUCCESS
    timeout /t 1 /nobreak > nul
)

:: Cleanup temporary files
del "%SUCCESS_FLAG%" 2>nul
del "%PATHS_FILE%" 2>nul

exit /b %ERRORLEVEL%