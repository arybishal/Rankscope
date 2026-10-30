# Changelog 📜

All notable changes to the RankScope project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.0.2] - 2026-10-30

### Task: Keyword Intelligence, Ranking Landing URLs & Black Screen Bug Fix
- **Release APK**: [RankScope-v1.0.2.apk](https://github.com/arybishal/Rankscope/releases/download/v1.0.2/RankScope-v1.0.2.apk)
- **SHA-256 Checksum**: `28A18886E865A4FC11F407972CD9BD9AD92D5C5B10372C21202D6D60B4C3FC57`

### Fixed
- **Keyword Creation Black Screen Bug**: Resolved critical navigation bug where saving a keyword dismissed the root router branch rather than the dialog route's context. Isolated dialog contexts to ensure dashboard route remains mounted and newly created keywords render immediately without app restart.
- **Form Layout Flex Overflow**: Fixed 26px horizontal render flex overflow on advanced settings button across narrow Android viewports by applying `Expanded` and flex layout constraints.
- **SQLite Double-Quote Identifiers**: Corrected duplicate keyword queries to avoid SQL identifier misinterpretations for empty strings in SQLite.

### Added
- **Multi-Search Engine Separation**: Independent position tracking, movement deltas, and historical observations for Google and Bing.
- **Strict Rank Display Standard**: Unambiguous separation between exact SERP positions (`#1` to `#100`), confirmed absent (`0`), and unranked/pending (`—`).
- **Detected Ranking Landing URLs**: Automatic extraction and storage of specific ranking URLs with one-tap clipboard copy action.
- **Keyword Cannibalization Detection**: Automatic identification of `multiple_urls` and `url_switching` across observation checks with visual warning banners and affected URL lists.
- **Keyword Lifecycle Transitions**: State tracking for `new` (first-time ranked), `lost` (dropped to position 0), and `recovered` (re-entered top 100) status events.
- **Keyword Details Screen**: Comprehensive view with 7D/30D/90D/All timeframe filtering, search engine comparison breakdown, detected ranking URLs, and full observation history timeline.
- **Dashboard SEO KPIs Grid**: 6 high-level metric cards for Tracked queries, Ranking (1-100), Not Ranking (0), Improved, Declined, and Cannibalization alerts.
- **Database Schema Migration 003**: Added `rank_observations` table with performance indexes on `keyword_id`, `search_engine`, `ranking_url`, and `recorded_at DESC`.
- **Encrypted Backup & CSV Export Expansion**: Enriched `.rankscope` encrypted snapshots and RFC 4180 CSV exports with complete rank observation records and landing URLs.
- **Automated Regression Test Suites**: Added `keyword_black_screen_regression_test.dart` and `keyword_intelligence_test.dart` bringing test suite to 74 passing tests.

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
