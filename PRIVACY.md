# RankScope Privacy & Data Sovereignty Manifesto 🛡️

**Effective Date:** Current Release  
**Target Environment:** Android (Local-Only Application)

RankScope is built upon an unyielding commitment to user privacy, operational transparency, and absolute data sovereignty.

---

## 1. Zero Cloud Architecture (True Offline-First)

Unlike traditional commercial SEO platforms, RankScope operates **without any central server, cloud backend, or remote database**:
- There are **no user accounts, sign-ups, or logins** required to use RankScope.
- All tracked websites, monitored keywords, SERP positions, notes, and historical audit records exist **solely on your physical Android device**.
- If you lose your device without creating an exported backup, your data cannot be retrieved by anyone—including the developers of RankScope.

---

## 2. Zero Telemetry, Zero Analytics, Zero Tracking

- **No Google Analytics / Firebase Analytics**: We do not collect click events, screen views, or session durations.
- **No Crash Reporting Daemons**: No automated error trackers (e.g., Sentry, Crashlytics) transmitting stack traces or device identifiers over the network.
- **No Advertising SDKs**: The application is 100% ad-free and contains no marketing libraries or fingerprinting trackers.
- **No Third-Party Cookies or Web Beacons**: All UI rendering is native Flutter.

---

## 3. Direct-to-Platform Communications

When external integrations are activated:
1. **Google Search Console (GSC)**:
   - RankScope communicates **directly** with official Google endpoints (`https://accounts.google.com` and `https://www.googleapis.com/webmasters/v3/`).
   - Network requests originate directly from your Android device's IP address.
   - Authentication tokens (OAuth access token and refresh token) are held **exclusively** on your local device.
   - RankScope requests the minimum possible read-only scope (`webmasters.readonly`). It can never modify, add, or delete your verified properties or sitemaps.
2. **Bing Webmaster Tools**:
   - RankScope communicates **directly** with Microsoft's official endpoint (`https://ssl.bing.com/webmaster/api.svc/`).
   - Your private API key is sent only to Microsoft over encrypted TLS 1.3 channels.
3. **No Intermediate Proxy**:
   - RankScope does not route your requests through intermediate servers or proxy relays. No third party can inspect your search console data or monitor which domains you track.

---

## 4. Hardware-Backed Credential Security

All sensitive credentials—including:
- Google OAuth refresh and access tokens,
- Bing Webmaster API keys,
- Custom Google Cloud Project Client Secrets (if provided)—

are committed to **encrypted storage** via `flutter_secure_storage`. On Android, this leverages:
- **Android KeyStore Provider**: Cryptographic keys are generated inside the device's hardware-backed Secure Execution Environment (TEE) or StrongBox keymaster.
- **EncryptedSharedPreferences**: Payloads are encrypted using AES-256 GCM before writing to flash storage.

Plaintext credentials are never written to standard SQLite tables, application logs, or non-secure cache files.

---

## 5. Compliance with Search Engine Guidelines (No Scraping)

RankScope strictly honors search engine Terms of Service:
- **No Automated Scraping**: The app never sends simulated browser requests or bot traffic to Google Search, Googlebot, or Bing Search.
- **No IP Masking or Proxy Rotation**: We do not integrate with residential proxy providers.
- **Honest Data Presentation**: Point-in-time SERP rankings are logged strictly through manual human audits. Google Search Console impressions and average positions are labeled as aggregate search console metrics.

---

## 6. User Data Control, Export & Total Deletion

- **Export Anytime**: You can export your full database snapshot or generate standard CSV and PDF reports at any time.
- **Immediate Data Destruction**: Clearing the application data in Android Settings or uninstalling RankScope permanently purges all local SQLite records, secure tokens, and cached reports from your device.
