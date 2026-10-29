# LINKED — Peer Learning Platform

LINKED adalah platform peer learning yang membantu mahasiswa menemukan mentor sesama mahasiswa, mengatur sesi belajar, mengikuti course, memantau progres, dan berbagi kesempatan belajar dalam satu tempat.

> **Status:** MVP siap untuk tahap persiapan pilot. Sebelum digunakan lebih luas, lakukan validasi akhir pada konfigurasi deployment, keamanan, email autentikasi, dan dokumen privasi/ketentuan.

## Fitur utama

- **Akun dan profil:** pendaftaran, login, profil pengguna, pengaturan akun, dan alur pemulihan kata sandi.
- **Direktori mentor:** pencarian dan filter mentor, profil publik, bidang keahlian, topik, mode belajar, dan status verifikasi.
- **Pendaftaran mentor:** pengajuan profil dan keahlian, peninjauan oleh admin, serta pengajuan perubahan profil.
- **Learning Requests:** learner dapat mengirim permintaan belajar; mentor dapat menerima atau menolak permintaan yang ditujukan kepadanya.
- **Sesi belajar:** jadwal terkonfirmasi, catatan sesi, dan status penyelesaian.
- **Course dan progres:** course Full Course, modul, dan penyimpanan progres pembelajaran.
- **Reviews dan rating:** learner dapat menilai sesi yang selesai; ulasan ditangani melalui alur moderasi.
- **Admin dashboard:** peninjauan profil mentor, pengelolaan status, serta moderasi ulasan.
- **Opportunities:** pengelolaan dan penayangan kesempatan belajar.
- **Notifikasi dalam aplikasi:** pemberitahuan aktivitas dan status dibaca/belum dibaca.
- **Bantuan & masukan:** tiket laporan pengguna dan tanggapan admin.
- **Pengalaman penggunaan:** Light/Dark Mode, layout responsif, navigasi mobile, micro-interactions, serta maskot LINKED.
- **Informasi pengguna:** halaman Kebijakan Privasi dan Ketentuan Penggunaan.

## Teknologi

- HTML, CSS, dan JavaScript dalam satu file frontend (`index.html`).
- Supabase Auth untuk autentikasi pengguna.
- PostgreSQL dengan Row Level Security (RLS) untuk data aplikasi.
- Netlify untuk hosting frontend (jika repository terhubung ke site Netlify).
- Fontshare untuk font Cabinet Grotesk dan Satoshi; jika font eksternal tidak tersedia, browser menggunakan font fallback.

Frontend memakai **publishable key** untuk terhubung ke layanan aplikasi. Jangan pernah menaruh `service_role` key, secret key, password, atau kredensial privat di `index.html`, README, atau repository.

## Menjalankan secara lokal

Disarankan membuka aplikasi melalui local web server, bukan dengan klik ganda pada file HTML, agar alur autentikasi dan redirect berjalan dengan baik.

1. Pastikan Python tersedia, lalu buka terminal/Command Prompt di folder yang berisi `index.html`.
2. Jalankan:

   ```bash
   py -m http.server 5500
   ```

   Jika perintah `py` tidak tersedia, coba `python -m http.server 5500`.

