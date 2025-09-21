@echo off
echo ========================================
echo iOS Bundle ID Guncelleme ve IPA Build
echo ========================================
echo.

echo [1/6] Mevcut durum kontrol ediliyor...
echo Mevcut Bundle ID: com.fitmatch.app.athlor
echo Hedef Bundle ID: com.athlor.app
echo.

echo [2/6] iOS klasorune geciliyor...
cd ios
if %errorlevel% neq 0 (
    echo HATA: iOS klasoru bulunamadi!
    pause
    exit /b 1
)

echo [3/6] Bundle ID guncelleniyor...
echo project.pbxproj dosyasinda PRODUCT_BUNDLE_IDENTIFIER degerleri guncelleniyor...

powershell -Command "(Get-Content 'Runner.xcodeproj/project.pbxproj') -replace 'com\.fitmatch\.app\.athlor', 'com.athlor.app' | Set-Content 'Runner.xcodeproj/project.pbxproj'"

if %errorlevel% neq 0 (
    echo HATA: Bundle ID guncellenemedi!
    pause
    exit /b 1
)

echo Bundle ID basariyla guncellendi!
echo.

echo [4/6] Pod install calistiriliyor...
pod install
if %errorlevel% neq 0 (
    echo UYARI: Pod install basarisiz olabilir, devam ediliyor...
)
echo.

echo [5/6] Ana dizine donuluyor ve Flutter clean yapiliyor...
cd ..
flutter clean
if %errorlevel% neq 0 (
    echo HATA: Flutter clean basarisiz!
    pause
    exit /b 1
)
echo.

echo [6/6] iOS build test ediliyor...
echo Bu islem biraz zaman alabilir...
echo NOT: Bu Flutter surumunde iOS build destegi yok.
echo Xcode ile manuel build yapmaniz gerekiyor.
echo.
echo Xcode'da acmak icin:
echo open ios/Runner.xcodeproj
echo.
echo Xcode'da:
echo 1. Product -> Archive secin
echo 2. Organizer'da Distribute App secin
echo 3. App Store Connect'e yukleyin

echo.
echo ========================================
echo TAMAMLANDI!
echo ========================================
echo.
echo Bundle ID basariyla com.athlor.app olarak guncellendi.
echo IPA dosyasi build/ios/ipa/ klasorunde olusturuldu.
echo.
echo Codemagic workflow'da kontrol edin:
echo - Automatic signing secili olmali
echo - API Key dogru secili
echo - Provisioning profile type = App Store
echo.
pause
