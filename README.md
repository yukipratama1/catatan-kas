# Catatan Kas (Flutter)

Aplikasi pencatat keuangan pribadi: ringkasan, kalender (hari/minggu/bulan),
pendapatan, pengeluaran, utang & piutang, aset, statistik, dan ekspor PDF
(invoice + laporan bulanan). Data tersimpan di perangkat.

## Cara membuat APK lewat GitHub
1. Buat repository baru di GitHub, lalu upload **seluruh isi folder ini**
   (termasuk folder `.github`, `lib`, dan `pubspec.yaml`).
2. Buka tab **Actions** -> workflow **Build APK** (jalan otomatis setiap push,
   atau klik **Run workflow**).
3. Tunggu sekitar 5-10 menit sampai hijau.
4. Buka run tersebut -> bagian **Artifacts** -> unduh **catatan-kas-apk**.
5. Ekstrak zip, kirim `app-release.apk` ke HP, lalu install
   (izinkan "Install dari sumber tidak dikenal").

Folder `android/` dibuat otomatis oleh workflow, jadi tidak perlu ada di repo.

## Jalankan di komputer sendiri
```
flutter create --platforms=android .
flutter pub get
flutter run
```
(Jika `flutter create` menimpa `lib/main.dart`, kembalikan dari repo.)
