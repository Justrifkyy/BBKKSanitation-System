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

Siapkan nilai konfigurasi Firebase server/browser dan Cloudflare R2 pada
`.env.local` berdasarkan `.env.example`, lalu jalankan:

```bash
npm install
npm run dev
```

Route `/dashboard` memerlukan cookie sesi yang dibuat setelah login Admin
berhasil. API data tetap memverifikasi Firebase ID token dan role pengguna.
Pengguna dengan role selain `validator_admin` tidak dapat masuk ke portal Admin.

## Penyimpanan media

Tanda tangan PNG/SVG, foto, video, dan berkas hasil disimpan privat di
Cloudflare R2. Firestore hanya menyimpan object path, metadata, dan relasi
berkas. Upload memakai URL sementara yang diterbitkan API setelah memverifikasi
Firebase ID token dan hak akses pengguna.

Untuk menyiapkan R2:

1. Buat bucket R2 dengan storage class **Standard** dan tetap non-public.
2. Buat token/API key R2 yang hanya memiliki izin baca/tulis untuk bucket itu.
3. Isi `R2_ACCOUNT_ID`, `R2_BUCKET_NAME`, `R2_ACCESS_KEY_ID`, dan
   `R2_SECRET_ACCESS_KEY` di `.env.local` untuk lokal dan environment secrets
   pada hosting web. Jangan masukkan nilai ini ke aplikasi mobile atau Git.
4. Restart server web agar variabel baru dimuat.

Free tier R2 saat ini mencakup 10 GB-month storage Standard, 1 juta operasi
Class A, 10 juta operasi Class B per bulan, dan egress gratis. Pemakaian di atas
kuota gratis dapat dikenakan biaya; pantau penggunaan dan billing di Cloudflare.
