import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../features/keywords/presentation/controllers/keywords_controller.dart';
import '../buttons/app_primary_button.dart';
import '../inputs/app_text_field.dart';

const List<String> _groupColorPresets = [
  '#2563EB', // Blue
  '#10B981', // Emerald
  '#8B5CF6', // Purple
  '#F59E0B', // Amber
  '#F43F5E', // Rose
  '#06B6D4', // Cyan
  '#64748B', // Slate
];

Color _parseHex(String? hexString, {Color fallback = const Color(0xFF2563EB)}) {
  if (hexString == null || hexString.isEmpty) return fallback;
  final buffer = StringBuffer();
  if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
  buffer.write(hexString.replaceFirst('#', ''));
  try {
    return Color(int.parse(buffer.toString(), radix: 16));
  } catch (_) {
    return fallback;
  }
}

/// Dialog to manage, create, edit, and delete keyword groups for a website.
class ManageKeywordGroupsDialog extends ConsumerStatefulWidget {
  final int websiteId;

  const ManageKeywordGroupsDialog({super.key, required this.websiteId});

  @override
  ConsumerState<ManageKeywordGroupsDialog> createState() =>
      _ManageKeywordGroupsDialogState();
}

class _ManageKeywordGroupsDialogState
    extends ConsumerState<ManageKeywordGroupsDialog> {
  void _openCreateOrEditGroupDialog({KeywordGroup? group}) {
    showDialog(
      context: context,
      builder: (ctx) => _GroupEditorDialog(
        websiteId: widget.websiteId,
        existingGroup: group,
      ),
    );
  }

  void _confirmDeleteGroup(KeywordGroup group) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          side: const BorderSide(color: AppColors.borderSubtle),
        ),
        title: const Text('Delete Group', style: AppTextStyles.titleLarge),
        content: Text(
          'Are you sure you want to delete "${group.name}"?\n\n'
          'Keywords assigned to this group will remain intact and be moved to Ungrouped. No ranking data or history will be lost.',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.rankDrop,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ref
                  .read(keywordGroupsFamilyProvider(widget.websiteId).notifier)
                  .deleteGroup(group.id!);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Group "${group.name}" deleted.')),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final groupsAsync = ref.watch(keywordGroupsFamilyProvider(widget.websiteId));

    return Dialog(
      backgroundColor: isDark ? AppColors.darkCard : AppColors.surfacePrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Keyword Groups', style: AppTextStyles.titleLarge),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              Text(
                'Organize keywords into topic clusters or campaigns without risking ranking history.',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Groups List
              Expanded(
                child: groupsAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: AppColors.accent),
                  ),
                  error: (err, _) => Center(
                    child: Text('Error: $err', style: AppTextStyles.bodyMedium),
                  ),
                  data: (groups) {
                    if (groups.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.folder_open_outlined,
                              size: 48,
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.textSecondary,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            const Text(
                              'No custom groups yet',
                              style: AppTextStyles.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Create a group to categorize and monitor keywords together.',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.textSecondary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      itemCount: groups.length,
                      separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final g = groups[index];
                        final color = _parseHex(g.colorHex);

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.darkBackground
                                : AppColors.surfaceSecondary,
                            borderRadius:
                                BorderRadius.circular(AppSpacing.cardRadius),
                            border: Border.all(
                              color: isDark
                                  ? AppColors.darkBorder
                                  : AppColors.borderSubtle,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: color,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      g.name,
                                      style: AppTextStyles.labelLarge,
                                    ),
                                    if (g.description != null &&
                                        g.description!.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        g.description!,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isDark
                                              ? AppColors.darkTextSecondary
                                              : AppColors.textSecondary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                    const SizedBox(height: 4),
                                    Text(
                                      '${g.keywordCount} keywords'
                                      '${g.averagePosition != null ? " • Avg #${g.averagePosition!.toStringAsFixed(1)}" : ""}'
                                      '${g.totalImpressions > 0 ? " • ${g.totalImpressions} imp" : ""}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: isDark
                                            ? AppColors.darkTextSecondary
                                            : AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                tooltip: 'Edit Group',
                                onPressed: () =>
                                    _openCreateOrEditGroupDialog(group: g),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18),
                                color: AppColors.rankDrop,
                                tooltip: 'Delete Group',
                                onPressed: () => _confirmDeleteGroup(g),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              const SizedBox(height: AppSpacing.md),
              AppPrimaryButton(
                label: 'Create New Group',
                icon: const Icon(Icons.add, size: 18, color: Colors.white),
                onPressed: () => _openCreateOrEditGroupDialog(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupEditorDialog extends ConsumerStatefulWidget {
  final int websiteId;
  final KeywordGroup? existingGroup;

  const _GroupEditorDialog({
    required this.websiteId,
    this.existingGroup,
  });

  @override
  ConsumerState<_GroupEditorDialog> createState() => _GroupEditorDialogState();
}

class _GroupEditorDialogState extends ConsumerState<_GroupEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  late String _selectedColor;
  bool _isSaving = false;

  bool get _isEditing => widget.existingGroup != null;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.existingGroup?.name ?? '');
    _descController =
        TextEditingController(text: widget.existingGroup?.description ?? '');
    _selectedColor = widget.existingGroup?.colorHex ?? _groupColorPresets.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSaving) return;

    setState(() => _isSaving = true);

    try {
      if (_isEditing) {
        final updated = widget.existingGroup!.copyWith(
          name: _nameController.text.trim(),
          colorHex: _selectedColor,
          description: _descController.text.trim().isEmpty
              ? null
              : _descController.text.trim(),
        );
        await ref
            .read(keywordGroupsFamilyProvider(widget.websiteId).notifier)
            .updateGroup(updated);
      } else {
        await ref
            .read(keywordGroupsFamilyProvider(widget.websiteId).notifier)
            .createGroup(
              name: _nameController.text.trim(),
              colorHex: _selectedColor,
              description: _descController.text.trim().isEmpty
                  ? null
                  : _descController.text.trim(),
            );
      }

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving group: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      backgroundColor: isDark ? AppColors.darkCard : AppColors.surfacePrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      title: Text(
        _isEditing ? 'Edit Keyword Group' : 'Create Keyword Group',
        style: AppTextStyles.titleLarge,
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppTextField(
                controller: _nameController,
                label: 'Group Name',
                hintText: 'e.g. Core Brand, High Commercial, Blog Topic',
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter a group name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _descController,
                label: 'Description (Optional)',
                hintText: 'e.g. High priority search queries for Q1 launch',
              ),
              const SizedBox(height: AppSpacing.md),
              const Text(
                'Group Color Badge',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _groupColorPresets.map((hex) {
                  final color = _parseHex(hex);
                  final isSelected = _selectedColor == hex;

                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = hex),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? (isDark ? Colors.white : Colors.black)
                              : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, size: 18, color: Colors.white)
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  _isEditing ? 'Save Changes' : 'Create Group',
                  style: const TextStyle(color: Colors.white),
                ),
        ),
      ],
    );
  }
}
