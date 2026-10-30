# RankScope v1.0.0 🎯

> **Zero-Cost, Privacy-First SEO Rank & Search Performance Tracker for Android**

RankScope is an open-source, offline-first Android application designed for webmasters, digital marketers, and SEO professionals to track search keyword positions, monitor competitor performance, and analyze organic visibility across Google and Bing—with **strictly $0 spend**, **zero backend infrastructure**, and **100% on-device data sovereignty**.

---

## 🌟 Key Highlights in This Release

### 1. Multi-Property & Competitor Tracking
- Track multiple domains simultaneously with dedicated badges distinguishing **Own Websites** vs **Competitors**.
- Group, organize, and categorize target search terms with flexible keyword tags.

### 2. Manual SERP Rank Auditing & Delta Engine
- Log verified search positions (ranks 1 to 100) with discrete point-in-time observations.
- Automatic delta engine computes instant gains or drops ($\Delta = \text{previous} - \text{current}$) with visual color indicators (`▲2`, `▼4`).
- Encode and track detected SERP features: *Featured Snippets, Local 3-Pack, People Also Ask, Video Carousels, Sitelinks, and Knowledge Panels*.
- Verified Country and City-level geographic tags.

### 3. Google Search Console Integration (Zero Server / Free API)
- Connect verified GSC properties via secure **OAuth 2.0 PKCE** directly from your phone to Google.
- Ingest search queries, impressions, clicks, CTR, and average positions without any middleman or proxy server.
- Built-in disambiguation educating users on the mathematical difference between GSC aggregate *average position* and discrete point-in-time SERP rankings.

### 4. Bing Webmaster Tools Integration (Free API)
- Direct integration using personal free API keys generated from the official Microsoft Bing Webmaster portal.
- Stored securely inside the Android KeyStore (`flutter_secure_storage`).

### 5. Local Vector PDF & CSV Reporting
- Generate comprehensive, print-ready executive SEO reports (**PDF**) entirely within device memory without calling external servers.
- Export raw tabular data (**RFC 4180 CSV**) for Excel, Google Sheets, or LibreOffice.
- Share directly using the native Android system share sheet.

### 6. Air-Gapped Database Backup & Restore
- Full SQLite snapshot export to user-selected device storage with **SHA-256 integrity verification**.
- Crash-safe restore with automatic rollback guards to prevent corruption.

### 7. Premium Minimalist Light-Mode UI
- Built exclusively in clean, high-contrast Light Theme for long analytical sessions.
- 0dp elevation shadows, crisp 1dp outlines, and responsive 8dp layout grid.

---

## 🔒 Security & Data Hygiene
- **Zero Cloud Servers**: All database rows exist solely on your device in embedded SQLite.
- **Zero Telemetry**: No Google Analytics, Firebase, Sentry, or ad tracking SDKs.
- **Hardware-Backed Tokens**: All API keys and OAuth tokens reside in the Android KeyStore.

---

## 📦 Release Assets & Checksums

| Asset | File Size | SHA-256 Checksum |
|---|---|---|
| `RankScope-v1.0.0.apk` | 52.4 MB | `D5BA708FE313E9241F4266BDF18FEBFCA3726D4C8DC0B8E8519E957D77EF08FC` |

### Installation Instructions
1. Download `RankScope-v1.0.0.apk` onto your Android device (Android 8.0 Oreo / API 26 or higher).
2. Tap the APK file and select **Install** (enable "Install unknown apps" if prompted).
3. Open **RankScope** and begin tracking!
