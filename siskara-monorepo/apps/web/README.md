# SISKARA Web Admin

Portal internal SISKARA untuk administrator BBKK Makassar. Aplikasi web
dimulai langsung dari halaman login; tidak ada landing page publik. Halaman
utama yang tersedia saat ini:

- `/login` — autentikasi Firebase untuk akun dengan custom claim
  `role: "validator_admin"`.
- `/dashboard` — ringkasan pengajuan, statistik, pencarian, filter, dan ekspor
  CSV dari pengajuan yang sedang ditampilkan. Dashboard bersifat read-only
  untuk keputusan verifikasi.
- `/` — mengarahkan pengguna ke `/login`.

## Menjalankan aplikasi

Siapkan nilai konfigurasi Firebase server dan browser pada `.env.local`
berdasarkan `.env.example`, lalu jalankan:

```bash
npm install
npm run dev
```

Route `/dashboard` memerlukan cookie sesi yang dibuat setelah login Admin
berhasil. API data tetap memverifikasi Firebase ID token dan role pengguna.
Pengguna dengan role selain `validator_admin` tidak dapat masuk ke portal Admin.
