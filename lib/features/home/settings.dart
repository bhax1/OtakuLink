import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:otakulink/core/providers/package_info_provider.dart';
import 'package:otakulink/core/providers/settings_provider.dart';
import 'package:otakulink/core/cache/local_cache_service.dart';
import 'package:otakulink/core/utils/app_snackbar.dart';
import 'package:otakulink/core/utils/validators.dart';
import 'package:otakulink/features/auth/data/auth_repository.dart';

class SettingPage extends ConsumerWidget {
  const SettingPage({super.key});

  // --- ACTIONS ---

  Future<void> _changePassword(BuildContext context, WidgetRef ref) async {
    String? newPassword = await _showInputDialog(
        context: context,
        title: 'Change Password',
        hint: 'Enter new password',
        isPassword: true);

    if (newPassword == null) return;

    final validationError = AppValidators.validatePassword(newPassword);

    if (validationError != null) {
      AppSnackBar.show(context, validationError, type: SnackBarType.warning);
      return;
    }

    _showLoading(context);
    final navigator = Navigator.of(context);

    try {
      await ref.read(authRepositoryProvider).updatePassword(newPassword);

      if (!context.mounted) return;
      navigator.pop(); // Pop loading dialog

      AppSnackBar.show(context, 'Password updated successfully!',
          type: SnackBarType.success);
    } catch (e) {
      if (!context.mounted) return;
      navigator.pop();
      AppSnackBar.show(context, e.toString(), type: SnackBarType.error);
    }
  }

