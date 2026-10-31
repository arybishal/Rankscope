import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/api_documentation_urls.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../shared/widgets/feedback/empty_state_view.dart';
import '../../../../shared/widgets/surfaces/glass_container.dart';
import '../../../dashboard/presentation/views/dashboard_view.dart'
    hide yandexConfiguredProvider;
import '../../../keywords/presentation/controllers/keywords_controller.dart';
import '../../../websites/presentation/controllers/websites_controller.dart';
import '../../../yandex_webmaster/presentation/controllers/yandex_controller.dart';

class SearchEnginesView extends ConsumerStatefulWidget {
  const SearchEnginesView({super.key});

  @override
  ConsumerState<SearchEnginesView> createState() => _SearchEnginesViewState();
}

class _SearchEnginesViewState extends ConsumerState<SearchEnginesView> {
  bool _isSyncingAll = false;

  Future<void> _syncAll(Website website) async {
    setState(() => _isSyncingAll = true);
    try {
      final syncService = SearchPerformanceSyncService();
      final result = await syncService.syncPerformanceForWebsite(
        websiteId: website.id!,
        domain: website.domain,
        gscPropertyId: website.gscPropertyId,
        bingSiteUrl: website.bingSiteUrl,
        yandexHostId: website.yandexHostId,
      );

      // Refresh Riverpod providers
      ref.invalidate(keywordsFamilyProvider(website.id!));
      ref.invalidate(googleConfiguredProvider);
      ref.invalidate(bingConfiguredProvider);
      ref.invalidate(yandexConfiguredProvider);

      if (mounted) {
        final List<String> engines = [
          if (result.googleConnected) 'Google',
          if (result.bingConnected) 'Bing',
          if (result.yandexConnected) 'Yandex',
        ];
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Sync completed: ${result.matchedKeywords} keywords correlated across ${engines.isEmpty ? "no engines configured" : engines.join(", ")}.',
            ),
            backgroundColor: AppColors.rankGain,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: $e'),
            backgroundColor: AppColors.rankDrop,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncingAll = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final websitesState = ref.watch(websitesProvider);
    final selectedSiteId = ref.watch(selectedWebsiteIdProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.surfacePrimary,
      appBar: AppBar(
        title: const Text('Search Engines Hub', style: AppTextStyles.titleLarge),
        actions: [
          IconButton(
            icon: Icon(
              Icons.language_outlined,
              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
            ),
            tooltip: 'Switch Website',
            onPressed: () => context.push('/websites'),
          ),
        ],
      ),
      body: websitesState.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
        error: (err, _) => Center(
          child: Text('Error loading websites: $err', style: AppTextStyles.bodyMedium),
        ),
        data: (websites) {
          final activeWebsite = websites.findActive(selectedSiteId);
          if (activeWebsite == null) {
            return EmptyStateView(
              icon: Icons.hub_outlined,
              title: 'No Website Selected',
              description: 'Select or add a website to configure and sync search engines.',
              actionLabel: 'Manage Websites',
              onAction: () => context.push('/websites'),
            );
          }

          return _SearchEnginesContent(
            website: activeWebsite,
            allWebsites: websites,
            isSyncingAll: _isSyncingAll,
            onSyncAll: () => _syncAll(activeWebsite),
          );
        },
      ),
    );
  }
}

class _SearchEnginesContent extends ConsumerStatefulWidget {
  final Website website;
  final List<Website> allWebsites;
  final bool isSyncingAll;
  final VoidCallback onSyncAll;

  const _SearchEnginesContent({
    required this.website,
    required this.allWebsites,
    required this.isSyncingAll,
    required this.onSyncAll,
  });

  @override
  ConsumerState<_SearchEnginesContent> createState() => _SearchEnginesContentState();
}

class _SearchEnginesContentState extends ConsumerState<_SearchEnginesContent> {
  int? _expandedTutorialIndex; // 0 = Google, 1 = Bing, 2 = Yandex