3. Buka [http://localhost:5500/index.html](http://localhost:5500/index.html).
4. Untuk menghentikan server, kembali ke terminal dan tekan `Ctrl+C`.

Tidak diperlukan instalasi Node.js untuk menjalankan frontend ini.

## Konfigurasi autentikasi lokal

Aplikasi menggunakan URL proyek dan publishable key yang dikonfigurasi di bagian JavaScript pada `index.html`. Pastikan nilainya mengarah ke proyek yang benar.

Di pengaturan URL autentikasi proyek, tambahkan redirect lokal yang digunakan saat pengembangan, misalnya:

- `http://localhost:5500/**`
- `http://127.0.0.1:5500/**`

Pastikan Site URL dan redirect untuk domain produksi juga sesuai dengan domain yang benar-benar digunakan. Nama domain di konfigurasi harus disesuaikan apabila hosting berubah.

## Struktur database

File `linked-consolidated-setup.sql` berisi referensi setup gabungan untuk **proyek database baru yang kosong**. File ini menggabungkan skema dan setup fitur seperti:

- `profiles`, `mentor_profiles`, `subjects`, `mentor_expertise`
- `learning_requests`, `sessions`
- `courses`, `course_modules`, `module_progress`
- `reviews`, `opportunities`
- `linked_admin_users`, `linked_notifications`, `support_tickets`

### Penting tentang SQL

- **Jangan jalankan `linked-consolidated-setup.sql` pada database LINKED yang sudah berjalan dan berisi data.** File tersebut ditujukan sebagai referensi bootstrap untuk proyek baru, bukan migration pembaruan untuk database yang sedang digunakan.
- Untuk mengubah database yang ada, siapkan migration baru yang spesifik dan uji terlebih dahulu pada proyek staging/salinan.
- Script SQL tidak otomatis dijalankan oleh GitHub atau Netlify. Commit `index.html` memperbarui frontend; perubahan database memerlukan proses SQL/migration tersendiri.
- Sebelum membuat database baru, tinjau placeholder email admin dalam file SQL dan sesuaikan dengan akun admin yang sudah terdaftar di proyek baru.
- Pastikan RLS aktif dan kebijakan akses sudah diuji. Jangan memberikan hak admin kepada pengguna umum.

## Deploy ke Netlify melalui GitHub

Jika Netlify sudah terhubung ke repository GitHub dan branch produksi (misalnya `main`):

1. Perbarui file `index.html` pada root repository dengan versi yang ingin dirilis.
2. Commit perubahan ke branch produksi.
3. Periksa tab **Deploys** di Netlify dan tunggu deployment berstatus **Published**.
4. Buka domain produksi, lakukan hard refresh, lalu periksa halaman login, tampilan mobile, dan fitur yang baru berubah.

Jangan membuat site baru jika site yang sekarang sudah dikonfigurasi dengan benar. Perubahan database tidak ikut ter-deploy hanya karena file HTML di-commit.

## Alur penggunaan yang disarankan

1. Daftar atau masuk sebagai learner.
2. Buka **Find a mentor**, cari mentor yang sudah disetujui dan aktif, lalu lihat profilnya.
3. Kirim **Learning Request** dan cek statusnya pada halaman **Learning requests**.
4. Masuk dengan akun mentor yang dituju untuk menerima atau menolak request.
5. Setelah request dikonfirmasi, buka detail sesi dan gunakan catatan sesi sesuai alur yang tersedia.
6. Tandai sesi selesai; learner kemudian dapat memberikan ulasan sesuai aturan aplikasi.
7. Buka **My learning** untuk mengikuti course dan memperbarui progres modul.
8. Gunakan **Opportunities**, notifikasi, dan **Bantuan & masukan** untuk menguji alur terkait.
9. Masuk dengan akun admin yang sudah diotorisasi untuk meninjau pendaftaran mentor, moderasi ulasan, serta pengelolaan konten yang tersedia.

## Sebelum pilot dengan pengguna lain

- Periksa bahwa konfigurasi Auth menggunakan domain/redirect yang benar untuk lingkungan pilot.
- Pastikan akun admin yang berwenang sudah disiapkan dan akses admin tidak dapat diberikan sendiri oleh pengguna biasa.
- Uji RLS dan akses data menggunakan akun learner, mentor, dan admin yang berbeda.
- Tinjau Kebijakan Privasi dan Ketentuan Penggunaan bersama pihak yang berwenang sebelum peluncuran lebih luas.
- Tetapkan prosedur dukungan, penghapusan akun/data, backup, dan penanganan laporan keamanan.
- Lakukan satu pemeriksaan akhir pada desktop dan perangkat mobile setelah deployment.

## Catatan data demo

Aplikasi dapat memiliki tampilan demo atau contoh data untuk membantu pengguna memahami alur. Bedakan data demonstrasi dari data yang benar-benar dikirim pengguna. Jangan memperlakukan nama, aktivitas, atau ulasan contoh sebagai bukti penggunaan aktual.

---

**LINKED — Belajar bareng, tumbuh bareng.**
