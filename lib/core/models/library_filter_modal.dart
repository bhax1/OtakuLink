import 'package:flutter/material.dart';

class LibraryFilterSettings {
  final String sortBy; // 'Date', 'Title', 'Rating'
  final bool ascending;
  final bool favoritesOnly;
  final String? status; // 'Reading', 'Completed', etc.

  LibraryFilterSettings({
    this.sortBy = 'Date',
    this.ascending = false,
    this.favoritesOnly = false,
    this.status,
  });

  LibraryFilterSettings copyWith({
    String? sortBy,
    bool? ascending,
    bool? favoritesOnly,
    String? status,
  }) {
    return LibraryFilterSettings(
      sortBy: sortBy ?? this.sortBy,
      ascending: ascending ?? this.ascending,
      favoritesOnly: favoritesOnly ?? this.favoritesOnly,
      // Pass null to clear
      status: status,
    );
  }
}

class LibraryFilterModal extends StatefulWidget {
  final LibraryFilterSettings currentSettings;
  const LibraryFilterModal({Key? key, required this.currentSettings})
      : super(key: key);

  @override
  State<LibraryFilterModal> createState() => _LibraryFilterModalState();
}

class _LibraryFilterModalState extends State<LibraryFilterModal> {
  late LibraryFilterSettings _settings;
  final List<String> _statuses = [
    'Reading',
    'Completed',
    'Plan to Read',
    'On Hold',
    'Dropped'
  ];

  @override
  void initState() {
    super.initState();
    _settings = widget.currentSettings;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Library Filters",
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              TextButton(
                onPressed: () =>
                    setState(() => _settings = LibraryFilterSettings()),
                child: Text("Reset",
                    style: TextStyle(color: theme.colorScheme.error)),
              ),
            ],
          ),
          const Divider(),
          const SizedBox(height: 10),
          Text("Sort By",
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Wrap(
                spacing: 8,
                children: ['Date', 'Rating', 'Title'].map((sort) {
                  final isSelected = _settings.sortBy == sort;
                  return ChoiceChip(
                    label: Text(sort),
                    selected: isSelected,
                    onSelected: (val) {
                      if (val)
                        setState(
                            () => _settings = _settings.copyWith(sortBy: sort));
                    },
                  );
                }).toList(),
              ),
              IconButton(
                icon: Icon(_settings.ascending
                    ? Icons.arrow_upward
                    : Icons.arrow_downward),
                onPressed: () => setState(() => _settings =
                    _settings.copyWith(ascending: !_settings.ascending)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text("Filter By Status",
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text("All"),
                selected: _settings.status == null,
                onSelected: (val) {
                  if (val)
                    setState(() {
                      _settings = LibraryFilterSettings(
                          sortBy: _settings.sortBy,
                          ascending: _settings.ascending,
                          favoritesOnly: _settings.favoritesOnly,
                          status: null);
                    });
                },
              ),
              ..._statuses.map((status) {
                return ChoiceChip(
                  label: Text(status),
                  selected: _settings.status == status,
                  onSelected: (val) {
                    if (val)
                      setState(
                          () => _settings = _settings.copyWith(status: status));
                  },
                );
              }),
            ],
          ),
          const SizedBox(height: 20),
          SwitchListTile(
            title: const Text("Favorites Only"),
            secondary: const Icon(Icons.favorite, color: Colors.redAccent),
            contentPadding: EdgeInsets.zero,
            value: _settings.favoritesOnly,
            onChanged: (val) => setState(
                () => _settings = _settings.copyWith(favoritesOnly: val)),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(context, _settings),
              child: const Text("Apply",
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
