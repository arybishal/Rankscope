# RankScope v1.0.2 - Keyword Intelligence, Landing URLs & Black Screen Fix

## 🚀 What's New in v1.0.2

### 🛠️ Critical Bug Fixes
- **Keyword Creation Black Screen Resolved**: Fixed root cause navigation issue where saving a keyword dismissed the root GoRouter branch route rather than the isolated dialog context. Newly tracked keywords now immediately render on the dashboard without black screens or app restarts.
- **Form Flex Overflow Resolved**: Eliminated the 26px RenderFlex horizontal overflow on the Advanced Settings button for narrow screens by applying flex constraints.
- **SQLite Parameterization**: Corrected duplicate keyword queries to avoid SQL identifier misinterpretations for empty strings in SQLite.

### 🌟 New Keyword Intelligence Engine
- **Multi-Search Engine Separation**: Independent position tracking, movement deltas, and historical observations for Google and Bing.
- **Strict Rank Display Standard**: Unambiguous separation between exact SERP positions (`#1` to `#100`), confirmed absent (`0`), and unranked/pending (`—`).
- **Detected Ranking Landing URLs**: Automatic extraction and storage of specific ranking URLs with one-tap clipboard copy action.
- **Keyword Cannibalization Detection**: Automatic identification of `multiple_urls` and `url_switching` across observation checks with visual warning banners and affected URL lists.
- **Keyword Lifecycle Transitions**: State tracking for `new` (first-time ranked), `lost` (dropped to position 0), and `recovered` (re-entered top 100) status events.
- **Keyword Details Screen**: Comprehensive view with 7D/30D/90D/All timeframe filtering, search engine comparison breakdown, detected ranking URLs, and full observation history timeline.
- **Dashboard SEO KPIs Grid**: 6 high-level metric cards for Tracked queries, Ranking (1-100), Not Ranking (0), Improved, Declined, and Cannibalization alerts.
- **Database Schema Migration 003**: Added `rank_observations` table with performance indexes on `keyword_id`, `search_engine`, `ranking_url`, and `recorded_at DESC`.
- **Encrypted Backup & CSV Export Expansion**: Enriched `.rankscope` encrypted snapshots and RFC 4180 CSV exports with complete rank observation records and landing URLs.

---

### 📦 Release Asset Verification
- **File**: `RankScope-v1.0.2.apk` (55.1 MB)
- **SHA-256**: `28A18886E865A4FC11F407972CD9BD9AD92D5C5B10372C21202D6D60B4C3FC57`
