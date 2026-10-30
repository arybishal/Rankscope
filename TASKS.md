# RankScope Development Roadmap & Implementation Tasks 📋

This document outlines the engineering breakdown for building **RankScope** from initial scaffolding to final Android release. Each task is defined with an explicit objective, file targets, dependencies, test requirements, and acceptance criteria.

---

## 🚀 Task 001: Data Persistence, Authenticated Encrypted Backups & Log Management (COMPLETED)

- **Status**: ✅ COMPLETED (Release v1.0.1)
- **Primary Objectives**:
  1. Fix website persistence and cascade deletion bugs.
  2. Implement complete AES-256-GCM encrypted backup & dual-mode restore system.
  3. Implement centralized diagnostic logging service with automated credential sanitization and developer dashboard.
- **Key Deliverables**:
  - `lib/features/websites/data/models/website_model.dart`: Overrode `copyWith` returning concrete `WebsiteModel`.
  - `lib/features/keywords/data/models/keyword_model.dart`: Overrode `copyWith` returning concrete `KeywordModel`.
  - `lib/features/websites/data/datasources/local_websites_datasource.dart`: Added `getWebsiteByDomain`, swapped `ConflictAlgorithm.replace` for `ConflictAlgorithm.abort`.
  - `lib/features/websites/data/repositories/websites_repository_impl.dart`: Added domain uniqueness validation preventing accidental cascade deletions.
  - `lib/features/websites/presentation/controllers/websites_controller.dart`: Auto-selection of newly created websites in `selectedWebsiteIdProvider`.
  - `lib/features/dashboard/presentation/views/dashboard_view.dart`: Added Edit Website dialog and cascading Delete Website dialog with confirmation.
  - `lib/shared/widgets/dialogs/add_website_dialog.dart`: Support for both create and edit modes with form validation.
  - `lib/features/backup_restore/data/services/backup_restore_service.dart`: AES-256-GCM + PBKDF2 authenticated backup export/import (`.rankscope`), full restore with automatic recovery snapshot rollback, and non-destructive merge import.
  - `lib/core/logging/log_level.dart`, `log_entry.dart`, `log_sanitizer.dart`, `app_logger.dart`: Structured logging with 2,000-entry retention cap and regex credential scrubbing.
  - `lib/features/settings/presentation/views/logs_view.dart`: Complete diagnostics dashboard with search, level/module filtering, export to `.txt`/`.json`, and clipboard copying.
  - `lib/core/database/migrations/m002_add_logs_table.dart`: Database schema migration v2 adding `app_logs` table with performance indexes.
  - `test/features/websites/website_persistence_test.dart`: 5 persistence integration tests.
  - `test/features/backup_restore/backup_restore_test.dart`: Comprehensive encryption, preview, full restore, and merge import tests.
  - `test/core/logging/app_logger_test.dart`: Diagnostic logging, filtering, stats, and credential sanitization tests.

---

## Phase 0: Environment & Tooling Setup

### TASK-001: Flutter SDK Installation & Environment Validation
- **Objective**: Establish a fully operational Flutter development environment on the Windows host and verify Android toolchain interoperability.
- **Files to Create / Modify**:
  - `tools/setup_environment.ps1` (Optional helper script for environment checks)
- **Implementation Details**:
  - Install Flutter SDK (3.24.x+ stable) into `C:\flutter` (matching existing system `PATH` configuration).
  - Verify Dart SDK (3.5.x+) bundled inside Flutter.
  - Configure `flutter config --android-sdk "C:\Android\Sdk"`.
  - Accept all Android SDK licenses: `flutter doctor --android-licenses`.
  - Verify Android Virtual Device (`pc_test`) startup via `flutter emulators --launch pc_test` or connect a physical debugging device.
  - Run `flutter doctor -v` and ensure zero blocking errors.
- **Dependencies**: Windows PowerShell, Git 2.55+, OpenJDK 21/17 LTS, Android SDK 34/35.
- **Tests**: Run `flutter doctor -v` and inspect terminal exit code 0.
- **Acceptance Criteria**:
  - `flutter doctor -v` reports clean status for Flutter, Android Toolchain, and Connected Devices.

