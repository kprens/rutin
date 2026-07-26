# Poppins fontu — buraya eklenecek dosyalar

Kod tarafı Poppins'i kullanmaya hazır (`lib/theme.dart` → `fontFamily: 'Poppins'`),
ancak bu ortamda internet erişimi kısıtlı olduğu için gerçek `.ttf` dosyaları
otomatik indirilemedi. Aşağıdaki adımları kendi makinende tamamla:

1. https://fonts.google.com/specimen/Poppins adresinden şu dört ağırlığı indir:
   - Poppins-Regular.ttf
   - Poppins-Medium.ttf     (weight 500)
   - Poppins-SemiBold.ttf   (weight 600)
   - Poppins-Bold.ttf       (weight 700)
2. İndirdiğin `.ttf` dosyalarını bu klasöre (`assets/fonts/`) kopyala.
3. `pubspec.yaml`'daki `flutter:` bloğuna şunu ekle (henüz eklenmedi —
   dosyalar burada olmadan eklenirse `flutter build`/`flutter run` hata verir):

   ```yaml
   flutter:
     fonts:
       - family: Poppins
         fonts:
           - asset: assets/fonts/Poppins-Regular.ttf
           - asset: assets/fonts/Poppins-Medium.ttf
             weight: 500
           - asset: assets/fonts/Poppins-SemiBold.ttf
             weight: 600
           - asset: assets/fonts/Poppins-Bold.ttf
             weight: 700
   ```

4. `flutter pub get` çalıştır. Tema zaten `fontFamily: 'Poppins'` kullanıyor,
   başka hiçbir kod değişikliği gerekmiyor.
