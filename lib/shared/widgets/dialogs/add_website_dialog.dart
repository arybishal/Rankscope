import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rankscope/core/errors/failures.dart';
import 'package:rankscope/core/theme/app_colors.dart';
import 'package:rankscope/core/theme/app_text_styles.dart';
import 'package:rankscope/core/theme/spacing.dart';
import 'package:rankscope/core/utils/url_validator.dart';
import 'package:rankscope/features/websites/presentation/controllers/websites_controller.dart';
import 'package:rankscope/shared/widgets/buttons/app_primary_button.dart';
import 'package:rankscope/shared/widgets/inputs/app_text_field.dart';

class AddWebsiteDialog extends ConsumerStatefulWidget {
  final Website? initialWebsite;

  const AddWebsiteDialog({super.key, this.initialWebsite});

  @override
  ConsumerState<AddWebsiteDialog> createState() => _AddWebsiteDialogState();
}

class _AddWebsiteDialogState extends ConsumerState<AddWebsiteDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _domainController;
  late final TextEditingController _labelController;
  late final TextEditingController _notesController;
  late final TextEditingController _gscPropertyController;
  late final TextEditingController _bingSiteUrlController;
  late final TextEditingController _yandexHostIdController;
  late bool _isCompetitor;
  bool _showAdvanced = false;
  bool _isSubmitting = false;

  bool get _isEditing => widget.initialWebsite != null;

  @override
  void initState() {
    super.initState();
    _domainController = TextEditingController(
      text: widget.initialWebsite?.domain ?? '',
    );
    _labelController = TextEditingController(
      text: widget.initialWebsite?.label ?? '',
    );
    _notesController = TextEditingController(
      text: widget.initialWebsite?.notes ?? '',
    );
    _gscPropertyController = TextEditingController(
      text: widget.initialWebsite?.gscPropertyId ?? '',
    );
    _bingSiteUrlController = TextEditingController(
      text: widget.initialWebsite?.bingSiteUrl ?? '',
    );
    _yandexHostIdController = TextEditingController(
      text: widget.initialWebsite?.yandexHostId ?? '',
    );
    _isCompetitor = widget.initialWebsite?.isCompetitor ?? false;
    _showAdvanced = widget.initialWebsite?.gscPropertyId != null ||
        widget.initialWebsite?.bingSiteUrl != null ||
        widget.initialWebsite?.yandexHostId != null;
  }

  @override
  void dispose() {
    _domainController.dispose();
    _labelController.dispose();
    _notesController.dispose();
    _gscPropertyController.dispose();
    _bingSiteUrlController.dispose();
    _yandexHostIdController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    final normalizedDomain = UrlValidator.normalizeDomain(
      _domainController.text,
    );
    final label = _labelController.text.trim().isEmpty
        ? normalizedDomain
        : _labelController.text.trim();
    final notes = _notesController.text.trim().isEmpty
        ? null
        : _notesController.text.trim();
    final gscPropertyId = _gscPropertyController.text.trim().isEmpty
        ? null
        : _gscPropertyController.text.trim();
    final bingSiteUrl = _bingSiteUrlController.text.trim().isEmpty
        ? null
        : _bingSiteUrlController.text.trim();
    final yandexHostId = _yandexHostIdController.text.trim().isEmpty
        ? null
        : _yandexHostIdController.text.trim();

    try {
      if (_isEditing) {
        final updated = widget.initialWebsite!.copyWith(
          domain: normalizedDomain,
          label: label,
          isCompetitor: _isCompetitor,
          notes: notes,
          gscPropertyId: gscPropertyId,
          bingSiteUrl: bingSiteUrl,
          yandexHostId: yandexHostId,
        );
        await ref.read(websitesProvider.notifier).updateWebsite(updated);

        if (mounted) {
          setState(() => _isSubmitting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Website "$label" updated successfully.')),
          );
          Navigator.of(context).pop(updated);
        }
      } else {
        final created = await ref
            .read(websitesProvider.notifier)
            .addWebsite(
              domain: normalizedDomain,
              label: label,
              isCompetitor: _isCompetitor,
              notes: notes,
              gscPropertyId: gscPropertyId,
              bingSiteUrl: bingSiteUrl,
              yandexHostId: yandexHostId,
            );

        if (mounted) {
          setState(() => _isSubmitting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Website "$label" registered successfully.'),
            ),
          );
          Navigator.of(context).pop(created);
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? AppColors.darkCard : AppColors.surfacePrimary,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        side: BorderSide(
          color: isDark ? AppColors.darkBorder : AppColors.borderSubtle,
        ),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isEditing ? 'Edit Website' : 'Track New Website',
                  style: AppTextStyles.titleLarge,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _isEditing
                      ? 'Update website details, labels, notes, or verified search engine properties.'
                      : 'Track your primary domain or monitor competitor search rankings.',
                  style: AppTextStyles.bodySmall,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _domainController,
                  label: 'Domain Name',
                  hintText: 'e.g. example.com or https://example.com',
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter domain';
                    }
                    if (!UrlValidator.isValidDomain(val)) {
                      return 'Invalid domain format';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _labelController,
                  label: 'Display Label (Optional)',
                  hintText: 'e.g. Brand Flagship',
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _notesController,
                  label: 'Notes / Description (Optional)',
                  hintText: 'e.g. Primary e-commerce store',
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Checkbox(
                      value: _isCompetitor,
                      activeColor: AppColors.accent,
                      onChanged: (val) =>
                          setState(() => _isCompetitor = val ?? false),
                    ),
                    const Text(
                      'This is a Competitor website',
                      style: AppTextStyles.bodyMedium,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                InkWell(
                  onTap: () => setState(() => _showAdvanced = !_showAdvanced),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Icon(
                          _showAdvanced
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          size: 18,
                          color: AppColors.accent,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _showAdvanced
                              ? 'Hide Verified Properties'
                              : 'Advanced Verified Properties (Optional)',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_showAdvanced) ...[
                  const SizedBox(height: AppSpacing.sm),
                  AppTextField(
                    controller: _gscPropertyController,
                    label: 'Google Search Console Property ID',
                    hintText: 'e.g. sc-domain:example.com or https://example.com/',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppTextField(
                    controller: _bingSiteUrlController,
                    label: 'Bing Webmaster Site URL',
                    hintText: 'e.g. https://example.com/',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppTextField(
                    controller: _yandexHostIdController,
                    label: 'Yandex Webmaster Host ID',
                    hintText: 'e.g. https:example.com:443',
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                AppPrimaryButton(
                  label: _isSubmitting
                      ? 'Saving...'
                      : (_isEditing ? 'Save Changes' : 'Add Property'),
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
