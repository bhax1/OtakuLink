import 'package:flutter/material.dart';

class UserStatusEditor extends StatelessWidget {
  final double rating;
  final String status;
  final bool isFavorite;
  final bool isSaving;
  final bool existsInList;
  final String mangaStatus;
  final TextEditingController commentController;
  final ValueChanged<double> onRatingChanged;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<bool?> onFavoriteChanged;
  final VoidCallback onSave;

  const UserStatusEditor({
    Key? key,
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
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // --- LOGIC: SMART STATUS FILTER ---
    List<String> options = [
      'Not Yet',
      'Plan to Read',
      'Reading',
      'Completed',
      'On Hold',
      'Dropped'
    ];

    // Define which statuses allow "Completed"
    // FINISHED = Done.
    // CANCELLED = Done (abruptly).
    // ONESHOT = Done.
    final bool allowCompleted = ['FINISHED', 'CANCELLED', 'ONESHOT']
        .contains(mangaStatus.toUpperCase());

    // If NOT allowed, remove 'Completed'
    // Exception: Keep it if the user ALREADY has it set (legacy data protection)
    if (!allowCompleted && status != 'Completed') {
      options.remove('Completed');
    }

    // Format status for display (e.g. "RELEASING" -> "Releasing")
    String displayStatus = "Unknown";
    if (mangaStatus.isNotEmpty) {
      displayStatus = mangaStatus[0] + mangaStatus.substring(1).toLowerCase();
    }
    if (mangaStatus == 'NOT_YET_RELEASED') displayStatus = "Not Yet Released";

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.onSurface.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        children: [
          // Rating Slider
          Row(
            children: [
              Text(
                "Score: ${rating.toStringAsFixed(1)}",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Expanded(
                child: Slider(
                  value: rating,
                  min: 0,
                  max: 10,
                  divisions: 20,
                  activeColor: colorScheme.secondary,
                  onChanged: onRatingChanged,
                ),
              ),
            ],
          ),

          // Status Dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: colorScheme.onSurface.withOpacity(0.2)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                dropdownColor: colorScheme.surface,
                value: status,
                items: options
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: onStatusChanged,
              ),
            ),
          ),

          // --- SMART HELPER TEXT ---
          // Shows why "Completed" is missing
          if (!allowCompleted && status != 'Completed')
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 12, color: theme.colorScheme.error),
                  const SizedBox(width: 4),
                  Text(
                    "Cannot mark as Completed (Series is $displayStatus)",
                    style:
                        TextStyle(fontSize: 11, color: theme.colorScheme.error),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 10),

          // Favorite Checkbox
          CheckboxListTile(
            title: const Text("Add to Favorites"),
            value: isFavorite,
            activeColor: colorScheme.primary,
            contentPadding: EdgeInsets.zero,
            onChanged: onFavoriteChanged,
          ),
          const SizedBox(height: 10),

          // Comment Field
          TextField(
            controller: commentController,
            maxLines: 3,
            maxLength: 500,
            decoration: const InputDecoration(labelText: 'Personal Notes'),
          ),
          const SizedBox(height: 20),

          // Save Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: isSaving ? null : onSave,
              child: isSaving
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          color: colorScheme.onPrimary, strokeWidth: 2),
                    )
                  : Text(
                      existsInList ? 'UPDATE' : 'ADD TO LIBRARY',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
