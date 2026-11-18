# Logbook Lab IoT — Blockchain Mobile App

Aplikasi mobile berbasis **Flutter** yang terintegrasi dengan **Ethereum Smart Contract (Sepolia Testnet)** untuk pencatatan peminjaman dan pengembalian alat laboratorium IoT secara transparan dan permanen (_immutable_).

---

## Fitur Utama

- **Pencatatan Peminjaman On-Chain:** Menyimpan nama alat, kode/inisial peminjam, alamat wallet, dan waktu pinjam ke smart contract.
- **Pembaruan Status Pengembalian:** Menandai alat yang telah dikembalikan langsung melalui transaksi blockchain.
- **Filter & Statistik Real-Time:** Ringkasan jumlah total log, alat yang sedang dipinjam, dan alat yang sudah dikembalikan beserta filter status.
- **Indikator Status Transaksi:** Menampilkan status pengiriman transaksi beserta _Transaction Hash_ (Tx Hash).

---

## Teknologi yang Digunakan

- **Frontend Mobile:** Flutter (Dart)
- **Integrasi Blockchain:** `web3dart`, `http`, `flutter_dotenv`
- **Smart Contract:** Solidity (`contracts/LogbookLabIoT.sol`)
- **Jaringan Blockchain:** Ethereum Sepolia Testnet (`Chain ID: 11155111`)
- **Tools Pendukung:** Remix IDE, MetaMask, Alchemy/Infura RPC, Sepolia Etherscan

---

## Struktur Proyek

```text
logbook_lab_iot/
├── contracts/
│   └── LogbookLabIoT.sol           # Kode sumber Smart Contract Solidity
├── lib/
│   ├── config/
│   │   └── blockchain_config.dart  # Konfigurasi RPC URL, Chain ID, dan Address
│   └── main.dart                   # Antarmuka aplikasi & integrasi web3dart
├── .env.example                    # Template konfigurasi environment
├── .gitignore                      # Mengabaikan file sensitif (.env)
└── pubspec.yaml                    # Daftar dependensi Flutter
```

---

## Cara Menjalankan Proyek

### 1. Prasyarat

- Flutter SDK terpasang di perangkat.
- Akun RPC Sepolia (Alchemy / Infura) dan wallet MetaMask jaringan Sepolia dengan saldo SepoliaETH (faucet).

### 2. Instalasi Dependensi

```bash
git clone <URL_REPOSITORY_GITHUB>
cd logbook_lab_iot
flutter pub get
```

### 3. Konfigurasi Environment (`.env`)

Buat file baru bernama **`.env`** di folder root proyek (sejajar dengan `pubspec.yaml`), lalu isi sesuai format berikut:

```env
RPC_URL=[https://eth-sepolia.g.alchemy.com/v2/ISI_API_KEY_ANDA](https://eth-sepolia.g.alchemy.com/v2/ISI_API_KEY_ANDA)
PRIVATE_KEY=ISI_PRIVATE_KEY_WALLET_SEPOLIA_ANDA
CONTRACT_ADDRESS=0xISI_ALAMAT_SMART_CONTRACT_SEPOLIA
```

> **Catatan Keamanan:** File `.env` sudah didaftarkan ke dalam `.gitignore` agar _private key_ tidak ikut terunggah ke repositori publik. Gunakan akun MetaMask khusus pengujian (_testnet_) dan gunakan kode/inisial peminjam (bukan nama lengkap/NIM asli) saat mencatat transaksi.

### 4. Jalankan Aplikasi

```bash
flutter run
```

---

## Informasi Smart Contract (Sepolia Testnet)

- **Nama Kontrak:** `LogbookLabIoT`
- **Network:** Sepolia Testnet (`Chain ID: 11155111`)
- **Contract Address:** `0x...` _(Diisi setelah proses deploy selesai)_
- **Link Etherscan:** `https://sepolia.etherscan.io/address/0x...` _(Diisi setelah verifikasi kontrak)_

---

## Tim Pengembang

- **Azalia Natasya** — Perancangan Antarmuka (Flutter UI/UX), Struktur Proyek, & Dokumentasi
- **Opi** — Pengembangan & Deploy Smart Contract (`Solidity`), Integrasi `web3dart`, & Pengujian Transaksi Sepolia
