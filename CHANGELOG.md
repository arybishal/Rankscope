# Changelog 📜

All notable changes to the RankScope project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.0.1] - 2026-10-30

### Task 001: Data Persistence, Authenticated Encrypted Backups & Log Management Center
- **Release APK**: [RankScope-v1.0.1.apk](https://github.com/arybishal/Rankscope/releases/download/v1.0.1/RankScope-v1.0.1.apk)
- **SHA-256 Checksum**: `3146FC774C4FA5E48AC9C19D91B4B5EE59E709A041F60532FFD7D1BF66502692`

### Fixed
- **Website Persistence Root Cause Resolved**: Fixed `_TypeError` cast exception where `Website.copyWith` downcast to `WebsiteModel` failed in data source layer. Added explicit `copyWith` type overrides in both `WebsiteModel` and `KeywordModel`.
- **SQLite Conflict Strategy Restructured**: Replaced destructive `ConflictAlgorithm.replace` on websites table with pre-check uniqueness validation (`getWebsiteByDomain`) and `ConflictAlgorithm.abort`, preventing unintended cascade deletions of child keywords and historical rank records.
- **State Selection Sync**: Automatically select newly created website in `SelectedWebsiteIdNotifier` upon insertion, immediately updating dashboard context.
- **Website Management UX**: Added dedicated inline Edit Website dialog (with label/notes editing) and Delete Website dialog with explicit cascading confirmation.

### Added
- **Authenticated AES-256-GCM Encrypted Backups (`.rankscope`)**: Complete backup and restore system utilizing PBKDF2 (HMAC-SHA256, 100,000 iterations) with unique 16-byte cryptographic salt and 12-byte nonce per archive.
- **Preview & Dual-Mode Restore**: Decryption verification, preview inspection dialog (websites, keywords, ranking records, integrations count), and user choice between **Full Restore** (transactional with automatic recovery snapshot) and **Merge Import** (conflict-free upsert).
- **Log Management Center (`AppLogger`)**: Centralized local diagnostic logging service with severity levels (`DEBUG`, `INFO`, `WARNING`, `ERROR`, `CRITICAL`), structured metadata, and bounded retention (max 2,000 entries).
- **Automated Credential Redaction (`LogSanitizer`)**: Automated regex scrubbing of Google OAuth tokens, Bing API keys, passwords, client secrets, and authorization headers before disk persistence.
- **Diagnostic Dashboard (`LogsView`)**: Developer-friendly UI in Settings featuring metrics cards, real-time search, severity/module filters, full details bottom sheet, clipboard copy, and `.txt` / `.json` export via native share sheet.
- **Database Schema Migration 002**: Added `app_logs` table with performance indexes on `timestamp DESC`, `level`, and `module`.
- **Comprehensive Automated Tests**: Added test suites for website persistence, PBKDF2 + AES-GCM cryptography, encrypted backup/restore (full + merge), and diagnostic logging with redaction.

---

## [1.0.0] - 2026-10-30

### Initial Production Release
- **Official Release**: [RankScope v1.0.0 on GitHub](https://github.com/arybishal/Rankscope/releases/tag/v1.0.0)
- **APK Download**: [RankScope-v1.0.0.apk](https://github.com/arybishal/Rankscope/releases/download/v1.0.0/RankScope-v1.0.0.apk)

### Added
- **Offline Relational Storage**: Embedded SQLite database (`rankscope.db`) with Write-Ahead Logging (WAL mode), cascade deletes, and versioned migration runner.
- **Premium Light-Mode UI**: Strict Light Theme designed with zero elevation drop shadows, 1dp crisp outlines, and high-contrast typography.
- **5-Tab Navigation**: Persistent bottom navigation using GoRouter (Overview, SERP Audit, Google Search Console, Bing Webmaster, Settings & Privacy).
- **Manual SERP Auditing**: Point-in-time ranking logger (1-100), automated delta calculation ($\Delta = \text{previous} - \text{current}$), verified country & city support, and SERP feature bitmasking (Featured Snippets, Local Pack, PAA, Video Carousels).
- **Google Search Console**: Direct serverless OAuth 2.0 PKCE synchronization for organic search queries, clicks, impressions, CTR, and average position.
- **Bing Webmaster Tools**: Direct free API key integration pulling Bing query statistics into local SQLite.
- **Local Reporting Engine**: On-device vector PDF report generation and RFC 4180 CSV export via Android share sheet.
- **Air-Gapped Backup & Restore**: Full database snapshot export with SHA-256 checksum verification and crash-safe rollback safeguard.
- **Hardware-Backed KeyStore**: All tokens and API keys isolated in Android KeyStore via `flutter_secure_storage`.
- **10 Automated Test Suites**: Comprehensive test coverage across models, bitmasks, formatters, validators, widgets, and app boot sequence.