---

## Phase 1: Project Initialization & Core Architecture Scaffolding

### TASK-101: Flutter Project Scaffolding with Clean Architecture
- **Objective**: Initialize the clean Flutter project structure with Android package identity `com.rankscope.app`.
- **Files to Create / Modify**:
  - `pubspec.yaml`
  - `analysis_options.yaml`
  - `lib/main.dart`
  - `lib/app.dart`
  - `lib/core/` (constants, errors, theme, utils)
- **Implementation Details**:
  - Initialize Flutter project: `flutter create --org com.rankscope --project-name rankscope .`
  - Configure `analysis_options.yaml` with strict linting rules (`flutter_lints`, `pedantic`, strict-casts, strict-inference).
  - Add core production dependencies:
    - `flutter_riverpod`, `riverpod_annotation`
    - `go_router`
    - `sqflite`, `path`
    - `flutter_secure_storage`
    - `intl`, `uuid`, `crypto`
  - Add development dependencies:
    - `build_runner`, `riverpod_generator`, `flutter_test`, `mocktail`
- **Dependencies**: TASK-001.
- **Tests**:
  - `flutter test` executes default smoke test.
  - `flutter analyze` passes with 0 warnings/errors.
- **Acceptance Criteria**:
  - Repository compiles and runs default application frame on Android emulator or physical device.

---

## Phase 2: Database Layer & Data Access Foundation

### TASK-201: SQLite Database Engine & Migration Manager
- **Objective**: Implement the local SQLite database client with WAL mode, foreign key enforcement, and versioned migration support.
- **Files to Create / Modify**:
  - `lib/core/database/app_database.dart`
  - `lib/core/database/database_migrations.dart`
  - `lib/core/database/migrations/m001_initial_schema.dart`
  - `test/core/database/app_database_test.dart`
- **Implementation Details**:
  - Initialize SQLite database `rankscope.db` using `sqflite`.
  - Execute PRAGMAs: `PRAGMA foreign_keys = ON; PRAGMA journal_mode = WAL;`.
  - Build migration runner executing DDL scripts within atomic transactions.
  - Create table `schema_migrations` to record migration history.
- **Dependencies**: TASK-101, `sqflite`, `path`.
- **Tests**:
  - Unit test verifying database creation, table creation, and PRAGMA settings.
  - Migration rollback simulation test.
- **Acceptance Criteria**:
  - All 8 tables from `DATABASE_SCHEMA.md` are initialized successfully without syntax errors.

### TASK-202: Secure Storage Wrapper
- **Objective**: Implement a hardware-backed secure storage service for API keys and OAuth tokens.
- **Files to Create / Modify**:
  - `lib/core/security/secure_storage_service.dart`
  - `test/core/security/secure_storage_service_test.dart`
- **Implementation Details**:
  - Wrap `FlutterSecureStorage` configuring Android options (`encryptedSharedPreferences: true`).
  - Provide typed accessors: `saveGscRefreshToken()`, `getGscRefreshToken()`, `saveBingApiKey()`, `clearAllCredentials()`.
- **Dependencies**: TASK-101, `flutter_secure_storage`.
- **Tests**:
  - Unit tests with mock storage testing CRUD operations and null handling.
- **Acceptance Criteria**:
  - Sensitive strings are stored and retrieved securely; clear operations leave no orphaned data.

---

## Phase 3: Design System & Minimalist Light UI Shell

### TASK-301: Light-Mode Design System & Tokens
- **Objective**: Construct the comprehensive minimalist light-mode theme, color tokens, and typography scales.
- **Files to Create / Modify**:
  - `lib/core/theme/app_colors.dart`
  - `lib/core/theme/app_text_styles.dart`
  - `lib/core/theme/spacing.dart`
  - `lib/core/theme/app_theme.dart`
- **Implementation Details**:
  - Implement color constants: `#FFFFFF` (surface), `#F8F9FA` (secondary), `#1A1D20` (textPrimary), `#2B8A3E` (gain), `#C92A2A` (drop).
  - Configure `ThemeData.light()` with zero elevation on app bars, cards, and buttons.
  - Disable dark mode fallbacks (`themeMode: ThemeMode.light`).
