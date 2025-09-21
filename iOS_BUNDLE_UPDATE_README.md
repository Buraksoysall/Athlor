# iOS Bundle ID Güncelleme Rehberi

Bu rehber, iOS uygulamanızın Bundle ID'sini `com.fitmatch.app.athlor`'dan `com.athlor.app`'e güncellemek için hazırlanmıştır.

## ✅ Tamamlanan İşlemler

1. **Bundle ID Güncellendi**: `ios/Runner.xcodeproj/project.pbxproj` dosyasında tüm `PRODUCT_BUNDLE_IDENTIFIER` değerleri `com.athlor.app` olarak güncellendi.

2. **Flutter Clean**: Eski build cache'leri temizlendi.

## 📁 Oluşturulan Dosyalar

- `ios_bundle_update.bat` - Windows Batch scripti
- `ios_bundle_update.ps1` - PowerShell scripti
- `iOS_BUNDLE_UPDATE_README.md` - Bu rehber

## 🚀 Kullanım

### Otomatik Script Kullanımı

**Windows Batch:**
```cmd
ios_bundle_update.bat
```

**PowerShell:**
```powershell
.\ios_bundle_update.ps1
```

### Manuel Adımlar

1. **iOS klasörüne git:**
   ```cmd
   cd ios
   ```

2. **Pod install (eğer CocoaPods yüklüyse):**
   ```cmd
   pod install
   ```

3. **Ana dizine dön ve Flutter clean:**
   ```cmd
   cd ..
   flutter clean
   ```

4. **Xcode ile build:**
   ```cmd
   open ios/Runner.xcodeproj
   ```

## 🔧 Xcode'da Yapılacaklar

1. **Xcode'u aç:**
   - `ios/Runner.xcodeproj` dosyasını açın

2. **Archive oluştur:**
   - Product → Archive seçin
   - Build tamamlandığında Organizer açılacak

3. **App Store'a yükle:**
   - Distribute App seçin
   - App Store Connect seçin
   - Upload seçin

## ⚠️ Önemli Notlar

- **CocoaPods**: Eğer `pod install` komutu çalışmıyorsa, CocoaPods yüklü değildir. Bu durumda Xcode build sırasında otomatik olarak çözülecektir.

- **Flutter iOS Build**: Bu Flutter sürümünde `flutter build ipa` komutu desteklenmiyor. Xcode ile manuel build yapmanız gerekiyor.

- **Codemagic**: Codemagic workflow'da şunları kontrol edin:
  - Automatic signing seçili olmalı
  - API Key doğru seçili
  - Provisioning profile type = App Store

## 🔍 Doğrulama

Bundle ID'nin doğru güncellendiğini kontrol etmek için:

```cmd
grep "PRODUCT_BUNDLE_IDENTIFIER" ios/Runner.xcodeproj/project.pbxproj
```

Çıktıda `com.athlor.app` değerlerini görmelisiniz.

## 📞 Sorun Giderme

- **Build hatası**: Xcode'da "Clean Build Folder" yapın (Product → Clean Build Folder)
- **Signing hatası**: Apple Developer hesabınızda Bundle ID'nin kayıtlı olduğundan emin olun
- **Pod hatası**: `ios` klasöründe `Podfile.lock` dosyasını silin ve tekrar deneyin

---

**Son Güncelleme**: $(Get-Date -Format "yyyy-MM-dd HH:mm")
