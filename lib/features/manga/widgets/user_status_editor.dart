import 'package:flutter/material.dart';

class UserStatusEditor extends StatelessWidget {
  final double rating;
  final String? status;
  final bool isFavorite;
  final bool isSaving;
  final bool existsInList;
  final String mangaStatus;
  final TextEditingController commentController;
  final ValueChanged<double> onRatingChanged;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<bool?> onFavoriteChanged;
  final VoidCallback onSave;
  final VoidCallback onRemove;

  const UserStatusEditor({
    super.key,
    required this.rating,
    required this.status,
    required this.isFavorite,
    required this.isSaving,
    required this.existsInList,
    required this.mangaStatus,
    required this.commentController,
    required this.onRatingChanged,
    required this.onStatusChanged,
    required this.onFavoriteChanged,
    required this.onSave,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // --- LOGIC: STATUS OPTIONS ---
    List<String> options = [
      'Plan to Read',
      'Reading',
      'Completed',
      'On Hold',
      'Dropped',
    ];

    final bool allowCompleted = [
      'FINISHED',
      'CANCELLED',
      'ONESHOT',
    ].contains(mangaStatus.toUpperCase());

    if (!allowCompleted && status != 'Completed') {
      options.remove('Completed');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. RATING SECTION
        Center(
          child: Column(
            children: [
              _StarRating(
                rating: rating,
                onRatingChanged: onRatingChanged,
                color: Colors.amber,
              ),
              const SizedBox(height: 4),
              Text(
                rating > 0 ? rating.toStringAsFixed(1) : "No rating",
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // 2. PRIMARY ACTIONS ROW (Favorite & Status)
        Row(
          children: [
            // Status Selector
            Expanded(
              flex: 3,
              child: _StatusSelector(
                currentStatus: status,
                options: options,
                onChanged: onStatusChanged,
                isSaving: isSaving,
              ),
            ),
            const SizedBox(width: 12),
            // Favorite Toggle (Heart Only)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onFavoriteChanged(!isFavorite),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isFavorite
                          ? Colors.red.withValues(alpha: 0.5)
                          : colorScheme.onSurface.withValues(alpha: 0.1),
                    ),
                    borderRadius: BorderRadius.circular(8),
                    color: isFavorite
                        ? Colors.red.withValues(alpha: 0.05)
                        : null,
                  ),
                  child: Icon(
                    isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: isFavorite
                        ? Colors.red
                        : colorScheme.onSurface.withValues(alpha: 0.6),
                    size: 26,
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // 3. NOTES SECTION
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "YOUR NOTES",
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: colorScheme.primary,
                  ),
                ),
                if (commentController.text.isNotEmpty)
                  TextButton(
                    onPressed: () => _showNoteEditor(context),
                    child: const Text("EDIT"),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (commentController.text.isEmpty)
              OutlinedButton.icon(
                onPressed: () => _showNoteEditor(context),
                icon: const Icon(Icons.add),
                label: const Text("Add note..."),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              )
            else
              GestureDetector(
                onTap: () => _showNoteEditor(context),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.3,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: colorScheme.onSurface.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Text(
                    commentController.text,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontStyle: FontStyle.italic),
                  ),
                ),
              ),
          ],
        ),

        // 4. REMOVE BUTTON (If exists)
        if (existsInList) ...[
          const SizedBox(height: 32),
          TextButton.icon(
            onPressed: isSaving ? null : onRemove,
            icon: Icon(
              Icons.delete_outline,
              color: colorScheme.error,
              size: 20,
            ),
            label: Text(
              "REMOVE FROM LIBRARY",
              style: TextStyle(
                color: colorScheme.error,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ],
      ],
    );
  }

  void _showNoteEditor(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          _NoteEditorSheet(controller: commentController, onSave: onSave),
    );
  }
}

class _StarRating extends StatelessWidget {
  final double rating;
  final ValueChanged<double> onRatingChanged;
  final Color color;

  const _StarRating({
    required this.rating,
    required this.onRatingChanged,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final double starValue = (index + 1) * 2;
        IconData icon;
        if (rating >= starValue) {
          icon = Icons.star;
        } else if (rating >= starValue - 1) {
          icon = Icons.star_half;
        } else {
          icon = Icons.star_border;
        }

        return GestureDetector(
          onTapDown: (details) {
            final box = context.findRenderObject() as RenderBox;
            final double localX = details.localPosition.dx;
            final double starX = localX;
            final double starWidth = box.size.width / 5;

            // If tapped on left half of star, give half star
            double newRating = starValue;
            if (starX < starWidth / 2) {
              newRating -= 1;
            }
            onRatingChanged(newRating);
          },
          child: Icon(icon, color: color, size: 36),
        );
      }),
    );
  }
}

class _StatusSelector extends StatelessWidget {
  final String? currentStatus;
  final List<String> options;
  final ValueChanged<String?> onChanged;
  final bool isSaving;

  const _StatusSelector({
    required this.currentStatus,
    required this.options,
    required this.onChanged,
    required this.isSaving,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.secondary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.bookmark_outline, size: 20, color: colorScheme.secondary),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: currentStatus,
                hint: Text(
                  "ADD TO LIBRARY",
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.secondary.withValues(alpha: 0.7),
                  ),
                ),
                icon: Icon(Icons.arrow_drop_down),
                items: options
                    .map(
                      (s) => DropdownMenuItem(
                        value: s,
                        child: Text(
                          s.toUpperCase(),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: isSaving ? null : onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteEditorSheet extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSave;

  const _NoteEditorSheet({required this.controller, required this.onSave});

  @override
  State<_NoteEditorSheet> createState() => _NoteEditorSheetState();
}

class _NoteEditorSheetState extends State<_NoteEditorSheet> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "ADD PERSONAL NOTE",
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: widget.controller,
              autofocus: true,
              maxLines: 5,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: "Enter your thoughts about this manga...",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.3,
                ),
              ),
              onChanged: (val) {
                // Future use: character counter or disable save if empty
              },
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("CANCEL"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      widget.onSave();
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      "SAVE NOTE",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
