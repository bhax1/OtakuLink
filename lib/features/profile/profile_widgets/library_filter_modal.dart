import 'package:flutter/material.dart';
import 'package:otakulink/features/profile/domain/entities/library_filter_settings.dart';

class LibraryFilterModal extends StatefulWidget {
  final LibraryFilterSettings currentSettings;

  const LibraryFilterModal({super.key, required this.currentSettings});

  @override
  State<LibraryFilterModal> createState() => _LibraryFilterModalState();
}

class _LibraryFilterModalState extends State<LibraryFilterModal> {
  late LibraryFilterSettings _tempSettings;

  @override
  void initState() {
    super.initState();
    _tempSettings = widget.currentSettings;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statuses = [
      'All',
      'Reading',
      'Completed',
      'On Hold',
      'Dropped',
      'Plan to Read',
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Filter Library",
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () =>
                    Navigator.pop(context, LibraryFilterSettings()),
                child: const Text("Reset"),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text("Status", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: statuses.map((status) {
              final isSelected =
                  (status == 'All' && _tempSettings.status == null) ||
                  status == _tempSettings.status;
              return FilterChip(
                label: Text(status),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    _tempSettings = _tempSettings.copyWith(
                      status: status == 'All' ? null : status,
                    );
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          SwitchListTile(
            title: const Text("Favorites Only"),
            value: _tempSettings.favoritesOnly,
            contentPadding: EdgeInsets.zero,
            onChanged: (val) => setState(
              () => _tempSettings = _tempSettings.copyWith(favoritesOnly: val),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.pop(context, _tempSettings),
              child: const Text("Apply Filters"),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
