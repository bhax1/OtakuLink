import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:otakulink/features/settings/providers/settings_provider.dart';
import 'package:otakulink/core/constants/app_constants.dart';
import 'package:otakulink/core/utils/app_snackbar.dart';
import 'package:otakulink/core/services/local_cache_service.dart';
import 'package:otakulink/core/utils/secure_logger.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:otakulink/routes/app_router.dart';
import 'package:otakulink/core/services/audit_service.dart';

class SettingPage extends ConsumerWidget {
  const SettingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Center(
                child: Image.asset('assets/logo/logo_flat2.png', height: 150),
              ),
              const SizedBox(height: 30),
              _buildSectionHeader(context, 'Personalization'),
              SwitchListTile(
                title: const Text('Dark Mode'),
                secondary: Icon(Icons.light_mode, color: colorScheme.secondary),
                value: settings.themeMode == ThemeMode.dark,
                onChanged: (value) {
                  ref
                      .read(settingsProvider.notifier)
                      .setThemeMode(value ? ThemeMode.dark : ThemeMode.light);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.palette_outlined,
                  color: Colors.blueAccent,
                ),
                title: const Text('Accent Color'),
                subtitle: const Text('System Default'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {},
              ),
              const Divider(),
              _buildSectionHeader(context, 'Content Filters'),
              SwitchListTile(
                title: const Text('Show 18+ Content'),
                subtitle: const Text('Include explicit results in searches'),
                secondary: Icon(
                  Icons.visibility_off,
                  color: colorScheme.onSurfaceVariant,
                ),
                value: settings.showAdultContent,
                onChanged: (value) {
                  ref.read(settingsProvider.notifier).toggleAdultContent(value);
                  AppSnackBar.show(
                    context,
                    value ? 'Adult content enabled.' : 'Adult content hidden.',
                  );
                },
              ),
              const Divider(),
              _buildSectionHeader(context, 'Account'),
              ListTile(
                leading: Icon(
                  Icons.lock_outline,
                  color: colorScheme.onSurfaceVariant,
                ),
                title: const Text('Change Password'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {}, // Functionality removed
              ),
              const Divider(height: 30),
              _buildSectionHeader(context, 'Notifications'),
              ListTile(
                leading: Icon(
                  Icons.notifications_none,
                  color: colorScheme.error,
                ),
                title: const Text('Notification Preferences'),
                subtitle: const Text('Manage alerts for new chapters'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {},
              ),
              const Divider(),
              _buildSectionHeader(context, 'Media & Storage'),
              ListTile(
                leading: const Icon(
                  Icons.cleaning_services_outlined,
                  color: Colors.green,
                ),
                title: const Text('Clear Cache'),
                onTap: () async {
                  // Show loading
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (c) =>
                        const Center(child: CircularProgressIndicator()),
                  );

                  try {
                    await DefaultCacheManager().emptyCache();
                    await LocalCacheService.clearAllCache();

                    ref
                        .read(auditServiceProvider)
                        .logAction(action: 'clear_cache');

                    // Also reload settings in case they were cached or we need a clean start
                    ref.invalidate(settingsProvider);

                    if (context.mounted) {
                      Navigator.pop(context); // hide loading
                      AppSnackBar.show(
                        context,
                        'Cache cleared successfully!',
                        type: SnackBarType.success,
                      );
                    }
                  } catch (e, stack) {
                    SecureLogger.logError("SettingPage clearCache", e, stack);
                    if (context.mounted) {
                      Navigator.pop(context); // hide loading
                      AppSnackBar.show(
                        context,
                        'Failed to clear cache.',
                        type: SnackBarType.error,
                      );
                    }
                  }
                },
              ),
              const Divider(),
              _buildSectionHeader(context, 'Legal & Privacy'),
              ListTile(
                leading: Icon(
                  Icons.privacy_tip_outlined,
                  color: colorScheme.onSurfaceVariant,
                ),
                title: const Text('Privacy Policy'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  ref.read(appRouterProvider).pushNamed('privacy-policy');
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.description_outlined,
                  color: colorScheme.onSurfaceVariant,
                ),
                title: const Text('Terms of Service'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  ref.read(appRouterProvider).pushNamed('terms-of-service');
                },
              ),
              const Divider(),
              _buildSectionHeader(context, 'Support'),
              ListTile(
                leading: const Icon(
                  Icons.bug_report_outlined,
                  color: Colors.brown,
                ),
                title: const Text('Report a Bug'),
                onTap: () async {
                  final emailUrl = Uri.parse(
                    'mailto:${AppConstants.contactEmail}?subject=OtakuLink%20Bug%20Report&body=App%20Version:%20${AppConstants.version}%0D%0A%0D%0APlease%20describe%20the%20bug%20below:%0D%0A',
                  );
                  if (await canLaunchUrl(emailUrl)) {
                    await launchUrl(emailUrl);
                  } else {
                    if (context.mounted) {
                      AppSnackBar.show(
                        context,
                        'Could not open email client.',
                        type: SnackBarType.warning,
                      );
                    }
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.info_outline, color: Colors.grey),
                title: const Text('Version'),
                trailing: Text(
                  AppConstants.version,
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
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
