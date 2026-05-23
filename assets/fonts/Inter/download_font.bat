@echo off
echo Downloading Inter font...
echo.

curl -L "https://github.com/rsms/inter/releases/download/v4.0/Inter-4.0.zip" -o "inter.zip"

if exist "inter.zip" (
    echo.
    echo Download complete! Extracting...
    tar -xf "inter.zip" -C .
    
    echo.
    echo Copying font files...
    copy "Inter Desktop\Inter-Regular.ttf" "Inter-Regular.ttf"
    copy "Inter Desktop\Inter-Medium.ttf" "Inter-Medium.ttf"
    copy "Inter Desktop\Inter-SemiBold.ttf" "Inter-SemiBold.ttf"
    copy "Inter Desktop\Inter-Bold.ttf" "Inter-Bold.ttf"
    
    echo.
    echo Cleaning up...
    del "inter.zip"
    rmdir /s /q "Inter Desktop"
    rmdir /s /q "Inter Web"
    del "LICENSE.txt"
    
    echo.
    echo Done! Inter font installed successfully.
) else (
    echo.
    echo Download failed. Please download manually from:
    echo https://fonts.google.com/specimen/Inter
)

pause
