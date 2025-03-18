@echo off
setlocal

set LIBS_DIR=libs
mkdir %LIBS_DIR%
cd %LIBS_DIR%

:: ImGui Repo
set REPO1_NAME=imgui
set REPO1_URL=https://github.com/ocornut/imgui.git
set REPO1_TAG=v1.91.8

:: GLFW Precompiled Binaries
set GLFW_VERSION=3.4
set GLFW_ZIP=glfw-%GLFW_VERSION%.bin.Win64.zip
set GLFW_URL=https://github.com/glfw/glfw/releases/download/%GLFW_VERSION%/%GLFW_ZIP%
set GLFW_DIR=glfw


:: ImGui
if not exist %REPO1_NAME% (
    echo Cloning %REPO1_NAME% at tag %REPO1_TAG%...
    git clone --branch %REPO1_TAG% --depth 1 %REPO1_URL% %REPO1_NAME%
) else (
    echo Checking out %REPO1_NAME% at tag %REPO1_TAG%...
    cd %REPO1_NAME%
    git fetch --tags
    git checkout %REPO1_TAG%
    cd ..
)

:: GLFW
if not exist %GLFW_DIR% (
    echo Downloading GLFW %GLFW_VERSION%...
    curl -L -o %GLFW_ZIP% %GLFW_URL%
    echo Extracting GLFW...
    powershell -Command "Expand-Archive -Force '%GLFW_ZIP%' ."
    rename glfw-%GLFW_VERSION%.bin.Win64 %GLFW_DIR%
    del %GLFW_ZIP%
) else (
    echo GLFW is already downloaded.
)

:: GLFW Cleanup
cd %GLFW_DIR%
for /d %%D in (*) do (
    if /I not "%%D"=="include" if /I not "%%D"=="lib-static-ucrt" (
        echo Deleting directory: %%D
        rmdir /s /q "%%D"
    )
)
del LICENSE*.* /Q 2>nul
del README*.* /Q 2>nul
cd ..

:: Rename glfw3dll.lib to glfw3.lib
cd %GLFW_DIR%\lib-static-ucrt
rename glfw3dll.lib glfw3.lib
cd ..\..

echo All libraries are checked out at the specified tags.
exit /b