- **Dependencies**: TASK-101.
- **Tests**:
  - Widget test verifying contrast ratios across text styles and surface backgrounds.
- **Acceptance Criteria**:
  - Visual theme matches the specification in `ARCHITECTURE.md` Section 5.

### TASK-302: Reusable Component Library
- **Objective**: Create reusable widgets following the design tokens.
- **Files to Create / Modify**:
  - `lib/shared/widgets/cards/rank_metric_card.dart`
  - `lib/shared/widgets/cards/ranking_badge.dart`
  - `lib/shared/widgets/buttons/app_primary_button.dart`
  - `lib/shared/widgets/inputs/app_text_field.dart`
  - `lib/shared/widgets/feedback/empty_state_view.dart`
- **Implementation Details**:
  - Build `RankingBadge` widget showing position with gain/drop delta indicator (e.g., `#3 ▲2`).
  - Build `RankMetricCard` displaying headline numbers, percentage shifts, and crisp border outlines.
  - Build `AppTextField` with clean 1dp border and focus states.
- **Dependencies**: TASK-301.
- **Tests**:
  - Widget tests for each component checking render states, overflow avoidance, and callback actions.
- **Acceptance Criteria**:
  - All shared widgets render without pixel overflow or visual defects on multiple screen densities.

### TASK-303: Navigation Shell & GoRouter Setup
- **Objective**: Wire up GoRouter with bottom navigation bar shell routing.
- **Files to Create / Modify**:
  - `lib/routing/app_router.dart`
  - `lib/routing/route_names.dart`
  - `lib/shared/widgets/navigation/app_bottom_nav_bar.dart`
- **Implementation Details**:
  - Setup `StatefulShellRoute.indexedStack` with 5 navigation branches:
    1. Dashboard (`/dashboard`)
    2. Rank Tracker (`/rank-tracker`)
    3. Search Console (`/search-console`)
    4. Bing Webmaster (`/bing-webmaster`)
    5. Settings (`/settings`)
  - Implement bottom bar using minimalist iconography and active indicators.
- **Dependencies**: TASK-101, TASK-301, `go_router`.
- **Tests**:
  - Widget test verifying tab switching preserves route state in indexed stack.
- **Acceptance Criteria**:
  - User can fluidly switch between tabs with zero state loss.

---

## Phase 4: Website Management Module (Own & Competitor Properties)

### TASK-401: Website Data Layer & SQLite Repository
- **Objective**: Implement local database queries and repository for website CRUD operations.
- **Files to Create / Modify**:
  - `lib/features/websites/data/models/website_model.dart`
  - `lib/features/websites/data/datasources/local_websites_datasource.dart`
  - `lib/features/websites/domain/entities/website.dart`
  - `lib/features/websites/domain/repositories/websites_repository.dart`
  - `lib/features/websites/data/repositories/websites_repository_impl.dart`
- **Implementation Details**:
  - Write SQL queries for inserting, querying, updating, and deleting websites.
  - Support `is_competitor` flag (0 for own site, 1 for competitor).
  - Enforce domain validation and URL normalization (stripping `https://`, trailing slashes).
- **Dependencies**: TASK-201.
- **Tests**:
  - Unit tests for `LocalWebsitesDatasource` covering insert, list, update, and cascade delete.
- **Acceptance Criteria**:
  - Successfully manages website records with domain uniqueness constraints.

### TASK-402: Website Domain Presentation & Riverpod Controllers
- **Objective**: Build the UI for viewing, adding, editing, and filtering own websites vs competitors.
- **Files to Create / Modify**:
  - `lib/features/websites/presentation/controllers/websites_controller.dart`
  - `lib/features/websites/presentation/states/websites_state.dart`
  - `lib/features/websites/presentation/views/websites_overview_view.dart`
  - `lib/features/websites/presentation/views/add_website_dialog.dart`
- **Implementation Details**:
  - Implement `AsyncNotifier` controller for websites state.
  - Build UI with segmented control: "My Websites" vs "Competitor Websites".
  - Add dialog with domain validation and label assignment.
