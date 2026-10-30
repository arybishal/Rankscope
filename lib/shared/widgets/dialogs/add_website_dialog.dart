import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rankscope/core/errors/failures.dart';
import 'package:rankscope/core/theme/app_colors.dart';
import 'package:rankscope/core/theme/app_text_styles.dart';
import 'package:rankscope/core/theme/spacing.dart';
import 'package:rankscope/core/utils/url_validator.dart';
import 'package:rankscope/features/websites/domain/entities/website.dart';
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
  late bool _isCompetitor;
  bool _isSubmitting = false;

  bool get _isEditing => widget.initialWebsite != null;

  @override
  void initState() {
    super.initState();
    _domainController = TextEditingController(text: widget.initialWebsite?.domain ?? '');
    _labelController = TextEditingController(text: widget.initialWebsite?.label ?? '');
    _notesController = TextEditingController(text: widget.initialWebsite?.notes ?? '');
    _isCompetitor = widget.initialWebsite?.isCompetitor ?? false;
  }

  @override
  void dispose() {
    _domainController.dispose();
    _labelController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    final normalizedDomain = UrlValidator.normalizeDomain(_domainController.text);
    final label = _labelController.text.trim().isEmpty ? normalizedDomain : _labelController.text.trim();
    final notes = _notesController.text.trim().isEmpty ? null : _notesController.text.trim();

    try {
      if (_isEditing) {
        final updated = widget.initialWebsite!.copyWith(
          domain: normalizedDomain,
          label: label,
          isCompetitor: _isCompetitor,
          notes: notes,
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
        final created = await ref.read(websitesProvider.notifier).addWebsite(
          domain: normalizedDomain,
          label: label,
          isCompetitor: _isCompetitor,
          notes: notes,
        );

        if (mounted) {
          setState(() => _isSubmitting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Website "$label" registered successfully.')),
          );
          Navigator.of(context).pop(created);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        final message = e is Failure ? e.message : 'Error: $e';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
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
                      ? 'Update website details, labels, or notes.'
                      : 'Track your primary domain or monitor competitor search rankings.',
                  style: AppTextStyles.bodySmall,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _domainController,
                  label: 'Domain Name',
                  hintText: 'e.g. example.com or https://example.com',
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Please enter domain';
                    if (!UrlValidator.isValidDomain(val)) return 'Invalid domain format';
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
                      onChanged: (val) => setState(() => _isCompetitor = val ?? false),
                    ),
                    const Text('This is a Competitor website', style: AppTextStyles.bodyMedium),
                  ],
                ),
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