  Future<void> _clearAppCache(BuildContext context) async {
    final theme = Theme.of(context);

    final int? choice = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Clear Image Cache'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 1),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text('Reading Pages (Frees most space)',
                  style: TextStyle(fontSize: 16)),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 2),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child:
                  Text('UI Covers & Banners', style: TextStyle(fontSize: 16)),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 3),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text('Clear All',
                  style:
                      TextStyle(color: theme.colorScheme.error, fontSize: 16)),
            ),
          ),
        ],
      ),
    );

    if (choice == null) return;

    _showLoading(context);
    final navigator = Navigator.of(context);

    try {
      if (choice == 1) {
        await LocalCacheService.clearPageCaches();
      } else if (choice == 2) {
        await LocalCacheService.clearCoverCaches();
      } else if (choice == 3) {
        await LocalCacheService.clearAllImageCaches();
      }

      if (!context.mounted) return;
      navigator.pop();

      AppSnackBar.show(context, 'Storage cleaned successfully!',
          type: SnackBarType.success);
    } catch (e) {
      if (!context.mounted) return;
      navigator.pop();
      AppSnackBar.show(context, 'Failed to clear cache.',
          type: SnackBarType.error);
    }
  }

  Future<void> _showImageQualityDialog(
      BuildContext context, WidgetRef ref, bool currentDataSaver) async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Image Quality'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<bool>(
                title: const Text('High Quality'),
                subtitle: const Text('Original resolution. Uses more data.'),
                value: false,
                groupValue: currentDataSaver,
                activeColor: colorScheme.secondary,
                onChanged: (val) => Navigator.pop(context, val),
              ),
              RadioListTile<bool>(
                title: const Text('Data Saver'),
                subtitle: const Text('Compressed images. Faster loading.'),
                value: true,
                groupValue: currentDataSaver,
                activeColor: colorScheme.secondary,
                onChanged: (val) => Navigator.pop(context, val),
              ),
            ],
          ),
        );
      },
    );

    if (result != null && result != currentDataSaver) {
      // Trigger Riverpod Notifier
      await ref.read(settingsProvider.notifier).updateDataSaver(result);

      if (context.mounted) {
        AppSnackBar.show(context, 'Image quality updated',
            type: SnackBarType.success);
      }
    }
  }

  // --- UI HELPERS ---

  Future<String?> _showInputDialog({
    required BuildContext context,
    required String title,
    required String hint,
    required bool isPassword,
  }) async {
    TextEditingController controller = TextEditingController();
    final theme = Theme.of(context);

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          obscureText: isPassword,
          decoration: InputDecoration(
            hintText: hint,
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: theme.colorScheme.primary),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: TextStyle(color: theme.colorScheme.error)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text('Save',
                style: TextStyle(color: theme.textTheme.titleMedium!.color)),
          ),
        ],
      ),
    );
  }

  void _showLoading(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: CircularProgressIndicator(
            color: Theme.of(context).colorScheme.primary),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Watch the global settings provider
    final settingsAsync = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) =>
            const Center(child: Text("Error loading settings")),
        data: (settings) {
          final isDarkMode = settings.themeMode == ThemeMode.dark;

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  Center(
                    child:
                        Image.asset('assets/logo/logo_flat2.png', height: 150),
                  ),
                  const SizedBox(height: 30),
                  _buildSectionHeader(context, 'Personalization'),
                  SwitchListTile(
                    title: const Text('Dark Mode'),
                    secondary: Icon(
                      isDarkMode ? Icons.dark_mode : Icons.light_mode,
                      color: colorScheme.secondary,
                    ),
                    value: isDarkMode,
                    onChanged: (value) {
                      // Instantly updates the UI and saves it
                      ref.read(settingsProvider.notifier).updateTheme(value);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.palette_outlined,
                        color: Colors.blueAccent),
                    title: const Text('Accent Color'),
                    subtitle: const Text('System Default'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {},
                  ),
                  const Divider(),
                  _buildSectionHeader(context, 'Content Filters'),
                  SwitchListTile(
                    title: const Text('Show 18+ Content'),
                    subtitle:
                        const Text('Include explicit results in searches'),
                    secondary: Icon(
                      settings.isNsfw ? Icons.visibility : Icons.visibility_off,
                      color: settings.isNsfw
                          ? colorScheme.error
                          : colorScheme.onSurfaceVariant,
                    ),
                    value: settings.isNsfw,
                    onChanged: (value) {
                      ref.read(settingsProvider.notifier).updateNsfw(value);
                    },
                  ),
                  const Divider(),
                  _buildSectionHeader(context, 'Account'),
                  ListTile(
                    leading: Icon(Icons.lock_outline,
                        color: colorScheme.onSurfaceVariant),
                    title: const Text('Change Password'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _changePassword(context, ref),
                  ),
                  const Divider(height: 30),
                  _buildSectionHeader(context, 'Notifications'),
                  ListTile(
                    leading: Icon(Icons.notifications_none,
                        color: colorScheme.error),
                    title: const Text('Notification Preferences'),
                    subtitle: const Text('Manage alerts for new chapters'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {},
                  ),
                  const Divider(),
                  _buildSectionHeader(context, 'Media & Storage'),
                  ListTile(
                    leading: Icon(Icons.high_quality,
                        color: colorScheme.onSurfaceVariant),
                    title: const Text('Image Quality'),
                    subtitle: Text(settings.isDataSaver
                        ? 'Data Saver (Compressed)'
                        : 'High Quality (Original)'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showImageQualityDialog(
                        context, ref, settings.isDataSaver),
                  ),
                  ListTile(
                    leading: const Icon(Icons.cleaning_services_outlined,
                        color: Colors.green),
                    title: const Text('Clear Image Cache'),
                    onTap: () => _clearAppCache(context),
                  ),
                  const Divider(),
                  _buildSectionHeader(context, 'Support'),
                  ListTile(
                    leading: const Icon(Icons.bug_report_outlined,
                        color: Colors.brown),
                    title: const Text('Report a Bug'),
                    onTap: () {},
                  ),
                  ref.watch(appVersionProvider).when(
                        data: (version) => ListTile(
                          leading: const Icon(Icons.info_outline,
                              color: Colors.grey),
                          title: const Text('Version'),
                          trailing: Text(version,
                              style: const TextStyle(color: Colors.grey)),
                        ),
                        loading: () => const ListTile(
                            title: Text('Version'),
                            trailing: CircularProgressIndicator()),
                        error: (_, __) => const ListTile(
                            title: Text('Version'), trailing: Text('1.0.0')),
                      ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Text(
          title.toUpperCase(),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
      ),
    );
  }
}