  Future<void> _launchUrlSafe(String urlString) async {
    final uri = Uri.parse(urlString);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not launch URL: $urlString'),
            backgroundColor: AppColors.rankDrop,
          ),
        );
      }
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard'),
        backgroundColor: AppColors.accent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final googleConfigured = ref.watch(googleConfiguredProvider).value ?? false;
    final bingConfigured = ref.watch(bingConfiguredProvider).value ?? false;
    final yandexConfigured = ref.watch(yandexConfiguredProvider).value ?? false;

    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: () async {
        ref.invalidate(googleConfiguredProvider);
        ref.invalidate(bingConfiguredProvider);
        ref.invalidate(yandexConfiguredProvider);
      },
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // 1. Website Switcher Header
          _buildWebsiteHeader(context, isDark),
          const SizedBox(height: AppSpacing.md),

          // 2. Global Sync Banner with Glassmorphic styling
          _buildGlobalSyncBanner(context, isDark),
          const SizedBox(height: AppSpacing.md),

          // 3. Google Search Console Card
          _buildGoogleCard(context, isDark, googleConfigured),
          const SizedBox(height: AppSpacing.md),

          // 4. Bing Webmaster Tools Card
          _buildBingCard(context, isDark, bingConfigured),
          const SizedBox(height: AppSpacing.md),

          // 5. Yandex Webmaster Card
          _buildYandexCard(context, isDark, yandexConfigured),
          const SizedBox(height: AppSpacing.lg),

          // 6. Ranking Semantics & Average Position Disambiguation
          _buildRankingSemanticsCard(isDark),
          const SizedBox(height: AppSpacing.md),

          // 7. Data Integrity Notice
          _buildDataIntegrityNotice(isDark),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Widget _buildWebsiteHeader(BuildContext context, bool isDark) {
    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: widget.website.id,
          isExpanded: true,
          dropdownColor: isDark ? AppColors.darkCard : AppColors.surfacePrimary,
          items: widget.allWebsites.map((w) {
            return DropdownMenuItem<int>(
              value: w.id,
              child: Row(
                children: [
                  Icon(
                    w.isCompetitor ? Icons.compare_arrows : Icons.language,
                    size: 18,
                    color: w.isCompetitor ? AppColors.rankTop3 : AppColors.accent,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${w.label} (${w.domain})',
                      style: AppTextStyles.labelLarge.copyWith(
                        color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (newId) {
            if (newId != null && newId != widget.website.id) {
              ref.read(selectedWebsiteIdProvider.notifier).select(newId);
            }
          },
        ),
      ),
    );
  }

  Widget _buildGlobalSyncBanner(BuildContext context, bool isDark) {
    return GlassContainer(
      padding: const EdgeInsets.all(AppSpacing.md),
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (isDark ? const Color(0xFF60A5FA) : AppColors.accent).withAlpha(25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.sync,
              size: 22,
              color: isDark ? const Color(0xFF60A5FA) : AppColors.accent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Unified Engine Sync',
                  style: AppTextStyles.labelLarge.copyWith(
                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Fetch queries and ranking observations from all connected APIs.',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? const Color(0xFF2563EB) : AppColors.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            icon: widget.isSyncingAll
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.refresh, size: 16),
            label: Text(widget.isSyncingAll ? 'Syncing...' : 'Sync All'),
            onPressed: widget.isSyncingAll ? null : widget.onSyncAll,
          ),
        ],
      ),
    );
  }

  Widget _buildGoogleCard(BuildContext context, bool isDark, bool isConfigured) {
    final isExpanded = _expandedTutorialIndex == 0;
    return _engineCardWithTutorial(
      context,
      isDark,
      engineIndex: 0,
      engineName: 'Google Search Console',
      brandColor: AppColors.engineGoogle,
      icon: Icons.travel_explore,
      isConfigured: isConfigured,
      mappedResource: widget.website.gscPropertyId ?? 'Auto-detecting from domain',
      statusLabel: isConfigured ? 'Connected & Verified' : 'OAuth Setup Required',
      description: 'Ingests daily search queries, impressions, clicks, CTR, and average position.',
      onConfigure: () => context.push('/search-console'),
      isTutorialExpanded: isExpanded,
      onToggleTutorial: () {
        setState(() {
          _expandedTutorialIndex = isExpanded ? null : 0;
        });
      },
      tutorialContent: _buildGoogleTutorial(isDark),
    );
  }

  Widget _buildBingCard(BuildContext context, bool isDark, bool isConfigured) {
    final isExpanded = _expandedTutorialIndex == 1;
    return _engineCardWithTutorial(
      context,
      isDark,
      engineIndex: 1,
      engineName: 'Bing Webmaster Tools',
      brandColor: AppColors.engineBing,
      icon: Icons.language,
      isConfigured: isConfigured,
      mappedResource: widget.website.bingSiteUrl ?? 'Auto-matching by domain',
      statusLabel: isConfigured ? 'API Key Active' : 'API Key Required',
      description: 'Ingests search queries, impressions, clicks, and average search positions.',
      onConfigure: () => context.push('/bing-webmaster'),
      isTutorialExpanded: isExpanded,
      onToggleTutorial: () {
        setState(() {
          _expandedTutorialIndex = isExpanded ? null : 1;
        });
      },
      tutorialContent: _buildBingTutorial(isDark),
    );
  }

  Widget _buildYandexCard(BuildContext context, bool isDark, bool isConfigured) {
    final isExpanded = _expandedTutorialIndex == 2;
    return _engineCardWithTutorial(
      context,
      isDark,
      engineIndex: 2,
      engineName: 'Yandex Webmaster',
      brandColor: AppColors.engineYandex,
      icon: Icons.search,
      isConfigured: isConfigured,
      mappedResource: widget.website.yandexHostId ?? 'Not mapped to verified host',
      statusLabel: isConfigured ? 'OAuth Token Active' : 'OAuth Token Required',
      description: 'Ingests verified search query history, impressions, clicks, and rank positions via API v4.',
      onConfigure: () => context.push('/yandex-webmaster'),
      isTutorialExpanded: isExpanded,
      onToggleTutorial: () {
        setState(() {
          _expandedTutorialIndex = isExpanded ? null : 2;
        });
      },
      tutorialContent: _buildYandexTutorial(isDark),
    );
  }

  Widget _engineCardWithTutorial(
    BuildContext context,
    bool isDark, {
    required int engineIndex,
    required String engineName,
    required Color brandColor,
    required IconData icon,
    required bool isConfigured,
    required String mappedResource,
    required String statusLabel,
    required String description,
    required VoidCallback onConfigure,
    required bool isTutorialExpanded,
    required VoidCallback onToggleTutorial,
    required Widget tutorialContent,
  }) {
    return GlassContainer(
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Brand Icon + Title + Status Pill
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: brandColor.withAlpha(isDark ? 50 : 25),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(icon, size: 18, color: brandColor),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        engineName,
                        style: AppTextStyles.labelLarge.copyWith(
                          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isConfigured
                            ? (isDark ? AppColors.darkRankGainLight : AppColors.rankGainLight)
                            : (isDark ? AppColors.darkSurfaceSecondary : AppColors.surfaceSecondary),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isConfigured ? AppColors.rankGain : AppColors.borderSubtle,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: isConfigured ? AppColors.rankGain : AppColors.textTertiary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            statusLabel,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isConfigured
                                  ? AppColors.rankGain
                                  : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Description
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),

                // Mapped Property
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceSecondary : AppColors.surfaceSecondary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.link,
                        size: 14,
                        color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Mapped Property: $mappedResource',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Action Row: Setup Tutorial Button + Configure Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: Icon(
                        isTutorialExpanded ? Icons.expand_less : Icons.help_outline,
                        size: 16,
                        color: brandColor,
                      ),
                      label: Text(
                        isTutorialExpanded ? 'Hide Setup Tutorial' : 'Setup Tutorial & Docs',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: brandColor,
                        ),
                      ),
                      onPressed: onToggleTutorial,
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                        side: BorderSide(
                          color: isDark ? AppColors.darkBorderMedium : AppColors.borderMedium,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.tune, size: 14),
                      label: Text(isConfigured ? 'View Data' : 'Connect Account'),
                      onPressed: onConfigure,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Expandable Tutorial Section
          if (isTutorialExpanded) ...[
            Divider(
              height: 1,
              color: isDark ? AppColors.darkBorderSubtle : AppColors.borderSubtle,
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: tutorialContent,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGoogleTutorial(bool isDark) {
    final headingColor = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final bodyColor = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.menu_book_outlined, size: 16, color: AppColors.engineGoogle),
            const SizedBox(width: 6),
            Text(
              'Google Search Console API Onboarding',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: headingColor),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '1. Open Google Cloud Console and select or create a project.\n'
          '2. In API Library, enable the Google Search Console API.\n'
          '3. Navigate to Credentials → Create Credentials → OAuth Client ID (Application type: Android/Desktop/Web).\n'
          '4. Paste the Client ID into RankScope Settings. Zero client secrets are required.\n'
          '5. Authorization uses standard OAuth 2.0 PKCE directly from your Android device.',
          style: TextStyle(fontSize: 12, height: 1.5, color: bodyColor),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurfaceSecondary : const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              const Icon(Icons.security, size: 14, color: AppColors.engineGoogle),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Scope required: https://www.googleapis.com/auth/webmasters.readonly',
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: isDark ? AppColors.darkTextPrimary : AppColors.accent,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.open_in_new, size: 14),
              label: const Text('Official GSC API Docs'),
              onPressed: () => _launchUrlSafe(ApiDocumentationUrls.gscOverview),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.cloud_outlined, size: 14),
              label: const Text('Cloud Console'),
              onPressed: () => _launchUrlSafe(ApiDocumentationUrls.gscCloudConsole),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.copy, size: 14),
              label: const Text('Copy Docs URL'),
              onPressed: () => _copyToClipboard(ApiDocumentationUrls.gscOverview, 'Google API Docs URL'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBingTutorial(bool isDark) {
    final headingColor = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final bodyColor = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.menu_book_outlined, size: 16, color: AppColors.engineBing),
            const SizedBox(width: 6),
            Text(
              'Bing Webmaster Tools API Onboarding',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: headingColor),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '1. Sign in to Bing Webmaster Tools using your Microsoft account.\n'
          '2. Click Settings (gear icon at top right) → API Access → API Key.\n'
          '3. Generate an API Key (32-character hexadecimal key).\n'
          '4. Copy the key and save it in RankScope Settings > Bing Webmaster Tools.\n'
          '5. RankScope will query the official Bing Webmaster JSON endpoint directly with no third-party servers.',
          style: TextStyle(fontSize: 12, height: 1.5, color: bodyColor),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurfaceSecondary : const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle_outline, size: 14, color: AppColors.engineBing),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Format: 32-character hex key • Completely free • Zero quota charges',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.darkTextPrimary : const Color(0xFF065F46),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.open_in_new, size: 14),
              label: const Text('Bing Webmaster Portal'),
              onPressed: () => _launchUrlSafe(ApiDocumentationUrls.bingPortal),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.description_outlined, size: 14),
              label: const Text('API Documentation'),
              onPressed: () => _launchUrlSafe(ApiDocumentationUrls.bingApiDocs),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.copy, size: 14),
              label: const Text('Copy Portal URL'),
              onPressed: () => _copyToClipboard(ApiDocumentationUrls.bingPortal, 'Bing Portal URL'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildYandexTutorial(bool isDark) {
    final headingColor = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final bodyColor = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.menu_book_outlined, size: 16, color: AppColors.engineYandex),
            const SizedBox(width: 6),
            Text(
              'Yandex Webmaster API v4 Onboarding',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: headingColor),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '1. Visit Yandex OAuth Portal to register an application.\n'
          '2. Under "Permissions", grant Yandex Webmaster permissions:\n'
          '   • webmaster:hostinfo (view host list and details)\n'
          '   • webmaster:verify (read verification and query statistics)\n'
          '3. Obtain an OAuth access token and enter it into RankScope Settings.\n'
          '4. RankScope will query the official Yandex Webmaster API directly from your phone.',
          style: TextStyle(fontSize: 12, height: 1.5, color: bodyColor),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurfaceSecondary : const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              const Icon(Icons.key, size: 14, color: AppColors.engineYandex),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Scopes required: webmaster:hostinfo, webmaster:verify',
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: isDark ? AppColors.darkTextPrimary : const Color(0xFF991B1B),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.open_in_new, size: 14),
              label: const Text('Register Yandex App'),
              onPressed: () => _launchUrlSafe(ApiDocumentationUrls.yandexOAuthRegister),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.description_outlined, size: 14),
              label: const Text('Yandex Webmaster API Docs'),
              onPressed: () => _launchUrlSafe(ApiDocumentationUrls.yandexApiDocs),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.copy, size: 14),
              label: const Text('Copy Docs URL'),
              onPressed: () => _copyToClipboard(ApiDocumentationUrls.yandexApiDocs, 'Yandex Docs URL'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRankingSemanticsCard(bool isDark) {
    return GlassContainer(
      padding: const EdgeInsets.all(AppSpacing.md),
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.analytics_outlined,
                size: 20,
                color: isDark ? const Color(0xFF60A5FA) : AppColors.accent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Average Position vs. Point-in-Time Rank',
                  style: AppTextStyles.labelLarge.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '• Webmaster APIs (Google, Bing, Yandex) report statistical Average Position over impressions across all devices, dates, and locations.\n'
            '• Point-in-time SERP Audits report the exact, snapshot ranking position of your target URL at the moment of inspection.\n'
            '• RankScope maintains strict metric separation so averages and discrete positions are never misleadingly blended together.',
            style: TextStyle(
              fontSize: 12,
              height: 1.55,
              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataIntegrityNotice(bool isDark) {
    return GlassContainer(
      padding: const EdgeInsets.all(AppSpacing.md),
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.shield_outlined,
            size: 18,
            color: isDark ? const Color(0xFF60A5FA) : AppColors.accent,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Data Provenance & Privacy Guarantee',
                  style: AppTextStyles.labelMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'All API calls happen directly from your Android phone to the respective search engine. No credentials or search data are ever relayed through a proxy or intermediate server.',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.darkTextTertiary : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
