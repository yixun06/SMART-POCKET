import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';

import '../../../application/controllers/authentication_controller.dart';
import '../../../application/controllers/budget_controller.dart';
import '../../../application/controllers/config_controller.dart';
import '../../../application/controllers/settings_controller.dart';
import '../../../application/controllers/theme_controller.dart';
import '../../widgets/navigation/bottom_nav_bar.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _biometricEnabled = false;
  bool _biometricLoaded = false;

  String get _email => context.read<SettingsController>().email;
  String get _name => context.read<SettingsController>().displayName;

  String _modeText(ConfigController cfg) {
    final mode = cfg.appMode.toLowerCase();
    return mode == 'detailed' ? 'Detailed' : 'Lazy';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_biometricLoaded) return;
    _biometricLoaded = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final enabled = await context
          .read<AuthenticationController>()
          .isBiometricEnabled();
      if (!mounted) return;
      setState(() => _biometricEnabled = enabled);
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthenticationController>();
    final cfg = context.watch<ConfigController>();
    final themeCtrl = context.watch<ThemeController>();
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          TextButton(
            onPressed: () => context.go('/dashboard'),
            child: const Text('Back'),
          ),
        ],
      ),
      body: AppAdaptiveBody(
        currentIndex: 3,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
          children: [
            _profileCard(_modeText(cfg)),
            const SizedBox(height: 14),
            _section(
              title: 'Account Settings',
              children: [
                _navTile(
                  icon: CupertinoIcons.mail,
                  title: 'Change Email',
                  onTap: _openChangeEmailDialog,
                ),
                _navTile(
                  icon: CupertinoIcons.lock,
                  title: 'Change Password',
                  onTap: _openChangePasswordDialog,
                ),
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 3,
                  ),
                  secondary: _settingsIcon(CupertinoIcons.lock_shield),
                  title: const Text('Biometric Authentication'),
                  subtitle: const Text(
                    'Require fingerprint or face unlock when reopening the app.',
                  ),
                  value: _biometricEnabled,
                  onChanged: (auth.isLoading)
                      ? null
                      : (value) async {
                          final messenger = ScaffoldMessenger.of(context);
                          await auth.setBiometricEnabled(value);
                          if (!mounted) return;
                          setState(() => _biometricEnabled = value);
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                value
                                    ? 'Biometric authentication enabled'
                                    : 'Biometric authentication disabled',
                              ),
                            ),
                          );
                        },
                ),
              ],
            ),
            const SizedBox(height: 20),
            _section(
              title: 'Customize Settings',
              children: [
                _navTile(
                  icon: CupertinoIcons.square_grid_2x2,
                  title: 'Manage Categories',
                  onTap: () => context.push('/categories'),
                ),
                _navTile(
                  icon: CupertinoIcons.creditcard,
                  title: 'Monthly Budget',
                  onTap: _openBudgetEditor,
                ),
                _navTile(
                  icon: CupertinoIcons.repeat,
                  title: 'Recurring Transactions',
                  onTap: () => context.push('/recurring'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _section(
              title: 'App Settings',
              children: [
                _modeTile(cfg),
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 3,
                  ),
                  secondary: _settingsIcon(CupertinoIcons.moon),
                  title: const Text('Dark Mode'),
                  subtitle: Text(
                    themeCtrl.isDarkMode
                        ? 'Dark appearance is currently enabled.'
                        : 'Switch the app to a darker appearance.',
                  ),
                  value: themeCtrl.isDarkMode,
                  onChanged: themeCtrl.isLoading ? null : themeCtrl.setDarkMode,
                ),
              ],
            ),
            const SizedBox(height: 20),
            _section(
              title: 'Backup & Sync',
              children: [
                _navTile(
                  icon: CupertinoIcons.cloud_upload,
                  title: 'Cloud Backup Now',
                  onTap: _createCloudBackupNow,
                ),
                _navTile(
                  icon: CupertinoIcons.arrow_down_doc,
                  title: 'Export JSON Backup',
                  onTap: _exportJsonBackup,
                ),
                _navTile(
                  icon: CupertinoIcons.cloud_download,
                  title: 'Restore Latest Cloud Backup',
                  onTap: _restoreLatestCloudBackup,
                ),
                _navTile(
                  icon: CupertinoIcons.arrow_up_doc,
                  title: 'Restore From JSON File',
                  onTap: _restoreFromJsonFile,
                ),
              ],
            ),
            const SizedBox(height: 20),
            _section(
              title: 'Account actions',
              children: [
                _navTile(
                  icon: CupertinoIcons.delete,
                  title: 'Reset All Data',
                  onTap: _confirmResetAllData,
                  danger: true,
                ),
                _navTile(
                  icon: CupertinoIcons.square_arrow_right,
                  title: 'Logout',
                  onTap: () async {
                    final router = GoRouter.of(context);
                    final messenger = ScaffoldMessenger.of(context);
                    final ok = await auth.logout();
                    if (!mounted) return;
                    if (ok) {
                      router.go('/login');
                    } else {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(auth.errorMessage ?? 'Logout failed'),
                        ),
                      );
                    }
                  },
                  danger: false,
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: 3,
        onTap: (i) {
          if (i == 0) context.go('/dashboard');
          if (i == 1) context.go('/accounts');
          if (i == 2) context.go('/stats');
          if (i == 3) context.go('/settings');
        },
        onAddTap: () => context.push('/add-transaction'),
      ),
    );
  }

  Widget _profileCard(String modeText) {
    final colors = Theme.of(context).colorScheme;
    final displayName = _name.trim().isEmpty ? 'Your profile' : _name.trim();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.65),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: colors.primaryContainer,
            child: Text(
              _name.trim().isNotEmpty ? _name.trim()[0].toUpperCase() : 'U',
              style: TextStyle(
                color: colors.onPrimaryContainer,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colors.onSurface,
                  ),
                ),
                if (_email.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    _email,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$modeText mode',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: colors.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: _openEditProfileDialog,
            tooltip: 'Edit profile',
            icon: Icon(
              CupertinoIcons.pencil,
              color: colors.onSurfaceVariant,
              size: 19,
            ),
          ),
        ],
      ),
    );
  }

  Widget _section({required String title, required List<Widget> children}) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 10, 4, 10),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: colors.outlineVariant.withValues(alpha: 0.65),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    indent: 64,
                    endIndent: 16,
                    color: colors.outlineVariant.withValues(alpha: 0.55),
                  ),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _settingsIcon(IconData icon, {bool danger = false}) {
    final colors = Theme.of(context).colorScheme;
    final foreground = danger ? colors.error : colors.primary;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: danger
            ? colors.errorContainer.withValues(alpha: 0.65)
            : colors.primaryContainer.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, size: 20, color: foreground),
    );
  }

  Widget _navTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool danger = false,
    String? subtitle,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 68),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _settingsIcon(icon, danger: danger),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: danger ? colors.error : colors.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  CupertinoIcons.chevron_right,
                  size: 16,
                  color: colors.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _modeTile(ConfigController cfg) => _navTile(
    icon: CupertinoIcons.slider_horizontal_3,
    title: 'Operating Mode',
    subtitle: _modeText(cfg),
    onTap: () async {
      await context.push('/mode');
      if (!mounted) return;
      await context.read<ConfigController>().loadCurrentMode();
      setState(() {});
    },
  );

  Future<void> _openBudgetEditor() async {
    final ctrl = context.read<BudgetController>();
    final c = TextEditingController(
      text: ctrl.monthlyBudget == 0
          ? ''
          : ctrl.monthlyBudget.toStringAsFixed(2),
    );

    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Monthly Budget'),
        content: TextField(
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Amount (RM)',
            hintText: 'e.g. 2500',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dCtx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await ctrl.saveBudget(c.text.trim());
    } catch (_) {
      try {
        await ctrl.setBudget(c.text.trim());
      } catch (_) {
        try {
          await ctrl.updateBudget(c.text.trim());
        } catch (_) {}
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ctrl.errorMessage ?? 'Budget saved')),
    );
  }

  Future<void> _confirmResetAllData() async {
    final settings = context.read<SettingsController>();
    final yes = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Reset all data?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dCtx, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (yes != true) return;

    try {
      await settings.resetAllDataWithBackup();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'All user data reset completed. A cloud backup was created before reset and can be restored anytime.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reset stopped because backup/reset failed: $e'),
        ),
      );
    }
  }

  Future<void> _createCloudBackupNow() async {
    final settings = context.read<SettingsController>();
    try {
      final preview = await settings.buildBackupPreview();
      if (!mounted) return;
      final lastBackupText = preview.lastBackupAt == null
          ? 'Never'
          : DateFormat('yyyy-MM-dd HH:mm').format(preview.lastBackupAt!);

      final yes = await showDialog<bool>(
        context: context,
        builder: (dCtx) => AlertDialog(
          title: const Text('Update Cloud Backup?'),
          content: Text(
            'Last backup: $lastBackupText\n\nDo you want to overwrite with a new backup now?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dCtx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dCtx, true),
              child: const Text('Update Backup'),
            ),
          ],
        ),
      );
      if (yes != true) return;

      await settings.createCloudBackup();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Cloud backup completed')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Cloud backup failed: $e')));
    }
  }

  Future<void> _exportJsonBackup() async {
    final settings = context.read<SettingsController>();
    try {
      final preview = await settings.buildBackupPreview();
      if (!mounted) return;

      final backupTime = preview.lastBackupAt == null
          ? 'Never'
          : DateFormat('yyyy-MM-dd HH:mm').format(preview.lastBackupAt!);
      final proceed = await showDialog<bool>(
        context: context,
        builder: (dCtx) => AlertDialog(
          title: const Text('Backup Preview'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Accounts: ${preview.accountCount}'),
              Text('Transactions: ${preview.transactionCount}'),
              Text('Last backup: $backupTime'),
              const SizedBox(height: 10),
              const Text(
                'This backup file may contain sensitive financial information.',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dCtx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dCtx, true),
              child: const Text('Export'),
            ),
          ],
        ),
      );
      if (proceed != true) return;

      final json = await settings.exportBackupJson();
      final dir = await getTemporaryDirectory();
      final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final file = File('${dir.path}/smart_pocket_backup_$stamp.json');
      await file.writeAsString(json);

      await Share.shareXFiles([
        XFile(file.path),
      ], text: 'Smart Pocket backup ($stamp)');

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Backup JSON exported')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  Future<void> _restoreLatestCloudBackup() async {
    final settings = context.read<SettingsController>();
    final config = context.read<ConfigController>();
    final yes = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Restore Latest Cloud Backup?'),
        content: const Text(
          'Current data will be replaced by latest cloud backup. Lazy balances will be re-aggregated automatically after restore.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dCtx, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (yes != true) return;

    try {
      await settings.restoreLatestCloudBackup();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Restore completed')));
      await config.loadCurrentMode();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Restore failed: $e')));
    }
  }

  Future<void> _restoreFromJsonFile() async {
    final settings = context.read<SettingsController>();
    final config = context.read<ConfigController>();
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
      withData: false,
    );
    if (picked == null || picked.files.isEmpty) return;
    final path = picked.files.single.path;
    if (path == null || path.trim().isEmpty) return;
    if (!mounted) return;

    final yes = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Restore From JSON Backup?'),
        content: const Text(
          'Current data will be replaced by selected backup file. Lazy balances will be re-aggregated automatically after restore.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dCtx, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (yes != true) return;

    try {
      final jsonText = await File(path).readAsString();
      await settings.restoreFromBackupJson(jsonText);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('JSON restore completed')));
      await config.loadCurrentMode();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('JSON restore failed: $e')));
    }
  }

  Future<void> _openChangeEmailDialog() async {
    final auth = context.read<AuthenticationController>();
    final emailCtrl = TextEditingController();
    final currentPwdCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.alternate_email_rounded,
              color: Theme.of(dCtx).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            const Text('Change Email'),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'A verification link will be sent to your new email address.',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(dCtx).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: emailCtrl,
                decoration: const InputDecoration(labelText: 'New Email'),
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  final t = (v ?? '').trim();
                  if (t.isEmpty || !t.contains('@')) {
                    return 'Enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: currentPwdCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Current Password',
                ),
                validator: (v) =>
                    (v ?? '').isEmpty ? 'Current password required' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(dCtx, true);
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final changed = await auth.changeEmail(
      newEmail: emailCtrl.text.trim(),
      currentPassword: currentPwdCtrl.text,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          changed
              ? 'Verification email sent to new address. Please verify to complete email change.'
              : (auth.errorMessage ?? 'Failed to change email'),
        ),
      ),
    );
  }

  Future<void> _openChangePasswordDialog() async {
    final auth = context.read<AuthenticationController>();
    final currentPwdCtrl = TextEditingController();
    final newPwdCtrl = TextEditingController();
    final confirmPwdCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.lock_reset_rounded,
              color: Theme.of(dCtx).colorScheme.secondary,
            ),
            const SizedBox(width: 8),
            const Text('Change Password'),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Use at least 8 characters with letters and numbers.',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(dCtx).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: currentPwdCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Current Password',
                ),
                validator: (v) =>
                    (v ?? '').isEmpty ? 'Current password required' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: newPwdCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New Password'),
                validator: (v) =>
                    (v ?? '').isEmpty ? 'New password required' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: confirmPwdCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm New Password',
                ),
                validator: (v) {
                  if ((v ?? '').isEmpty) return 'Please confirm password';
                  if (v != newPwdCtrl.text) return 'Passwords do not match';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(dCtx, true);
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final changed = await auth.changePassword(
      currentPassword: currentPwdCtrl.text,
      newPassword: newPwdCtrl.text,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          changed
              ? 'Password updated successfully'
              : (auth.errorMessage ?? 'Failed to change password'),
        ),
      ),
    );
  }

  Future<void> _openEditProfileDialog() async {
    final auth = context.read<AuthenticationController>();
    final nameCtrl = TextEditingController(text: _name);
    final formKey = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Edit Profile'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: nameCtrl,
            decoration: const InputDecoration(labelText: 'Display Name'),
            validator: (v) =>
                (v ?? '').trim().isEmpty ? 'Display name is required' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(dCtx, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final updated = await auth.updateDisplayName(nameCtrl.text.trim());
    if (!mounted) return;
    if (updated) {
      setState(() {});
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile updated')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ?? 'Failed to update profile'),
        ),
      );
    }
  }
}
