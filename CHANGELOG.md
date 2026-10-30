# Changelog 📜

All notable changes to the RankScope project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
