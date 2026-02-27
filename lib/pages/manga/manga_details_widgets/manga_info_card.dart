import 'package:flutter/material.dart';

class MangaInfoCard extends StatelessWidget {
  final Map<String, dynamic> details;

  const MangaInfoCard({Key? key, required this.details}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String avgScore = details['averageScore'] != null ? "${details['averageScore']}%" : "N/A";

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.onSurface.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          _buildRow(context, 'Average Score', avgScore),
          _buildRow(context, 'Status', details['status'] ?? '?'),
          _buildRow(context, 'Chapters', details['chapters']?.toString() ?? 'Ongoing'),
          _buildRow(context, 'Type', _getMediaType(details['countryOfOrigin'])),
          if (details['volumes'] != null)
             _buildRow(context, 'Volumes', details['volumes'].toString()),
          _buildRow(context, 'Released', _formatDate(details['startDate'])),
        ],
      ),
    );
  }

  Widget _buildRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              '$label:',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  String _getMediaType(String? countryCode) {
    switch (countryCode) {
      case 'KR': return 'Manhwa';
      case 'CN': return 'Manhua';
      case 'JP': return 'Manga';
      default: return 'Manga';
    }
  }

  String _formatDate(Map<String, dynamic>? dateData) {
    if (dateData == null || dateData['year'] == null) return '?';
    return '${dateData['year']}-${(dateData['month'] ?? 0).toString().padLeft(2, '0')}';
  }
}