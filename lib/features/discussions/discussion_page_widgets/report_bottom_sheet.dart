import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../presentation/controllers/discussion_controller.dart';

class ReportBottomSheet extends ConsumerStatefulWidget {
  final int mangaId;
  final String commentId;
  final String? chapterId;

  const ReportBottomSheet({
    super.key,
    required this.mangaId,
    required this.commentId,
    this.chapterId,
  });

  @override
  ConsumerState<ReportBottomSheet> createState() => _ReportBottomSheetState();
}

class _ReportBottomSheetState extends ConsumerState<ReportBottomSheet> {
  String? _selectedReason;
  final List<String> _reasons = [
    'Spam',
    'Abusive Content',
    'Inappropriate Language',
    'Spoiler without Tag',
    'Off-topic',
    'Other',
  ];
  final TextEditingController _detailsController = TextEditingController();

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    if (_selectedReason == null) return;

    final success = await ref
        .read(
          discussionControllerProvider((
            mangaId: widget.mangaId,
            chapterId: widget.chapterId,
          )).notifier,
        )
        .reportComment(
          commentId: widget.commentId,
          reason: _selectedReason!,
          details: _detailsController.text.trim(),
        );

    if (mounted) {
      Navigator.pop(context, success);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "Report Comment",
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const Text("Select a reason for reporting this comment:"),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _reasons.map((reason) {
              final isSelected = _selectedReason == reason;
              return ChoiceChip(
                label: Text(reason),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() => _selectedReason = selected ? reason : null);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _detailsController,
            decoration: const InputDecoration(
              hintText: "Additional details (optional)",
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _selectedReason != null ? _submitReport : null,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: theme.colorScheme.errorContainer,
              foregroundColor: theme.colorScheme.onErrorContainer,
            ),
            child: const Text("Submit Report"),
          ),
        ],
      ),
    );
  }
}
