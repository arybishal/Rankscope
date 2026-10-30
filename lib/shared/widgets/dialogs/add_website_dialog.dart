import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rankscope/core/theme/app_colors.dart';
import 'package:rankscope/core/theme/app_text_styles.dart';
import 'package:rankscope/core/theme/spacing.dart';
import 'package:rankscope/core/utils/url_validator.dart';
import 'package:rankscope/features/websites/presentation/controllers/websites_controller.dart';
import 'package:rankscope/shared/widgets/buttons/app_primary_button.dart';
import 'package:rankscope/shared/widgets/inputs/app_text_field.dart';

class AddWebsiteDialog extends ConsumerStatefulWidget {
  const AddWebsiteDialog({super.key});

  @override
  ConsumerState<AddWebsiteDialog> createState() => _AddWebsiteDialogState();
}

class _AddWebsiteDialogState extends ConsumerState<AddWebsiteDialog> {
  final _formKey = GlobalKey<FormState>();
  final _domainController = TextEditingController();
  final _labelController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isCompetitor = false;
  bool _isSubmitting = false;

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

    final website = await ref.read(websitesProvider.notifier).addWebsite(
      domain: normalizedDomain,
      label: label,
      isCompetitor: _isCompetitor,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (website != null) {
        Navigator.of(context).pop(website);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to add website. Domain may already exist.')),
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
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Track New Website', style: AppTextStyles.titleLarge),
              const SizedBox(height: AppSpacing.xs),
              const Text(
                'Track your primary domain or monitor competitor search rankings.',
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
                label: _isSubmitting ? 'Saving...' : 'Add Property',
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
