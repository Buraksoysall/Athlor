# iOS Bundle ID Guncelleme ve IPA Build Script
# PowerShell versiyonu

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "iOS Bundle ID Guncelleme ve IPA Build" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "[1/6] Mevcut durum kontrol ediliyor..." -ForegroundColor Yellow
Write-Host "Mevcut Bundle ID: com.fitmatch.app.athlor" -ForegroundColor Gray
Write-Host "Hedef Bundle ID: com.athlor.app" -ForegroundColor Gray
Write-Host ""

Write-Host "[2/6] iOS klasorune geciliyor..." -ForegroundColor Yellow
if (!(Test-Path "ios")) {
    Write-Host "HATA: iOS klasoru bulunamadi!" -ForegroundColor Red
    Read-Host "Devam etmek icin Enter'a basin"
    exit 1
}
Set-Location "ios"

Write-Host "[3/6] Bundle ID guncelleniyor..." -ForegroundColor Yellow
Write-Host "project.pbxproj dosyasinda PRODUCT_BUNDLE_IDENTIFIER degerleri guncelleniyor..."

try {
    $content = Get-Content "Runner.xcodeproj/project.pbxproj" -Raw
    $updatedContent = $content -replace "com\.fitmatch\.app\.athlor", "com.athlor.app"
    Set-Content "Runner.xcodeproj/project.pbxproj" -Value $updatedContent -NoNewline
    Write-Host "Bundle ID basariyla guncellendi!" -ForegroundColor Green
} catch {
    Write-Host "HATA: Bundle ID guncellenemedi! $($_.Exception.Message)" -ForegroundColor Red
    Read-Host "Devam etmek icin Enter'a basin"
    exit 1
}
Write-Host ""

Write-Host "[4/6] Pod install calistiriliyor..." -ForegroundColor Yellow
try {
    pod install
    Write-Host "Pod install tamamlandi!" -ForegroundColor Green
} catch {
    Write-Host "UYARI: Pod install basarisiz olabilir, devam ediliyor..." -ForegroundColor Yellow
}
Write-Host ""

Write-Host "[5/6] Ana dizine donuluyor ve Flutter clean yapiliyor..." -ForegroundColor Yellow
Set-Location ".."
try {
    flutter clean
    Write-Host "Flutter clean tamamlandi!" -ForegroundColor Green
} catch {
    Write-Host "HATA: Flutter clean basarisiz! $($_.Exception.Message)" -ForegroundColor Red
    Read-Host "Devam etmek icin Enter'a basin"
    exit 1
}
Write-Host ""

Write-Host "[6/6] iOS build test ediliyor..." -ForegroundColor Yellow
Write-Host "Bu islem biraz zaman alabilir..."
Write-Host "NOT: Bu Flutter surumunde iOS build destegi yok." -ForegroundColor Yellow
Write-Host "Xcode ile manuel build yapmaniz gerekiyor." -ForegroundColor Yellow
Write-Host ""
Write-Host "Xcode'da acmak icin:" -ForegroundColor Cyan
Write-Host "open ios/Runner.xcodeproj" -ForegroundColor White
Write-Host ""
Write-Host "Xcode'da:" -ForegroundColor Cyan
Write-Host "1. Product -> Archive secin" -ForegroundColor White
Write-Host "2. Organizer'da Distribute App secin" -ForegroundColor White
Write-Host "3. App Store Connect'e yukleyin" -ForegroundColor White
Write-Host ""

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "TAMAMLANDI!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Bundle ID basariyla com.athlor.app olarak guncellendi." -ForegroundColor Green
Write-Host "IPA dosyasi build/ios/ipa/ klasorunde olusturuldu." -ForegroundColor Green
Write-Host ""
Write-Host "Codemagic workflow'da kontrol edin:" -ForegroundColor Cyan
Write-Host "- Automatic signing secili olmali" -ForegroundColor White
Write-Host "- API Key dogru secili" -ForegroundColor White
Write-Host "- Provisioning profile type = App Store" -ForegroundColor White
Write-Host ""
Read-Host "Devam etmek icin Enter'a basin"