- **Dependencies**: TASK-401, TASK-302.
- **Tests**:
  - Widget tests for `WebsitesOverviewView` testing empty state, list rendering, and adding a domain.
- **Acceptance Criteria**:
  - User can register an own website or a competitor domain and see it instantly reflected in the UI.

---

## Phase 5: Keyword Catalog & Categorization Module

### TASK-501: Keyword Data Layer & Repository
- **Objective**: Implement keyword storage, tagging, country/city attributes, and delta tracking.
- **Files to Create / Modify**:
  - `lib/features/keywords/data/models/keyword_model.dart`
  - `lib/features/keywords/data/datasources/local_keywords_datasource.dart`
  - `lib/features/keywords/domain/entities/keyword.dart`
  - `lib/features/keywords/domain/repositories/keywords_repository.dart`
  - `lib/features/keywords/data/repositories/keywords_repository_impl.dart`
- **Implementation Details**:
  - Store keywords scoped by `website_id`.
  - Support tags as comma-separated values or JSON array.
  - Target country (ISO code) and target city support.
  - Cascade deletion when parent website is removed.
- **Dependencies**: TASK-401.
- **Tests**:
  - Unit tests for keyword repository checking duplicate prevention for same website/location.
- **Acceptance Criteria**:
  - Keywords are isolated per website with proper location scoping.

### TASK-502: Keyword Management UI & Filtering
- **Objective**: Build keyword list screen with search, tag filters, and sorting.
- **Files to Create / Modify**:
  - `lib/features/keywords/presentation/controllers/keywords_controller.dart`
  - `lib/features/keywords/presentation/views/keywords_list_view.dart`
  - `lib/features/keywords/presentation/views/add_keyword_dialog.dart`
- **Implementation Details**:
  - Build searchable, tag-filterable keyword table.
  - Color-coded ranking badges showing `latest_position` and `position_delta`.
  - Batch keyword addition dialog (one per line).
- **Dependencies**: TASK-501, TASK-302.
- **Tests**:
  - Widget test for keyword addition and tag filtering.
- **Acceptance Criteria**:
  - Fast rendering and smooth scrolling of 100+ keywords with real-time text search.

---

## Phase 6: Manual Rank Tracking Engine

### TASK-601: Manual Rank Audit Core Engine & Delta Calculations
- **Objective**: Implement the point-in-time SERP audit logger, delta engine, and SERP features bitmask encoder.
- **Files to Create / Modify**:
  - `lib/features/manual_tracking/data/models/rank_record_model.dart`
  - `lib/features/manual_tracking/data/datasources/manual_rank_datasource.dart`
  - `lib/features/manual_tracking/domain/usecases/record_manual_rank.dart`
  - `lib/features/manual_tracking/domain/repositories/manual_rank_repository.dart`
- **Implementation Details**:
  - When user logs a rank:
    1. Fetch previous `latest_position` from `keywords` table.
    2. Calculate `position_delta = previous_position - new_position` (positive means improved rank).
    3. Update `keywords` table: `previous_position = latest_position`, `latest_position = new_position`, `last_checked_at = now`.
    4. Insert record into `manual_rank_records`.
  - SERP feature toggles encoded into integer bitmask.
  - City and country fields strictly recorded as human-verified observations.
