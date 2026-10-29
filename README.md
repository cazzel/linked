# LINKED --- Peer Learning Platform

LINKED adalah platform peer learning yang membantu pengguna menemukan
mentor, mengajukan sesi belajar, mengikuti course, memantau progres, dan
menemukan kesempatan belajar dalam satu tempat.

> **Status:** MVP untuk persiapan pilot. Sebelum digunakan oleh pengguna
> yang lebih luas, lakukan pemeriksaan akhir pada konfigurasi
> deployment, keamanan database, autentikasi, serta dokumen privasi dan
> ketentuan penggunaan.

## Fitur

-   **Akun dan profil:** pendaftaran, login, profil pengguna, pengaturan
    akun, dan alur pemulihan kata sandi.
-   **Direktori mentor:** pencarian dan filter, profil mentor, bidang
    keahlian, serta status verifikasi.
-   **Pengajuan mentor:** pengajuan profil dan keahlian, dengan alur
    peninjauan admin.
-   **Learning Requests:** learner dapat mengirim permintaan belajar;
    mentor dapat meninjau dan menerima atau menolak permintaan yang
    ditujukan kepadanya.
-   **Pilihan pembelajaran:** alur Single Session dan Full Course
    ditampilkan sebagai jenis pengalaman belajar yang berbeda.
-   **Sesi belajar:** informasi jadwal dan status sesi, serta catatan
    sesi sesuai alur yang tersedia.
-   **Course dan progres:** course, modul, dan penyimpanan progres
    pembelajaran.
-   **Reviews dan rating:** ulasan setelah sesi selesai, dengan dukungan
    alur moderasi.
-   **Admin dashboard:** peninjauan pengajuan mentor dan pengelolaan
    fitur administratif yang tersedia.
-   **Opportunities:** penayangan dan pengelolaan kesempatan belajar.
-   **Notifikasi dalam aplikasi:** pemberitahuan aktivitas dan status
    baca.
-   **Bantuan & masukan:** kanal laporan atau masukan pengguna.
-   **UI responsif:** Light/Dark Mode, navigasi mobile, dan maskot
    LINKED.

Fitur yang tampil di antarmuka tetap perlu diverifikasi pada lingkungan
deployment dan database yang digunakan. Jangan menganggap fitur sudah
siap produksi hanya karena komponennya terlihat di UI.

## Teknologi

-   HTML, CSS, dan JavaScript dalam frontend `index.html`.
-   Supabase Auth untuk autentikasi.
-   PostgreSQL dan Row Level Security (RLS) untuk penyimpanan serta
    pembatasan akses data.
-   Netlify untuk hosting frontend jika repository terhubung ke site
    Netlify.
-   Font eksternal dari Fontshare dengan font fallback di browser.

Frontend menggunakan **Supabase publishable key** untuk mengakses
layanan yang memang dirancang untuk klien. Jangan pernah memasukkan
`service_role` key, secret key, password, atau kredensial privat ke
dalam `index.html`, README, atau repository publik.

## Menjalankan secara lokal

1.  Pastikan Python tersedia dan buka terminal di folder yang berisi
    `index.html`.

2.  Jalankan:

    ``` bash
    py -m http.server 5500
    ```

    Jika `py` tidak tersedia, coba `python -m http.server 5500`.

3.  Buka <http://localhost:5500/index.html>.

4.  Untuk menghentikan server, tekan `Ctrl+C` pada terminal.

Tidak diperlukan Node.js hanya untuk menyajikan frontend statis ini.

## Konfigurasi Supabase Auth

Frontend membaca URL proyek dan publishable key dari konfigurasi
JavaScript di `index.html`. Pastikan keduanya menunjuk ke proyek
Supabase yang benar.

Pada konfigurasi URL autentikasi Supabase, tambahkan URL lokal yang
memang digunakan untuk pengembangan, misalnya:

-   `http://localhost:5500/**`
-   `http://127.0.0.1:5500/**`

Pastikan Site URL dan redirect URL produksi juga sesuai dengan domain
yang digunakan. Sesuaikan konfigurasi bila domain atau port berubah.

## Database dan SQL

Database LINKED menggunakan tabel aplikasi seperti:

