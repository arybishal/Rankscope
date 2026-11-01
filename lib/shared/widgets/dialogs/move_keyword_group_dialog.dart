import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../features/keywords/presentation/controllers/keywords_controller.dart';

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

/// Dialog to move one or multiple keywords to a selected group.
class MoveKeywordGroupDialog extends ConsumerStatefulWidget {
  final int websiteId;
  final List<int> keywordIds;
  final String keywordSummaryText;
  final int? currentGroupId;

  const MoveKeywordGroupDialog({
    super.key,
    required this.websiteId,
    required this.keywordIds,
    required this.keywordSummaryText,
    this.currentGroupId,
  });

  @override
  ConsumerState<MoveKeywordGroupDialog> createState() =>
      _MoveKeywordGroupDialogState();
}

class _MoveKeywordGroupDialogState
    extends ConsumerState<MoveKeywordGroupDialog> {
  int? _selectedGroupId;
  bool _isMoving = false;

  @override
  void initState() {
    super.initState();
    _selectedGroupId = widget.currentGroupId;
  }

  Future<void> _move() async {
    if (_isMoving) return;
    setState(() => _isMoving = true);

    try {
      await ref
          .read(keywordsFamilyProvider(widget.websiteId).notifier)
          .assignKeywordsToGroup(widget.keywordIds, _selectedGroupId);

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${widget.keywordIds.length} keyword(s) moved successfully.',
            ),
            backgroundColor: AppColors.rankGain,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isMoving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error moving keywords: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final groupsAsync = ref.watch(keywordGroupsFamilyProvider(widget.websiteId));

    return AlertDialog(
      backgroundColor: isDark ? AppColors.darkCard : AppColors.surfacePrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      title: const Text('Move to Group', style: AppTextStyles.titleLarge),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Moving "${widget.keywordSummaryText}"',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              'Select destination group. All historical rankings, notes, and metrics are preserved.',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Flexible(
              child: groupsAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.accent),
                ),
                error: (err, _) => Center(
                  child: Text('Error: $err', style: AppTextStyles.bodyMedium),
                ),
                data: (groups) {
                  return ListView(
                    shrinkWrap: true,
                    children: [
                      // Ungrouped option
                      ListTile(
                        leading: Icon(
                          _selectedGroupId == null
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          color: _selectedGroupId == null
                              ? AppColors.accent
                              : (isDark
                                  ? AppColors.darkTextTertiary
                                  : AppColors.textTertiary),
                        ),
                        title: const Text('No Group (Ungrouped)'),
                        subtitle: const Text('General tracked keywords pool'),
                        trailing: Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        onTap: () => setState(() => _selectedGroupId = null),
                      ),
                      const Divider(height: 1),
                      // Custom groups
                      ...groups.map(
                        (g) => ListTile(
                          leading: Icon(
                            _selectedGroupId == g.id
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                            color: _selectedGroupId == g.id
                                ? AppColors.accent
                                : (isDark
                                    ? AppColors.darkTextTertiary
                                    : AppColors.textTertiary),
                          ),
                          title: Text(g.name),
                          subtitle: Text('${g.keywordCount} keywords currently'),
                          trailing: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _parseHex(g.colorHex),
                            ),
                          ),
                          onTap: () => setState(() => _selectedGroupId = g.id),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
          onPressed: _isMoving ? null : _move,
          child: _isMoving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text(
                  'Apply Move',
                  style: TextStyle(color: Colors.white),
                ),
        ),
      ],
    );
  }
}