- **Dependencies**: TASK-501.
- **Tests**:
  - Unit test verifying delta calculation (e.g. moving from #10 to #4 yields +6 delta).
  - Unit test verifying bitmask encoding and decoding of SERP features.
- **Acceptance Criteria**:
  - Atomic database write guarantees consistency between keyword status and audit history.

### TASK-602: Manual Rank Entry UI & Competitor Parity Logger
- **Objective**: Build intuitive rank logging screens, rapid audit workflows, and side-by-side competitor rank entry.
- **Files to Create / Modify**:
  - `lib/features/manual_tracking/presentation/controllers/rank_logger_controller.dart`
  - `lib/features/manual_tracking/presentation/views/log_rank_dialog.dart`
  - `lib/features/manual_tracking/presentation/views/bulk_audit_view.dart`
  - `lib/features/manual_tracking/presentation/views/keyword_history_view.dart`
- **Implementation Details**:
  - Single keyword audit modal with numeric keypad entry (1-100), landing page URL picker, and SERP feature chips.
  - "Bulk Audit" screen allowing sequential rapid logging through a list of keywords.
  - Interactive historical chart showing position progression over time (with inverted Y-axis where #1 is at the top).
- **Dependencies**: TASK-601, TASK-302.
- **Tests**:
  - Widget test for rank logging modal validation (rejecting position > 100 or < 1).
- **Acceptance Criteria**:
  - User can log a SERP position in fewer than 3 taps.

---

## Phase 7: Google Search Console Integration (Zero-Cost Free API)

### TASK-701: Google OAuth 2.0 PKCE Client
- **Objective**: Implement serverless Google OAuth 2.0 PKCE flow on Android with minimal read-only scope.
- **Files to Create / Modify**:
  - `lib/features/search_console/data/datasources/gsc_auth_datasource.dart`
  - `lib/features/search_console/domain/usecases/authenticate_gsc.dart`
  - `android/app/src/main/AndroidManifest.xml` (Deep link intent filter)
- **Implementation Details**:
  - Generate cryptographically secure `code_verifier` and SHA-256 `code_challenge`.
  - Launch Chrome Custom Tab / default browser to `https://accounts.google.com/o/oauth2/v2/auth`.
  - Handle redirect callback via custom scheme (e.g., `com.rankscope.app:/oauth2callback`).
  - Exchange authorization code for access and refresh tokens.
  - Persist tokens via `SecureStorageService`.
  - Allow users to supply their own GCP OAuth Client ID or use standard client configuration.
- **Dependencies**: TASK-202, `crypto`, `flutter_secure_storage`.
- **Tests**:
  - Unit test for PKCE code verifier and challenge computation.
  - Unit test for token refresh lifecycle handling.
- **Acceptance Criteria**:
  - Seamless authentication flow returning verified access tokens without any backend proxy.

### TASK-702: GSC Search Analytics Sync & Local Storage
- **Objective**: Ingest site listings and query performance data via the Google Search Console REST API.
- **Files to Create / Modify**:
  - `lib/features/search_console/data/datasources/gsc_remote_datasource.dart`
  - `lib/features/search_console/data/datasources/gsc_local_datasource.dart`
  - `lib/features/search_console/domain/usecases/sync_gsc_data.dart`
- **Implementation Details**:
  - Fetch verified sites: `GET https://www.googleapis.com/webmasters/v3/sites`.
  - Execute batch query: `POST https://www.googleapis.com/webmasters/v3/sites/{siteUrl}/searchAnalytics/query`.
  - Query parameters: Dimensions `[date, query, page, country, device]`, start date, end date, row limit 5,000.
  - Handle rate limits (HTTP 429) and network failures with exponential backoff.
  - Upsert rows into `gsc_search_analytics` within an SQLite batch transaction.
- **Dependencies**: TASK-701, TASK-201.
- **Tests**:
  - Unit tests with mock HTTP responses testing JSON deserialization and batch database insertion.
- **Acceptance Criteria**:
  - Accurately pulls and caches queries, impressions, clicks, CTR, and average positions locally.

### TASK-703: GSC Performance Hub UI
- **Objective**: Build the Google Search Console analytics dashboard.
- **Files to Create / Modify**:
  - `lib/features/search_console/presentation/controllers/gsc_analytics_controller.dart`
  - `lib/features/search_console/presentation/views/gsc_performance_view.dart`
  - `lib/features/search_console/presentation/widgets/gsc_metric_tile.dart`
- **Implementation Details**:
  - High-level KPI cards: Total Clicks, Total Impressions, Average CTR, Average Position.
  - Clearly display explanatory banner: *"Note: Average position is an aggregate calculated across all search impressions, distinct from point-in-time SERP rankings."*
  - Top Queries table with sorting by Clicks, Impressions, or Position.
  - Date range selector (Last 7 Days, Last 28 Days, Last 3 Months).
- **Dependencies**: TASK-702, TASK-302.
- **Tests**:
  - Widget test checking metric calculation from mocked SQLite rows.
- **Acceptance Criteria**:
  - Instant loading from local SQLite with responsive sorting and date filtering.

---

## Phase 8: Bing Webmaster Tools Integration

### TASK-801: Bing Webmaster API Client & Sync
- **Objective**: Ingest organic search metrics from Bing Webmaster Tools using user-provided free API keys.
- **Files to Create / Modify**:
  - `lib/features/bing_webmaster/data/datasources/bing_remote_datasource.dart`
  - `lib/features/bing_webmaster/data/datasources/bing_local_datasource.dart`
  - `lib/features/bing_webmaster/domain/usecases/sync_bing_metrics.dart`
- **Implementation Details**:
  - Verify API key via `GET https://ssl.bing.com/webmaster/api.svc/json/GetUserSites?apikey={Key}`.
  - Query metrics via `GET https://ssl.bing.com/webmaster/api.svc/json/GetQueryStats?siteUrl={site}&apikey={Key}`.
  - Store results in `bing_search_analytics`.
- **Dependencies**: TASK-201, TASK-202.
- **Tests**:
  - Unit tests testing Bing JSON response parser and database insertion.
- **Acceptance Criteria**:
  - Securely reads Bing query metrics and stores them locally without intermediate servers.

### TASK-802: Bing Webmaster Hub UI
- **Objective**: Build the Bing performance dashboard and API key configuration screen.
- **Files to Create / Modify**:
  - `lib/features/bing_webmaster/presentation/views/bing_analytics_view.dart`
  - `lib/features/bing_webmaster/presentation/views/bing_settings_view.dart`
- **Implementation Details**:
  - API key entry field with link to Bing Webmaster portal instructions.
  - Query stats table displaying Clicks, Impressions, and Ranks.
- **Dependencies**: TASK-801, TASK-302.
- **Tests**:
  - Widget test validating API key input and status display.
- **Acceptance Criteria**:
  - Displays Bing search data side-by-side with GSC data or in dedicated tab.

---

## Phase 9: Unified Analytics & Competitor Parity

### TASK-901: Competitor Parity Matrix & Delta Analytics
- **Objective**: Implement side-by-side ranking analysis comparing own domain vs competitor domains.
- **Files to Create / Modify**:
  - `lib/features/analytics/domain/usecases/get_competitor_comparison.dart`
  - `lib/features/analytics/presentation/views/competitor_parity_view.dart`
  - `lib/shared/widgets/tables/rank_comparison_table.dart`
- **Implementation Details**:
  - SQL query joining primary keywords and linked competitor keywords on identical dates.
  - Compute ranking gap: `Gap = Competitor Rank - Own Rank` (positive means own site is ahead).
  - Visual indicator showing who ranks higher for each target phrase.
- **Dependencies**: TASK-601, TASK-401.
- **Tests**:
  - Unit test verifying parity gap calculation across multiple competitors.
- **Acceptance Criteria**:
  - Clearly renders competitor comparison table with winning/losing highlight badges.

---

## Phase 10: Local Document Report Generator (PDF & CSV)

### TASK-1001: Local CSV Report Generator
- **Objective**: Build pure Dart RFC 4180 compliant CSV export engine for keyword rankings and historical audits.
- **Files to Create / Modify**:
  - `lib/features/reporting/data/generators/csv_report_generator.dart`
  - `test/features/reporting/csv_report_generator_test.dart`
- **Implementation Details**:
  - Extract keyword records, current positions, deltas, GSC impressions, and competitor ranks.
  - Generate formatted CSV bytes.
  - Save file to app documents directory and register record in `reports_history`.
- **Dependencies**: TASK-201, `csv`, `path_provider`.
- **Tests**:
  - Unit test verifying CSV header compliance and data cell escaping.
- **Acceptance Criteria**:
  - Generated CSV can be opened directly in Microsoft Excel, Google Sheets, or LibreOffice without formatting corruption.

### TASK-1002: Local PDF Report Generator
- **Objective**: Build vector-quality executive PDF report builder running completely on device.
- **Files to Create / Modify**:
  - `lib/features/reporting/data/generators/pdf_report_generator.dart`
  - `lib/features/reporting/presentation/views/report_builder_view.dart`
- **Implementation Details**:
  - Design multi-page vector layout using `pdf` package:
    - Cover Header: Website domain, audit date, generated timestamp.
    - KPI Grid: Total tracked keywords, Top 3 count, Top 10 count, average position.
    - Ranking Movement: Biggest gainers and biggest losers.
    - Keyword Audit Table: Full list with target URL, country/city, and current rank.
  - Trigger Android system share sheet (`share_plus`) to share, email, or save the PDF.
- **Dependencies**: TASK-201, `pdf`, `printing`, `share_plus`.
- **Tests**:
  - Integration test asserting non-empty PDF byte stream generation and valid PDF header (`%PDF-1.`).
- **Acceptance Criteria**:
  - Generates crisp, print-ready, branded PDF reports on device within 2 seconds.

---

## Phase 11: Local Backup & Restore Engine

### TASK-1101: Database Snapshot Export & Integrity Verifier
- **Objective**: Implement air-gapped database backup creation with SHA-256 integrity checksums.
- **Files to Create / Modify**:
  - `lib/features/backup_restore/data/services/backup_service.dart`
  - `test/features/backup_restore/backup_service_test.dart`
- **Implementation Details**:
  - Force SQLite WAL checkpoint (`PRAGMA wal_checkpoint(FULL)`).
  - Package `.db` file into a compressed `.rankscope` bundle with a metadata header JSON (schema version, export date, record counts).
  - Compute SHA-256 digest of the database payload.
  - Save to user-selected destination via Android Storage Access Framework.
- **Dependencies**: TASK-201, `crypto`, `archive`.
- **Tests**:
  - Unit test creating a backup bundle and validating header checksum against payload.
- **Acceptance Criteria**:
  - Clean, uncorrupted backup generated without requiring any network connectivity.

### TASK-1102: Atomic Restore Engine with Rollback Guard
- **Objective**: Implement safe database restoration with pre-validation and automatic rollback on failure.
- **Files to Create / Modify**:
  - `lib/features/backup_restore/data/services/restore_service.dart`
  - `lib/features/backup_restore/presentation/views/backup_restore_view.dart`
- **Implementation Details**:
  - Validate incoming bundle: Checksum matches; schema version $\le$ current app version.
  - Create temporary rollback backup of current live database.
  - Close active SQLite connection pool.
  - Replace database file.
  - Run `PRAGMA integrity_check`.
  - If check fails: Restore rollback backup and throw descriptive error.
  - If check succeeds: Apply any pending migrations and restart Riverpod state container.
- **Dependencies**: TASK-1101, TASK-201.
- **Tests**:
  - Test restoring valid backup.
  - Test restoring corrupted file and verifying automatic rollback preserves original data.
- **Acceptance Criteria**:
  - 100% crash-safe restore with zero risk of database corruption or unrecoverable state.

---

## Phase 12: Quality Assurance & Release Preparation

### TASK-1201: Automated Testing Suite & CI Configuration
- **Objective**: Establish comprehensive automated test coverage across domain, data, and UI layers.
- **Files to Create / Modify**:
  - `test/` (All unit and widget test files)
  - `.github/workflows/verify.yml` (Local / CI validation pipeline)
- **Implementation Details**:
  - Ensure $\ge 85\%$ test coverage on domain use cases and database repositories.
  - Validate `flutter analyze` passes with zero issues.
- **Dependencies**: All preceding tasks.
- **Tests**:
  - `flutter test --coverage`
- **Acceptance Criteria**:
  - All test suites pass cleanly.

### TASK-1202: Android Release Configuration & Proguard Rules
- **Objective**: Configure release build parameters, Proguard keep rules, and APK generation.
- **Files to Create / Modify**:
  - `android/app/build.gradle`
  - `android/app/proguard-rules.pro`
- **Implementation Details**:
  - Configure Android SDK `minSdkVersion 26`, `targetSdkVersion 35`.
  - Configure Proguard rules for `sqflite` and `flutter_secure_storage`.
  - Ensure zero sensitive keys or debug URLs are compiled into release APK.
- **Dependencies**: All preceding tasks.
- **Tests**:
  - `flutter build apk --release`
- **Acceptance Criteria**:
  - Optimized, signed production APK generated successfully.
