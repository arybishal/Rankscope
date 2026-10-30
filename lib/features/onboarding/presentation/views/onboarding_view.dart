import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/security/secure_storage_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/spacing.dart';

/// Full-screen interactive onboarding carousel showcasing core RankScope features.
/// Displayed automatically upon first install, and revisit-able from Settings.
class OnboardingView extends StatefulWidget {
  final bool isRevisit;
  final SecureStorageService? storageService;

  const OnboardingView({
    super.key,
    this.isRevisit = false,
    this.storageService,
  });

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const String developerName = '.com.npAryal';
  static const String authorUrl = 'bishalaryal.com.np';

  final List<_FeatureSlideData> _slides = const [
    _FeatureSlideData(
      badgeText: 'FEATURE 1 OF 4 • PORTFOLIO',
      title: 'Multi-Website Intelligence',
      subtitle: 'Manage Your Domains & Competitors',
      description: 'Easily manage multiple websites in one unified workspace with zero cloud accounts or artificial domain limits.',
      icon: Icons.language,
      iconColor: Color(0xFF2563EB),
      iconBgColor: Color(0xFFEFF6FF),
      highlights: [
        _HighlightItem(
          icon: Icons.domain_add_outlined,
          title: 'Multiple Property Support',
          subtitle: 'Add all your personal, client, or competitor domains.',
        ),
        _HighlightItem(
          icon: Icons.tune,
          title: 'Dynamic Property Switcher',
          subtitle:
              'Instantly toggle between active websites and isolate rank data.',
        ),
        _HighlightItem(
          icon: Icons.shield_outlined,
          title: 'Competitor Tracking',
          subtitle:
              'Benchmark your rankings against direct competing websites.',
        ),
      ],
    ),
    _FeatureSlideData(
      badgeText: 'FEATURE 2 OF 4 • RANK TRACKING',
      title: 'Keyword Rank & Target URL Audit',
      subtitle: 'Accurate Positions & Cannibalization',
      description: 'Monitor Google and Bing search rankings while verifying whether your intended landing page is the one ranking.',
      icon: Icons.ads_click,
      iconColor: Color(0xFF0F766E),
      iconBgColor: Color(0xFFF0FDFA),
      highlights: [
        _HighlightItem(
          icon: Icons.check_circle_outline,
          title: 'Landing Page Match Audit',
          subtitle: 'Detects whether the ranking URL matches your target page.',
        ),
        _HighlightItem(
          icon: Icons.warning_amber_rounded,
          title: 'Cannibalization Detection',
          subtitle:
              'Flags internal URL oscillations competing for the same query.',
        ),
        _HighlightItem(
          icon: Icons.timeline,
          title: 'Manual & Automatic SERP History',
          subtitle:
              'Record rank observations with date stamps and delta movements.',
        ),
      ],
    ),
    _FeatureSlideData(
      badgeText: 'FEATURE 3 OF 4 • ENGINE INTEGRATION',
      title: 'Search Console & Bing Sync',
      subtitle: 'Direct Serverless API Sync',
      description: 'Connect directly to Google Search Console and Bing Webmaster Tools API from your phone with zero intermediary proxies.',
      icon: Icons.hub_outlined,
      iconColor: Color(0xFF7C3AED),
      iconBgColor: Color(0xFFF5F3FF),
      highlights: [
        _HighlightItem(
          icon: Icons.sync,
          title: 'Live Query Data Sync',
          subtitle:
              'Correlate keywords with actual clicks, impressions, and CTR.',
        ),
        _HighlightItem(
          icon: Icons.vpn_key_outlined,
          title: 'Android KeyStore Security',
          subtitle:
              'API keys and OAuth tokens are protected by hardware encryption.',
        ),
        _HighlightItem(
          icon: Icons.verified_user_outlined,
          title: 'Canonical Domain Verification',
          subtitle: 'Automatically matches local domains to verified Webmaster sites.',
        ),
      ],
    ),
    _FeatureSlideData(
      badgeText: 'FEATURE 4 OF 4 • PRIVACY & BACKUPS',
      title: '100% Device-Only Privacy',
      subtitle: 'Zero Telemetry & Encrypted Backups',
      description: 'All your SEO rankings and keywords live strictly in your phone SQLite database with zero tracking and full data sovereignty.',
      icon: Icons.lock_outline,
      iconColor: Color(0xFF16A34A),
      iconBgColor: Color(0xFFF0FDF4),
      highlights: [
        _HighlightItem(
          icon: Icons.storage_outlined,
          title: 'Local-First SQLite Engine',
          subtitle: 'Complete functionality offline with zero recurring subscription fees.',
        ),
        _HighlightItem(
          icon: Icons.enhanced_encryption_outlined,
          title: 'AES-256-GCM Encrypted Backups',
          subtitle: 'Password-protected backup exports and full database restoration.',
        ),
        _HighlightItem(
          icon: Icons.picture_as_pdf_outlined,
          title: 'Executive PDF & CSV Reports',
          subtitle: 'Export clean client reports directly to device storage.',
        ),
      ],
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    try {
      final storage = widget.storageService ?? SecureStorageService();
      await storage.setCompletedOnboarding(true);
    } catch (_) {}

    if (!mounted) return;

    if (widget.isRevisit) {
      context.pop();
    } else {
      context.go('/dashboard');
    }
  }

  void _nextPage() {
    if (_currentPage < _slides.length - 1) {
      _pageController.animateToPage(
        _currentPage + 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _copyAuthorUrl() {
    Clipboard.setData(const ClipboardData(text: 'https://$authorUrl'));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 16),
            SizedBox(width: 8),
            Text('Author URL copied: bishalaryal.com.np'),
          ],
        ),
        backgroundColor: AppColors.accent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLastPage = _currentPage == _slides.length - 1;

    return Scaffold(
      backgroundColor: AppColors.surfacePrimary,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.surfacePrimary,
        leading: widget.isRevisit
            ? IconButton(
                icon: const Icon(
                  Icons.arrow_back,
                  color: AppColors.textPrimary,
                ),
                tooltip: 'Back to Settings',
                onPressed: () => context.pop(),
              )
            : null,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.track_changes,
                size: 16,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'RankScope',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        centerTitle: false,
        actions: [
          if (!widget.isRevisit && !isLastPage)
            TextButton(
              onPressed: _completeOnboarding,
              child: const Text(
                'Skip Tour',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Carousel Slides
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemBuilder: (context, index) {
                  final slide = _slides[index];
                  final isFinalSlide = index == _slides.length - 1;
                  return _buildSlide(slide, isFinalSlide);
                },
              ),
            ),

            // Bottom Controls Bar
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: const BoxDecoration(
                color: AppColors.surfacePrimary,
                border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Page Indicator Dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_slides.length, (index) {
                      final isSelected = index == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        height: 6,
                        width: isSelected ? 24 : 6,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.accent
                              : const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 12),

                  // Actions
                  if (isLastPage)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppSpacing.cardRadius,
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.rocket_launch, size: 18),
                        label: Text(
                          widget.isRevisit
                              ? 'Finish Tour'
                              : 'Get Started with RankScope',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: _completeOnboarding,
                      ),
                    )
                  else
                    Row(
                      children: [
                        if (!widget.isRevisit)
                          TextButton(
                            onPressed: _completeOnboarding,
                            child: const Text(
                              'Skip',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        else
                          const SizedBox.shrink(),
                        const Spacer(),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppSpacing.cardRadius,
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.arrow_forward, size: 16),
                          label: const Text(
                            'Next',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onPressed: _nextPage,
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlide(_FeatureSlideData slide, bool isFinalSlide) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Visual Hero Icon
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: slide.iconBgColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: slide.iconColor.withValues(alpha: 0.2),
                  width: 1.5,
                ),
              ),
              child: Icon(slide.icon, size: 36, color: slide.iconColor),
            ),
          ),
          const SizedBox(height: 16),

          // Badge Pill
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Text(
                slide.badgeText,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.6,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Title & Subtitle
          Center(
            child: Text(
              slide.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              slide.subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.accent,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              slide.description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 3 Feature Highlights
          ...slide.highlights.map((h) => _buildHighlightCard(h)),

          // Developer & Author Attribution Card (featured prominently on final slide)
          if (isFinalSlide) ...[
            const SizedBox(height: 12),
            _buildDeveloperCard(),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildHighlightCard(_HighlightItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(item.icon, size: 16, color: AppColors.accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeveloperCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.code, size: 16, color: AppColors.accent),
              SizedBox(width: 6),
              Text(
                'Developer & Author Information',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Row(
            children: [
              Text(
                'Developer: ',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                developerName,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          InkWell(
            onTap: _copyAuthorUrl,
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  const Text(
                    'author url: ',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const Text(
                    authorUrl,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: AppColors.accent,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.copy, size: 12, color: AppColors.accent),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureSlideData {
  final String badgeText;
  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final List<_HighlightItem> highlights;

  const _FeatureSlideData({
    required this.badgeText,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.highlights,
  });
}

class _HighlightItem {
  final IconData icon;
  final String title;
  final String subtitle;

  const _HighlightItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}
