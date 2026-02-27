import 'package:flutter/material.dart';

class SearchBar extends StatefulWidget {
  final ValueChanged<String> onChanged;
  final VoidCallback onFilterTap;
  final bool areFiltersActive;
  final String hintText;

  const SearchBar({
    Key? key,
    required this.onChanged,
    required this.onFilterTap,
    this.areFiltersActive = false,
    this.hintText = 'Search...',
  }) : super(key: key);

  @override
  State<SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<SearchBar> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fillColor = isDark ? Colors.grey[800]! : Colors.grey[100]!;

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            // Trigger the parent instantly. The parent handles debouncing.
            onChanged: widget.onChanged,
            style: theme.textTheme.bodyMedium,
            decoration: InputDecoration(
              hintText: widget.hintText,
              prefixIcon: Icon(Icons.search, color: theme.hintColor),
              filled: true,
              fillColor: fillColor,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              // ValueListenableBuilder isolates the rebuild to ONLY the icon
              suffixIcon: ValueListenableBuilder<TextEditingValue>(
                valueListenable: _controller,
                builder: (context, value, child) {
                  if (value.text.isEmpty) return const SizedBox.shrink();
                  return IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _controller.clear();
                      widget.onChanged('');
                      FocusScope.of(context).unfocus();
                    },
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          decoration: BoxDecoration(
            color:
                widget.areFiltersActive ? theme.colorScheme.primary : fillColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: Icon(
              Icons.tune,
              color: widget.areFiltersActive
                  ? theme.colorScheme.onPrimary
                  : Colors.grey[600],
            ),
            onPressed: widget.onFilterTap,
          ),
        ),
      ],
    );
  }
}
