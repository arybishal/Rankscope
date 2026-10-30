import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rankscope/core/errors/failures.dart';
import 'package:rankscope/core/theme/app_colors.dart';
import 'package:rankscope/core/theme/app_text_styles.dart';
import 'package:rankscope/core/theme/spacing.dart';
import 'package:rankscope/features/keywords/presentation/controllers/keywords_controller.dart';
import 'package:rankscope/shared/widgets/buttons/app_primary_button.dart';
import 'package:rankscope/shared/widgets/inputs/app_text_field.dart';

/// Professional dialog for creating or editing tracked keywords in RankScope.
class AddKeywordDialog extends ConsumerStatefulWidget {
  final int websiteId;
  final Keyword? initialKeyword;

  const AddKeywordDialog({
    super.key,
    required this.websiteId,
    this.initialKeyword,
  });

  @override
  ConsumerState<AddKeywordDialog> createState() => _AddKeywordDialogState();
}

class _AddKeywordDialogState extends ConsumerState<AddKeywordDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _keywordController;
  late final TextEditingController _targetUrlController;
  late final TextEditingController _cityController;
  late final TextEditingController _tagsController;
  late final TextEditingController _languageController;

  late String _searchEngine;
  late String _country;
  late String _device;
  late bool _isActive;
  bool _showAdvanced = false;
  bool _isSubmitting = false;

  bool get _isEditing => widget.initialKeyword != null;

  static const List<String> _countries = [
    'GLOBAL',
    'US',
    'GB',
    'CA',
    'AU',
    'DE',
    'FR',
    'ES',
    'IN',
    'NP',
    'BR',
    'JP',
  ];

  @override
  void initState() {
    super.initState();
    final kw = widget.initialKeyword;
    _keywordController = TextEditingController(text: kw?.keywordText ?? '');
    _targetUrlController = TextEditingController(text: kw?.targetUrl ?? '');
    _cityController = TextEditingController(text: kw?.targetCity ?? '');
    _tagsController = TextEditingController(text: kw?.tags.join(', ') ?? '');
    _languageController = TextEditingController(text: kw?.language ?? 'en');

    _searchEngine = kw?.searchEngine ?? 'Google';
    _country = kw?.targetCountry ?? 'GLOBAL';
    _device = kw?.device ?? 'Desktop';
    _isActive = kw?.isActive ?? true;

    if (_cityController.text.isNotEmpty ||
        _tagsController.text.isNotEmpty ||
        _languageController.text != 'en' ||
        _device != 'Desktop') {
      _showAdvanced = true;
    }
  }

  @override
  void dispose() {
    _keywordController.dispose();
    _targetUrlController.dispose();
    _cityController.dispose();
    _tagsController.dispose();
    _languageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);

    final keywordText = _keywordController.text.trim();
    final targetUrl = _targetUrlController.text.trim().isEmpty
        ? null
        : _targetUrlController.text.trim();
    final city = _cityController.text.trim().isEmpty
        ? null
        : _cityController.text.trim();
    final language = _languageController.text.trim().isEmpty
        ? 'en'
        : _languageController.text.trim();
    final tags = _tagsController.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    try {
      if (_isEditing) {
        final updated = widget.initialKeyword!.copyWith(
          keywordText: keywordText,
          targetUrl: targetUrl,
          searchEngine: _searchEngine,
          targetCountry: _country,
          targetCity: city,
          language: language,
          device: _device,
          tags: tags,
          isActive: _isActive,
        );

        await ref
            .read(keywordsFamilyProvider(widget.websiteId).notifier)
            .updateKeyword(updated);

        if (mounted) {
          setState(() => _isSubmitting = false);
          Navigator.of(context).pop(updated);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Keyword "$keywordText" updated.'),
              backgroundColor: AppColors.rankGain,
            ),
          );
        }
      } else {
        final created = await ref
            .read(keywordsFamilyProvider(widget.websiteId).notifier)
            .addKeyword(
              keywordText: keywordText,
              targetUrl: targetUrl,
              searchEngine: _searchEngine,
              targetCountry: _country,
              targetCity: city,
              language: language,
              device: _device,
              tags: tags,
              isActive: _isActive,
            );

        if (mounted) {
          setState(() => _isSubmitting = false);
          Navigator.of(context).pop(created);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Keyword "$keywordText" registered successfully.'),
              backgroundColor: AppColors.rankGain,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        final message = e is Failure ? e.message : 'Error: $e';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: AppColors.rankDrop),
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
                    Expanded(
                      child: Text(
                        _isEditing ? 'Edit Keyword' : 'Track New Keyword',
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
                  _isEditing
                      ? 'Modify target queries, engine preferences, or tracking settings.'
                      : 'Add high-value SEO search queries to monitor daily rankings and movements.',
                  style: AppTextStyles.bodySmall,
                ),
                const SizedBox(height: AppSpacing.md),

                // Keyword Text Field
                AppTextField(
                  controller: _keywordController,
                  label: 'Search Query / Keyword *',
                  hintText: 'e.g. best flutter developer',
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter a search query';
                    }
                    if (val.trim().length < 2) {
                      return 'Keyword must be at least 2 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),

                // Search Engine Selector
                const Text(
                  'Search Engine',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: _EngineSelectCard(
                        title: 'Google',
                        icon: Icons.search,
                        isSelected: _searchEngine == 'Google',
                        onTap: () => setState(() => _searchEngine = 'Google'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _EngineSelectCard(
                        title: 'Bing',
                        icon: Icons.travel_explore,
                        isSelected: _searchEngine == 'Bing',
                        onTap: () => setState(() => _searchEngine = 'Bing'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                // Target Country Selector
                const Text(
                  'Target Country',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfacePrimary,
                    borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _countries.contains(_country)
                          ? _country
                          : 'GLOBAL',
                      isExpanded: true,
                      dropdownColor: AppColors.surfacePrimary,
                      items: _countries.map((c) {
                        return DropdownMenuItem<String>(
                          value: c,
                          child: Text(
                            c == 'GLOBAL' ? 'Worldwide / Global' : c,
                            style: AppTextStyles.bodyMedium,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _country = val);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Target URL (Optional)
                AppTextField(
                  controller: _targetUrlController,
                  label: 'Target Landing Page (Optional)',
                  hintText:
                      'e.g. /services/flutter or https://example.com/blog',
                ),
                const SizedBox(height: AppSpacing.sm),

                // Expandable Advanced Options
                InkWell(
                  onTap: () => setState(() => _showAdvanced = !_showAdvanced),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(
                          _showAdvanced
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          size: 18,
                          color: AppColors.accent,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _showAdvanced
                                ? 'Hide Advanced Settings'
                                : 'Advanced Settings (City, Device, Language)',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.accent,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                if (_showAdvanced) ...[
                  const SizedBox(height: AppSpacing.sm),
                  AppTextField(
                    controller: _cityController,
                    label: 'Target City (Where supported)',
                    hintText: 'e.g. New York, London, Kathmandu',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          controller: _languageController,
                          label: 'Language',
                          hintText: 'e.g. en, es, de',
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Device',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfacePrimary,
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.cardRadius,
                                ),
                                border: Border.all(
                                  color: AppColors.borderSubtle,
                                ),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _device,
                                  isExpanded: true,
                                  dropdownColor: AppColors.surfacePrimary,
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'Desktop',
                                      child: Text('Desktop'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Mobile',
                                      child: Text('Mobile'),
                                    ),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() => _device = val);
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: _tagsController,
                    label: 'Tags (Comma-separated)',
                    hintText: 'e.g. core, brand, blog',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Checkbox(
                        value: _isActive,
                        activeColor: AppColors.accent,
                        onChanged: (val) =>
                            setState(() => _isActive = val ?? true),
                      ),
                      const Text(
                        'Active (Tracking Enabled)',
                        style: AppTextStyles.bodyMedium,
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: AppSpacing.lg),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  child: AppPrimaryButton(
                    label: _isSubmitting
                        ? 'Saving...'
                        : (_isEditing ? 'Save Changes' : 'Start Tracking'),
                    isLoading: _isSubmitting,
                    onPressed: _submit,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EngineSelectCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _EngineSelectCard({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFEFF6FF)
              : AppColors.surfaceSecondary,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          border: Border.all(
            color: isSelected ? AppColors.accent : AppColors.borderSubtle,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? AppColors.accent : AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppColors.accent : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
