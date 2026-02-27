import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:otakulink/pages/reader/providers/reading_mode_provider.dart';

class ReadingModesModal extends ConsumerWidget {
  const ReadingModesModal({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentMode = ref.watch(readingModeProvider);
    final notifier = ref.read(readingModeProvider.notifier);

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              "Reading Mode",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
          ),
          _buildOption(
            context: context,
            title: "Long Strip (Webtoon)",
            icon: Icons.view_day,
            isSelected: currentMode == ReadingMode.vertical,
            onTap: () {
              notifier.setMode(ReadingMode.vertical);
              Navigator.pop(context);
            },
          ),
          _buildOption(
            context: context,
            title: "Left to Right (Comic)",
            icon: Icons.arrow_forward,
            isSelected: currentMode == ReadingMode.horizontalLTR,
            onTap: () {
              notifier.setMode(ReadingMode.horizontalLTR);
              Navigator.pop(context);
            },
          ),
          _buildOption(
            context: context,
            title: "Right to Left (Manga)",
            icon: Icons.arrow_back,
            isSelected: currentMode == ReadingMode.horizontalRTL,
            onTap: () {
              notifier.setMode(ReadingMode.horizontalRTL);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOption({
    required BuildContext context,
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: isSelected ? Colors.orange : Colors.white),
      title: Text(title,
          style: TextStyle(color: isSelected ? Colors.orange : Colors.white)),
      trailing: isSelected
          ? const Icon(Icons.check_circle, color: Colors.orange)
          : null,
      onTap: onTap,
    );
  }
}
