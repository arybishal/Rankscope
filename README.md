# RankScope 🎯

> **Zero-Cost, Privacy-First SEO Rank & Search Performance Tracker for Android**

[![Release](https://img.shields.io/github/v/release/arybishal/Rankscope?style=flat-square&color=0F172A)](https://github.com/arybishal/Rankscope/releases/tag/v1.0.1)
[![Platform](https://img.shields.io/badge/Platform-Android%208.0%2B-blue?style=flat-square)](https://github.com/arybishal/Rankscope)
[![License](https://img.shields.io/badge/License-MIT-green?style=flat-square)](https://github.com/arybishal/Rankscope)
[![Budget](https://img.shields.io/badge/Budget-%240%20Zero--Cost-brightgreen?style=flat-square)](https://github.com/arybishal/Rankscope)

RankScope is an open-source, offline-first Android application built with Flutter that empowers website owners, digital marketers, and SEO professionals to track search keyword positions, monitor competitor performance, and analyze organic visibility across Google and Bing—with **strictly $0 spend**, **zero backend infrastructure**, and **100% on-device data sovereignty**.

📥 **[Download Latest APK (v1.0.1)](https://github.com/arybishal/Rankscope/releases/download/v1.0.1/RankScope-v1.0.1.apk)** • [GitHub Release Notes](https://github.com/arybishal/Rankscope/releases/tag/v1.0.1)

---

## 🌟 Core Philosophy & Principles

1. **Strictly $0 Budget**: No paid APIs, no recurring subscriptions, no premium SaaS dependencies.
2. **Zero Backend Server**: The application operates directly from the user's Android device. All data is stored locally in an embedded SQLite database.
3. **No Scraping / No ToS Violations**: RankScope never scrapes Google/Bing search results, uses headless proxies, or breaches search engine terms of service.
4. **Honest, Accurate Metrics**: Distinct separation between Google Search Console (GSC) *average position* and verified *manual SERP rank records*. Ranking data is never fabricated or guessed.
5. **Legitimate Location Tracking**: City-level and country-level geo-tracking are strictly supported through verified manual audit entries and location-specific data source dimensions.
6. **Device Sovereignty & Privacy**: OAuth tokens and API keys are stored in encrypted hardware-backed storage (`flutter_secure_storage`). RankScope has zero telemetry, zero analytics, and zero tracking code.

---

## 🚀 Key Features

- **Multi-Property Management**:
  - Track your own websites alongside direct competitor domains.
  - Full CRUD lifecycle: permanent SQLite storage, duplicate domain prevention, inline editing, and cascade deletion with confirmation.
- **Google Search Console Integration (Free)**:
  - Connect verified Google Search Console properties using secure Google OAuth 2.0 PKCE.
  - Pull query-level performance metrics: Clicks, Impressions, CTR, and Average Position across countries and devices.
- **Bing Webmaster Tools Integration (Free)**:
  - Direct integration via official free Bing Webmaster API keys.
  - Ingest query impressions, clicks, and average ranks directly into your local database.
- **Manual Rank Tracking Engine**:
  - Record exact ranking positions, ranking URLs, SERP features (Featured Snippets, Local Pack, People Also Ask, Video Carousel), country codes, and city names.
  - Track ranking deltas (gain/drop) over time against competitor URLs.
- **Authenticated Encrypted Backups (`.rankscope`)**:
  - Full backup encryption utilizing **AES-256-GCM** with **PBKDF2** (HMAC-SHA256, 100,000 iterations) master password derivation.
  - Unique 16-byte cryptographic salt and 12-byte nonce per backup.
  - Secure inclusion of API keys and credentials without cleartext exposure.
  - Dual-mode restoration: **Full Restore** (transactional with automatic recovery snapshot) and **Merge Import** (conflict-free upsert).
- **Log Management Center (`AppLogger`)**:
  - Centralized on-device diagnostic logging (`DEBUG`, `INFO`, `WARNING`, `ERROR`, `CRITICAL`).
  - Automated regex credential scrubbing (`LogSanitizer`) masking Google OAuth tokens, Bing keys, and passwords.
  - Developer dashboard in Settings with severity/module filtering, live search, `.txt`/`.json` export, and clipboard copying.
- **Premium Minimalist Light-Mode UI**:
  - Polished, distraction-free aesthetic crafted exclusively for high legibility in light environments.
  - Monochromatic contrast, subtle neutral dividers, crisp cards, and zero heavy drop-shadows.
- **Local PDF & CSV Reporting**:
  - Generate comprehensive executive reports directly on your phone with zero third-party cloud APIs.
  - Export ranking distributions, top gainers, top losers, and competitor parity matrices.

---

## 🛠️ Technology Stack

| Layer | Technology | Rationale |
|---|---|---|
| **Platform** | Android (API 26+ / Android 8.0 to Android 15) | Broadest mobile OS reach with native file system access |
| **Framework** | Flutter 3.x | Reactive UI, high performance, single codebase |
| **Language** | Dart 3.x | Type safety, pattern matching, async streams |
| **Local Database** | SQLite via `sqflite` | Robust ACID-compliant relational storage, zero latency |
| **State Management** | Riverpod 2.x | Compile-time safety, modular dependency injection, testability |
| **Navigation** | GoRouter | Declarative routing, deep-link ready, shell routes |
| **Secure Storage** | `flutter_secure_storage` | Android KeyStore / EncryptedSharedPreferences |
| **Reporting** | `pdf` & `csv` | Pure Dart document generation running purely on device |

---

## 📋 Repository Structure

```text
D:\Webapp\SEM\
├── ARCHITECTURE.md          # Comprehensive architectural blueprints & specifications
├── DATABASE_SCHEMA.md      # Complete SQLite tables, DDL, and ER relationships
├── TASKS.md                # Task-by-task development breakdown & test criteria
├── CHANGELOG.md            # Version history and evolution
├── PRIVACY.md              # Zero-telemetry, offline privacy manifesto
├── README.md               # Project overview and run guide
└── lib/                    # Planned Flutter Clean Architecture source (upon approval)
```

---

## ⚙️ Environment Setup & Prerequisites

Before building RankScope, ensure the following development environment dependencies are met:

1. **Flutter SDK**: Flutter 3.24.x or higher (Dart 3.5.x or higher).
2. **Git**: Installed and accessible in system path.
3. **Java Development Kit**: Microsoft OpenJDK 17 LTS or 21 LTS (`JAVA_HOME` configured).
4. **Android SDK**: Android SDK 34/35 platform tools, build tools, command-line tools.
5. **Android Device or Emulator**: Physical Android device with USB debugging enabled, or an Android Virtual Device (e.g., `pc_test`).

For full environment audit details, see the Environment Inspection section in [ARCHITECTURE.md](file:///D:/Webapp/SEM/ARCHITECTURE.md).

---

## 🔒 Security & Data Hygiene

RankScope does not embed any private API secrets in the binary:
- **Google OAuth**: RankScope uses the OAuth 2.0 PKCE (Proof Key for Code Exchange) flow designed for public/installed clients. Users supply their GCP Client ID or use standard open credentials.
- **Bing API Key**: Users generate their own free API key from their Bing Webmaster portal and input it in app settings.
- **Local Encryption**: All tokens are securely saved using Android's hardware-backed KeyStore.

---

## 📄 License & Compliance

RankScope is developed under an open, transparent model complying with:
- Google API Services User Data Policy
- Bing Webmaster Tools API Terms of Use
- Zero web scraping policy