-   `profiles`
-   `mentor_profiles`
-   `subjects`
-   `mentor_expertise`
-   `learning_requests`
-   `sessions`
-   `courses`
-   `course_modules`
-   `module_progress`
-   `reviews`
-   `opportunities`

Setup fitur lain dapat menambahkan tabel pendukung, misalnya untuk
admin, notifikasi, atau tiket bantuan. Cocokkan daftar ini dengan skema
yang benar-benar diterapkan pada proyek Supabase yang sedang digunakan.

### Penting sebelum menjalankan SQL

-   **Jangan jalankan `linked-consolidated-setup.sql` pada database
    LINKED aktif yang sudah berisi data.** File tersebut adalah setup
    gabungan untuk proyek database baru yang kosong, bukan migration
    pembaruan untuk database aktif.
-   Untuk database aktif, gunakan migration yang memang dibuat untuk
    perubahan tersebut, tinjau isi SQL, dan uji terlebih dahulu pada
    proyek staging atau salinan jika tersedia.
-   GitHub dan Netlify tidak otomatis menjalankan SQL. Commit frontend
    tidak menerapkan perubahan database.
-   Periksa dan sesuaikan placeholder konfigurasi, termasuk akun admin,
    sebelum menyiapkan proyek database baru.
-   Pastikan RLS dan kebijakan akses diuji menggunakan akun learner,
    mentor, dan admin yang berbeda. Jangan memberi hak admin kepada
    pengguna umum.

## Deploy melalui GitHub dan Netlify

Jika Netlify sudah terhubung ke repository GitHub dan branch produksi
(misalnya `main`):

1.  Perbarui `index.html` di root repository dengan versi yang akan
    dirilis.
2.  Commit dan push perubahan ke branch yang digunakan Netlify.
3.  Buka **Deploys** di Netlify dan tunggu status deployment menjadi
    **Published**.
4.  Buka domain produksi dan lakukan hard refresh.
5.  Periksa login, tampilan desktop/mobile, dan alur yang terdampak oleh
    perubahan.

Tidak perlu membuat site Netlify baru jika konfigurasi site yang
sekarang sudah benar. Perubahan SQL/database harus dilakukan secara
terpisah.

## Alur pemeriksaan dasar

1.  Daftar atau masuk sebagai learner.
2.  Cari mentor yang sudah disetujui dan aktif.
3.  Kirim Learning Request dan periksa statusnya.
4.  Masuk menggunakan akun mentor yang dituju untuk meninjau request.
5.  Periksa detail sesi, jadwal, dan catatan yang tersedia.
6.  Selesaikan sesi melalui alur aplikasi, lalu periksa apakah learner
    dapat memberi ulasan sesuai aturan.
7.  Buka My Learning untuk memeriksa course, modul, dan progres.
8.  Periksa Opportunities, notifikasi, dan Bantuan & masukan.
9.  Gunakan akun admin yang memang telah diberi otorisasi untuk
    memeriksa alur administratif.

Jangan menganggap pemeriksaan ini menggantikan pengujian keamanan atau
pengujian seluruh skenario.

## Batasan dan hal yang perlu diverifikasi sebelum pilot

-   **Pembayaran dan service fee:** jangan menganggap pembayaran sudah
    tersedia kecuali integrasi pembayaran dan pencatatan transaksinya
    benar-benar sudah dibuat dan diuji.
-   **Milestone atau reward mentor:** jangan menjanjikan badge,
    milestone, atau reward jika logika dan penyimpanan fiturnya belum
    diterapkan.
-   **Penjadwalan:** validasi aturan bentrok jadwal, perubahan jadwal,
    pembatalan, durasi, dan mode/lokasi sesi pada implementasi yang
    aktif.
-   **Keamanan:** uji RLS, akses lintas akun, hak admin, dan proses
    penghapusan akun/data.
-   **Operasional:** tetapkan SOP untuk pembatalan, no-show, keluhan,
    moderasi ulasan, dan dukungan pengguna.
-   **Kebijakan:** tinjau Kebijakan Privasi dan Ketentuan Penggunaan
    sebelum mengundang pengguna eksternal.
-   **Data demo:** bedakan contoh/demo dari data pengguna sungguhan.
    Jangan menyajikan data contoh sebagai bukti penggunaan aktual.

------------------------------------------------------------------------

**LINKED --- Belajar bareng, tumbuh bareng.**
