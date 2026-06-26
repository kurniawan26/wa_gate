# WaGate

WhatsApp Gateway berbasis Elixir/Phoenix. Mengirim dan menerima pesan WhatsApp melalui [Evolution API](https://github.com/EvolutionAPI/evolution-api), dengan antrian pengiriman (Oban), inbox live-update, dan REST API untuk integrasi sistem eksternal.

## Prasyarat

- **Elixir** >= 1.15
- **PostgreSQL** >= 14
- **Evolution API** — berjalan di Docker (lihat bagian di bawah)
- Node.js tidak diperlukan; aset dikelola oleh `esbuild` dan `tailwind` via Mix

## 1. Jalankan Evolution API

Evolution API adalah backend WhatsApp yang digunakan project ini. Jalankan dengan Docker:

```bash
docker run -d \
  --name evolution-api \
  -p 8080:8080 \
  -e AUTHENTICATION_TYPE=apikey \
  -e AUTHENTICATION_API_KEY=lt67scX4Hbodj0kpaQYW8MPPIEoh94qpcvkU5COaiec= \
  atendai/evolution-api:latest
```

Pastikan `AUTHENTICATION_API_KEY` sama dengan nilai `api_key` di `config/dev.exs`.

## 2. Konfigurasi

Semua konfigurasi development ada di `config/dev.exs`. Nilai default sudah siap pakai untuk development lokal:

| Config | Default | Keterangan |
|---|---|---|
| Database host | `localhost` | PostgreSQL |
| Database name | `wa_gate_dev` | Dibuat otomatis oleh `mix setup` |
| Evolution API URL | `http://localhost:8080` | Port Docker di atas |
| Evolution API key | `lt67scX4Hbodj0kpaQYW8MPPIEoh94qpcvkU5COaiec=` | Harus sama dengan Docker |
| API key aplikasi | `dev-secret-key` | Untuk endpoint `POST /api/messages` |

## 3. Setup Project

```bash
# Install dependensi, buat database, jalankan migrasi
mix setup
```

## 4. Jalankan Server

```bash
mix phx.server
```

Buka [http://localhost:4000](http://localhost:4000) di browser.

Atau jalankan di dalam IEx untuk bisa berinteraksi langsung:

```bash
iex -S mix phx.server
```

---

## Halaman Web

| URL | Keterangan |
|---|---|
| `/sessions` | Daftar sesi WhatsApp, tambah sesi baru |
| `/sessions/:id` | Detail sesi, scan QR code untuk connect |
| `/messages` | Inbox — daftar kontak & percakapan |
| `/messages/:number` | Thread percakapan dengan satu nomor |
| `/dev/dashboard` | Phoenix LiveDashboard (dev only) |

## REST API

### Kirim Pesan

```
POST /api/messages
Authorization: Bearer dev-secret-key
Content-Type: application/json
```

```json
{
  "to": "6281234567890",
  "text": "Halo dari sistem!"
}
```

Response:
```json
{
  "status": "queued",
  "message_id": 42,
  "info": "Pesan telah masuk antrean pengiriman"
}
```

### Webhook Inbound (dari Evolution API)

```
POST /api/webhooks/whatsapp
```

Daftarkan URL ini di Evolution API sebagai webhook untuk event `messages.upsert` dan `connection.update`.

---

## Alur Kerja

```
Sistem eksternal
      │
      ▼
POST /api/messages  ──►  Oban queue  ──►  MessageWorker
                                               │
                                               ├─ update_presence (typing...)
                                               └─ Evolution API → kirim pesan

Evolution API  ──►  POST /api/webhooks/whatsapp  ──►  simpan ke DB  ──►  PubSub live update
```

---

## Perintah Berguna

```bash
# Reset database (drop + recreate + migrate)
mix ecto.reset

# Jalankan migrasi
mix ecto.migrate

# Build aset untuk production
mix assets.deploy

# Jalankan test
mix test

# Pre-commit check (compile + format + test)
mix precommit
```
