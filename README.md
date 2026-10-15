# LINKED — Peer Learning Prototype V1

Prototype web interaktif untuk proyek Creativity and Technological Innovation (CTI).

## Cara menjalankan

1. Ekstrak folder `linked-mvp` bila menerima versi ZIP.
2. Buka `index.html` menggunakan browser modern (Chrome, Edge, Firefox, Safari).
3. Tidak perlu instalasi Node.js atau koneksi database untuk mencoba demo.

## Alur demo yang disarankan

1. Di mode Learner, buka **Find a mentor**.
2. Cari mentor atau gunakan filter subject/mode/verifikasi.
3. Buka profil dan pilih **Request sesi**.
4. Isi Learning Request lalu kirim.
5. Gunakan tombol **Switch to Mentor** di kanan atas.
6. Buka **Learning requests**, lalu terima/tolak request; request terkonfirmasi dapat ditandai selesai.
7. Kembali ke mode Learner dan coba memberikan ulasan setelah request selesai.
8. Buka **My learning** untuk menandai modul Full Course selesai dan melihat perubahan progress.

## Batasan penting

- Ini adalah front-end prototype dengan data demonstrasi.
- Perubahan disimpan di `localStorage` browser yang sama. Data tidak dibagikan dengan anggota kelompok/perangkat lain.
- Tidak ada login/autentikasi, database bersama, notifikasi email, pembayaran, atau verifikasi mentor sungguhan.
- Data nama, rating, review, sesi dan jadwal merupakan contoh UI; jangan disajikan sebagai pengguna/aktivitas aktual.
- Tombol role-switch hanya mensimulasikan tampilan learner dan mentor untuk demonstrasi, bukan sistem akses yang aman.
- `supabase_schema.sql` adalah rancangan awal untuk integrasi database. Review dan penyesuaian Row Level Security (RLS) wajib dilakukan sebelum penggunaan nyata.

## Arsitektur yang disarankan untuk versi berikutnya

Web UI → Supabase Auth → PostgreSQL Database → RLS policies.

Implementasikan login, profil berbasis akun, kepemilikan request, relasi course/module/session/review, dan pemeriksaan hak akses terlebih dahulu sebelum mengundang mahasiswa lain.
