import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rankscope/core/theme/app_colors.dart';
import 'package:rankscope/core/theme/app_text_styles.dart';
import 'package:rankscope/core/theme/spacing.dart';
import 'package:rankscope/features/keywords/domain/entities/keyword.dart';
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
  final String _engine = 'Google';
  String _country = 'GLOBAL';

  bool _featuredSnippet = false;
  bool _localPack = false;
  bool _peopleAlsoAsk = false;
  bool _videoCarousel = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _country = widget.keyword.targetCountry;
    _cityController.text = widget.keyword.targetCity ?? '';
    _urlController.text = widget.keyword.targetUrl ?? '';
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

    final pos = int.parse(_posController.text.trim());
    final mask = ManualRankRecord.buildBitmask(
      featuredSnippet: _featuredSnippet,
      localPack: _localPack,
      peopleAlsoAsk: _peopleAlsoAsk,
      videoCarousel: _videoCarousel,
    );

    setState(() => _isSubmitting = true);

    final success = await ref
        .read(manualRankNotifierProvider.notifier)
        .recordRank(
          keywordId: widget.keyword.id!,
          websiteId: widget.websiteId,
          position: pos,
          rankingUrl: _urlController.text.trim().isEmpty
              ? null
              : _urlController.text.trim(),
          searchEngine: _engine,
          locationCountry: _country,
          locationCity: _cityController.text.trim().isEmpty
              ? null
              : _cityController.text.trim(),
          serpFeaturesMask: mask,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
        );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        Navigator.of(context).pop(true);
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
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Log Verified SERP Rank',
                style: AppTextStyles.titleLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Keyword: "${widget.keyword.keywordText}"',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _posController,
                label: 'Exact SERP Position (1-100)',
                hintText: 'e.g. 1, 4, 12',
                keyboardType: TextInputType.number,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter ranking position';
                  }
                  final n = int.tryParse(val.trim());
                  if (n == null || n < 1 || n > 100) {
                    return 'Position must be between 1 and 100';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _urlController,
                label: 'Detected Landing Page URL (Optional)',
                hintText: 'https://example.com/blog/article',
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _cityController,
                      label: 'Verified City (Optional)',
                      hintText: 'e.g. Chicago',
                    ),
                  ),
                ],
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
                    onSelected: (val) => setState(() => _featuredSnippet = val),
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
    );
  }
}
