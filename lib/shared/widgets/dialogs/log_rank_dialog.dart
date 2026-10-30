import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rankscope/core/theme/app_colors.dart';
import 'package:rankscope/core/theme/app_text_styles.dart';
import 'package:rankscope/core/theme/spacing.dart';
import 'package:rankscope/features/keywords/presentation/controllers/keywords_controller.dart';
import 'package:rankscope/features/manual_tracking/domain/entities/manual_rank_record.dart';
import 'package:rankscope/features/manual_tracking/presentation/controllers/manual_rank_controller.dart';
import 'package:rankscope/shared/widgets/buttons/app_primary_button.dart';
import 'package:rankscope/shared/widgets/inputs/app_text_field.dart';

class LogRankDialog extends ConsumerStatefulWidget {
  final Keyword keyword;
  final int websiteId;

  const LogRankDialog({
    super.key,
    required this.keyword,
    required this.websiteId,
  });

  @override
  ConsumerState<LogRankDialog> createState() => _LogRankDialogState();
}

class _LogRankDialogState extends ConsumerState<LogRankDialog> {
  final _formKey = GlobalKey<FormState>();
  final _posController = TextEditingController();
  final _urlController = TextEditingController();
  final _cityController = TextEditingController();
  final _notesController = TextEditingController();
  String _engine = 'Google';
  String _country = 'GLOBAL';

  bool _featuredSnippet = false;
  bool _localPack = false;
  bool _peopleAlsoAsk = false;
  bool _videoCarousel = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _engine = widget.keyword.searchEngine;
    _country = widget.keyword.targetCountry;
    _cityController.text = widget.keyword.targetCity ?? '';
    _urlController.text =
        widget.keyword.rankingUrl ?? widget.keyword.targetUrl ?? '';
    final curPos = widget.keyword.positionFor(_engine);
    if (curPos != null) {
      _posController.text = curPos.toString();
    }
  }

  @override
  void dispose() {
    _posController.dispose();
    _urlController.dispose();
    _cityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSubmitting) return;

    final pos = int.parse(_posController.text.trim());
    final mask = ManualRankRecord.buildBitmask(
      featuredSnippet: _featuredSnippet,
      localPack: _localPack,
      peopleAlsoAsk: _peopleAlsoAsk,
      videoCarousel: _videoCarousel,
    );

    setState(() => _isSubmitting = true);

    try {
      final rankingUrl = _urlController.text.trim().isEmpty
          ? null
          : _urlController.text.trim();
      final notes = _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim();

      // 1. Record in manual_rank_records if pos >= 1
      if (pos >= 1) {
        await ref
            .read(manualRankNotifierProvider.notifier)
            .recordRank(
              keywordId: widget.keyword.id!,
              websiteId: widget.websiteId,
              position: pos,
              rankingUrl: rankingUrl,
              searchEngine: _engine,
              locationCountry: _country,
              locationCity: _cityController.text.trim().isEmpty
                  ? null
                  : _cityController.text.trim(),
              serpFeaturesMask: mask,
              notes: notes,
            );
      }

      // 2. Record full rank observation with intelligence transitions
      final obs = RankObservation(
        keywordId: widget.keyword.id!,
        websiteId: widget.websiteId,
        searchEngine: _engine,
        position: pos,
        rankingUrl: rankingUrl,
        country: _country,
        recordedAt: DateTime.now(),
        source: 'manual',
        observationStatus: pos > 0 ? 'ranking' : 'not_ranking',
        notes: notes,
      );

      await ref
          .read(keywordsFamilyProvider(widget.websiteId).notifier)
          .recordObservation(obs);

      if (mounted) {
        setState(() => _isSubmitting = false);
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              pos > 0
                  ? 'Rank #$pos on $_engine recorded successfully.'
                  : 'Confirmed Not Ranking (0) recorded on $_engine.',
            ),
            backgroundColor: AppColors.rankGain,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to record rank: $e'),
            backgroundColor: AppColors.rankDrop,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surfacePrimary,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        side: const BorderSide(color: AppColors.borderSubtle),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Log Verified SERP Rank',
                        style: AppTextStyles.titleLarge,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Keyword: "${widget.keyword.keywordText}"',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Search Engine Switcher
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _engine = 'Google'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _engine == 'Google'
                                ? const Color(0xFFEFF6FF)
                                : AppColors.surfaceSecondary,
                            borderRadius: BorderRadius.circular(
                              AppSpacing.cardRadius,
                            ),
                            border: Border.all(
                              color: _engine == 'Google'
                                  ? AppColors.accent
                                  : AppColors.borderSubtle,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              'Google',
                              style: TextStyle(
                                fontWeight: _engine == 'Google'
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: _engine == 'Google'
                                    ? AppColors.accent
                                    : AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _engine = 'Bing'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _engine == 'Bing'
                                ? const Color(0xFFEFF6FF)
                                : AppColors.surfaceSecondary,
                            borderRadius: BorderRadius.circular(
                              AppSpacing.cardRadius,
                            ),
                            border: Border.all(
                              color: _engine == 'Bing'
                                  ? AppColors.accent
                                  : AppColors.borderSubtle,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              'Bing',
                              style: TextStyle(
                                fontWeight: _engine == 'Bing'
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: _engine == 'Bing'
                                    ? AppColors.accent
                                    : AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                AppTextField(
                  controller: _posController,
                  label: 'SERP Position (1-100, or 0 for Not Ranking)',
                  hintText: 'e.g. 1, 4, 12, or 0',
                  keyboardType: TextInputType.number,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter ranking position';
                    }
                    final n = int.tryParse(val.trim());
                    if (n == null || n < 0 || n > 100) {
                      return 'Position must be between 0 and 100';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),

                AppTextField(
                  controller: _urlController,
                  label: 'Detected Ranking URL (Landing Page)',
                  hintText: 'https://example.com/blog/article',
                ),
                const SizedBox(height: AppSpacing.md),

                AppTextField(
                  controller: _notesController,
                  label: 'Notes / Observation Context (Optional)',
                  hintText: 'e.g. Checked on incognito window',
                ),
                const SizedBox(height: AppSpacing.md),

                const Text(
                  'SERP Features Detected',
                  style: AppTextStyles.labelMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    FilterChip(
                      label: const Text('Featured Snippet'),
                      selected: _featuredSnippet,
                      onSelected: (val) =>
                          setState(() => _featuredSnippet = val),
                    ),
                    FilterChip(
                      label: const Text('Local Pack / Map'),
                      selected: _localPack,
                      onSelected: (val) => setState(() => _localPack = val),
                    ),
                    FilterChip(
                      label: const Text('People Also Ask'),
                      selected: _peopleAlsoAsk,
                      onSelected: (val) => setState(() => _peopleAlsoAsk = val),
                    ),
                    FilterChip(
                      label: const Text('Video Carousel'),
                      selected: _videoCarousel,
                      onSelected: (val) => setState(() => _videoCarousel = val),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                AppPrimaryButton(
                  label: _isSubmitting ? 'Recording...' : 'Save Audit Record',
                  isLoading: _isSubmitting,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
