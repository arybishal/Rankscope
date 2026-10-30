# RankScope v1.0.1 🎯
## Task 001: Data Persistence, Authenticated Encrypted Backups & Log Management

RankScope v1.0.1 delivers critical stability fixes for website persistence, introduces a military-grade authenticated backup and dual-mode restore system, and implements an air-gapped on-device diagnostic logging center with automated credential redaction.

---

## 🌟 Key Highlights in v1.0.1

### 1. Permanent Website Persistence & Lifecycle Management
- **Type Cast Defect Resolved:** Fixed root cause `_TypeError` in `WebsiteModel` and `KeywordModel` data transfer layers.
- **Relational Integrity Preservation:** Swapped destructive `ConflictAlgorithm.replace` for `ConflictAlgorithm.abort` with duplicate detection, preventing unintended cascade deletions of child keywords and ranking records.
- **Instant State Synchronization:** Auto-selects newly created websites upon insertion, instantly updating dashboard KPIs and keyword lists.
- **Full CRUD Support:** Added dedicated inline Edit Website dialog and cascading Delete Website dialog with explicit user confirmation.

### 2. Authenticated Encrypted Backup & Dual-Mode Restore (`.rankscope`)
- **Military-Grade Security:** Encrypts complete application archives using **AES-256-GCM** authenticated encryption.
- **PBKDF2 Key Derivation:** Master key dynamically derived from user password using **HMAC-SHA256 (100,000 iterations)** with unique 16-byte cryptographic salt and 12-byte nonce.
- **Encrypted Credential Ingestion:** Securely includes Google Search Console tokens and Bing API keys without cleartext exposure.
- **Decryption & Preview Inspection:** Validates authentication tag and displays archive preview stats (creation timestamp, number of websites, keywords, ranking records, integrations).
- **Dual Restoration Modes:**
  - **Full Restore:** Atomic replacement with automatic recovery snapshot rollback guard.
  - **Merge Import:** Safe, non-destructive import mapping foreign keys and resolving conflicts without wiping existing data.

### 3. Log Management Center & Developer Dashboard
- **Central Diagnostic Logging (`AppLogger`):** Structured local SQLite persistence across 5 severity levels: `DEBUG`, `INFO`, `WARNING`, `ERROR`, `CRITICAL`.
- **Automated Credential Redaction (`LogSanitizer`):** Automated regex scrubbing masking Bearer tokens, Google OAuth access/refresh tokens, Bing API keys, passwords, and client secrets.
- **Bounded Storage Footprint:** Capped strictly at 2,000 log entries with automatic pruning to prevent unlimited storage expansion.
- **Interactive Dashboard (`LogsView`):** Real-time search, severity and module filters, detailed inspection bottom sheet, clipboard copy, and `.txt` / `.json` export via native share sheet.

---

## 📦 Release Assets & Checksums

| Asset | File Size | SHA-256 Checksum |
|---|---|---|
| `RankScope-v1.0.1.apk` | 53.2 MB | `3146FC774C4FA5E48AC9C19D91B4B5EE59E709A041F60532FFD7D1BF66502692` |

### Installation Instructions
1. Download `RankScope-v1.0.1.apk` onto your Android device (Android 8.0 Oreo / API 26 or higher).
2. Tap the APK file and select **Install** (enable "Install unknown apps" if prompted).
3. If upgrading from v1.0.0, your existing database will automatically migrate to schema version 2 without data loss.
