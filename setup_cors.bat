@echo off
echo ========================================
echo Firebase Storage CORS Ayarlari
echo ========================================
echo.

echo 1. Google Cloud SDK kurulu olmali
echo 2. Firebase projenizde authentication yapilmis olmali
echo 3. Bu script'i Firebase proje klasorunde calistirin
echo.

echo CORS dosyasi olusturuluyor...
echo {> cors.json
echo   "cors": [>> cors.json
echo     {>> cors.json
echo       "origin": ["*"],>> cors.json
echo       "method": ["GET", "POST", "PUT", "DELETE", "OPTIONS"],>> cors.json
echo       "maxAgeSeconds": 3600,>> cors.json
echo       "responseHeader": ["Content-Type", "Authorization"]>> cors.json
echo     }>> cors.json
echo   ]>> cors.json
echo }>> cors.json

echo.
echo CORS ayarlari uygulaniyor...
gsutil cors set cors.json gs://athlor-27900.firebasestorage.app

echo.
echo CORS ayarlari kontrol ediliyor...
gsutil cors get gs://athlor-27900.firebasestorage.app

echo.
echo Temizlik yapiliyor...
del cors.json

echo.
echo ========================================
echo CORS ayarlari tamamlandi!
echo ========================================
pause
