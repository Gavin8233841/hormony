@echo off
@rem ##########################################################################
@rem
@rem  Hvigor wrapper for C4-AI HarmonyOS project
@rem  Calls DevEco Studio's bundled hvigorw.bat with correct environment
@rem
@rem ##########################################################################

@rem Set local scope for the variables with windows NT shell
if "%OS%"=="Windows_NT" setlocal

@rem DevEco Studio installation path
set DEVECO_PATH=C:\Program Files\Huawei\DevEco Studio

@rem Environment variables required by hvigorw
set NODE_HOME=%DEVECO_PATH%\tools\node
set JAVA_HOME=%DEVECO_PATH%\jbr
set DEVECO_SDK_HOME=%DEVECO_PATH%\sdk

@rem Path to DevEco Studio's bundled hvigorw.bat
set DEV_HVIGORW=%DEVECO_PATH%\tools\hvigor\bin\hvigorw.bat

if not exist "%DEV_HVIGORW%" (
    echo ERROR: DevEco Studio hvigorw.bat not found at: %DEV_HVIGORW%
    echo Please verify DevEco Studio installation path.
    exit /b 1
)

@rem Execute DevEco Studio's hvigorw with all passed arguments
call "%DEV_HVIGORW%" %*

if "%OS%" == "Windows_NT" endlocal
