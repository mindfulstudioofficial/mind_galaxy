import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hive/hive.dart';
import 'package:mindgalaxy/l10n/app_localizations.dart';
import 'package:mindgalaxy/models/thought.dart';
import 'package:mindgalaxy/services/auth_service.dart';
import 'package:mindgalaxy/services/app_settings.dart';
import 'package:mindgalaxy/services/backup_service.dart';
import 'package:mindgalaxy/utils/responsive_layout.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _authProvider = '';
  String _authDisplayName = '';
  bool _authBusy = false;
  String _activeSignInProvider = '';

  @override
  void initState() {
    super.initState();
    _loadAuthState();
  }

  Future<void> _loadAuthState() async {
    await AuthService.syncAuthState();
    if (!mounted) return;
    setState(() {
      _authProvider = AppSettings.authProvider;
      _authDisplayName = AppSettings.authDisplayName;
    });
  }

  Future<void> _signIn(String provider) async {
    final loc = AppLocalizations.of(context)!;
    if (_authBusy) return;
    setState(() {
      _authBusy = true;
      _activeSignInProvider = provider;
    });

    final result = provider == 'google'
        ? await AuthService.signInWithGoogle()
        : await AuthService.signInWithApple();
    await _loadAuthState();
    if (!mounted) return;
    setState(() {
      _authBusy = false;
      _activeSignInProvider = '';
    });

    final message = switch (result.type) {
      AuthResultType.success => loc.loginSuccessSnack,
      AuthResultType.cancelled => loc.loginCancelledSnack,
      AuthResultType.setupRequired => loc.loginSetupRequiredSnack,
      AuthResultType.unsupported => loc.loginUnsupportedSnack,
      AuthResultType.failed => loc.loginFailedSnack,
    };
    if (result.type != AuthResultType.success && result.details != null) {
      debugPrint('Sign-in failure[$provider]: ${result.details}');
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _signOut() async {
    final loc = AppLocalizations.of(context)!;
    if (_authBusy) return;
    setState(() => _authBusy = true);
    final result = await AuthService.signOut();
    await _loadAuthState();
    if (!mounted) return;
    setState(() => _authBusy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.type == AuthResultType.success
              ? loc.logoutSuccessSnack
              : loc.loginFailedSnack,
        ),
      ),
    );
  }

  bool _backupBusy = false;

  Future<void> _exportData() async {
    final loc = AppLocalizations.of(context)!;
    if (_backupBusy) return;

    final box = Hive.box<Thought>('thoughts');
    if (box.isEmpty) {
      _showSnack(loc.exportEmptySnack);
      return;
    }

    setState(() => _backupBusy = true);
    try {
      await BackupService.shareBackupFile();
      if (!mounted) return;
      _showSnack(loc.exportSuccessSnack);
    } catch (e) {
      debugPrint('[Settings] Export failed: $e');
    } finally {
      if (mounted) setState(() => _backupBusy = false);
    }
  }

  Future<void> _importData() async {
    final loc = AppLocalizations.of(context)!;
    if (_backupBusy) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: false,
      withReadStream: false,
    );
    if (result == null || result.files.isEmpty) {
      if (mounted) _showSnack(loc.importCancelledSnack);
      return;
    }

    final filePath = result.files.single.path;
    if (filePath == null) {
      if (mounted) _showSnack(loc.importCancelledSnack);
      return;
    }

    final jsonString = await File(filePath).readAsString();

    final List<Thought> parsed;
    try {
      parsed = BackupService.parseAndValidate(jsonString);
    } on FormatException catch (e) {
      if (mounted) _showSnack(loc.importFailedSnack(e.message));
      return;
    }

    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0E1320),
        title: Text(loc.importConfirmTitle),
        content: Text(
          '${loc.importConfirmMessage}\n\n'
          '${loc.starsCount(parsed.length)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(loc.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade700,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(loc.importConfirmButton),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _backupBusy = true);
    try {
      final count = await BackupService.importAndReplace(jsonString);
      if (!mounted) return;
      _showSnack(loc.importSuccessSnack(count));
    } on FormatException catch (e) {
      if (mounted) _showSnack(loc.importFailedSnack(e.message));
    } catch (e) {
      debugPrint('[Settings] Import failed: $e');
      if (mounted) _showSnack(loc.importFailedSnack(e.toString()));
    } finally {
      if (mounted) setState(() => _backupBusy = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _providerLabel(AppLocalizations loc) {
    switch (_authProvider) {
      case 'google':
        return 'Google';
      case 'apple':
        return 'Apple';
      default:
        return loc.preparing;
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final textColor = Colors.white.withValues(alpha: 0.92);
    final isLoggedIn = _authProvider.isNotEmpty;
    final accountSubtitle = isLoggedIn
        ? loc.loginStatusWithProvider(_authDisplayName, _providerLabel(loc))
        : loc.guestModeStatus;

    return Scaffold(
      backgroundColor: const Color(0xFF04060D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          loc.settingsTitle,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w500,
            letterSpacing: 1.6,
          ),
        ),
      ),
      body: ResponsiveContentWidth(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 16),
        child: ListView(
        padding: EdgeInsets.zero,
        children: [
          ListTile(
            leading: Icon(
              Icons.folder_open,
              color: textColor.withValues(alpha: 0.7),
            ),
            title: Text(
              loc.dataManagementTitle,
              style: TextStyle(
                color: textColor.withValues(alpha: 0.85),
                letterSpacing: 1.1,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              loc.dataManagementIntro,
              style: TextStyle(
                color: textColor.withValues(alpha: 0.62),
                height: 1.4,
                fontSize: 13,
              ),
            ),
          ),
          ListTile(
            enabled: !_backupBusy,
            leading: Icon(
              Icons.upload_file,
              color: textColor.withValues(alpha: 0.65),
            ),
            title: Text(
              loc.exportDataTitle,
              style: TextStyle(color: textColor.withValues(alpha: 0.82)),
            ),
            subtitle: Text(
              loc.exportDataSubtitle,
              style: TextStyle(color: textColor.withValues(alpha: 0.55)),
            ),
            onTap: _exportData,
          ),
          ListTile(
            enabled: !_backupBusy,
            leading: Icon(
              Icons.download,
              color: textColor.withValues(alpha: 0.65),
            ),
            title: Text(
              loc.importDataTitle,
              style: TextStyle(color: textColor.withValues(alpha: 0.82)),
            ),
            subtitle: Text(
              loc.importDataSubtitle,
              style: TextStyle(color: textColor.withValues(alpha: 0.55)),
            ),
            onTap: _importData,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              loc.importWarningNote,
              style: TextStyle(
                color: Colors.orange.withValues(alpha: 0.6),
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Divider(color: Colors.white.withValues(alpha: 0.08)),
          ListTile(
            leading: Icon(
              isLoggedIn ? Icons.verified_user : Icons.cloud_sync,
              color: textColor.withValues(alpha: isLoggedIn ? 0.8 : 0.55),
            ),
            title: Text(
              loc.accountSyncTitle,
              style: TextStyle(
                color: textColor.withValues(alpha: 0.75),
                letterSpacing: 1.1,
              ),
            ),
            subtitle: Text(
              accountSubtitle,
              style: TextStyle(color: textColor.withValues(alpha: 0.55)),
            ),
          ),
          if (!isLoggedIn) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                loc.loginOptionalDescription,
                style: TextStyle(color: textColor.withValues(alpha: 0.48)),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.02),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 18,
                      color: textColor.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        loc.loginBenefitSummary,
                        style: TextStyle(
                          color: textColor.withValues(alpha: 0.52),
                          height: 1.35,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _signIn('google'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _activeSignInProvider == 'google'
                            ? const Color(0xFF111624)
                            : null,
                      ),
                      icon: const _GoogleLogoIcon(size: 20),
                      label: Text(loc.loginWithGoogle),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _signIn('apple'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _activeSignInProvider == 'apple'
                            ? const Color(0xFF111624)
                            : null,
                      ),
                      icon: const Icon(Icons.apple),
                      label: Text(loc.loginWithApple),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _authBusy ? null : _signOut,
                  icon: const Icon(Icons.logout),
                  label: Text(loc.logoutButton),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                loc.loginConnectedHint,
                style: TextStyle(color: textColor.withValues(alpha: 0.45)),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Divider(color: Colors.white.withValues(alpha: 0.08)),
          ListTile(
            enabled: false,
            leading: Icon(
              Icons.workspace_premium,
              color: textColor.withValues(alpha: 0.38),
            ),
            title: Text(
              loc.premiumPlanTitle,
              style: TextStyle(
                color: textColor.withValues(alpha: 0.55),
                letterSpacing: 1.1,
              ),
            ),
            subtitle: Text(
              loc.futureBillingPlan,
              style: TextStyle(color: textColor.withValues(alpha: 0.42)),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            loc.comingSoonLabel,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textColor.withValues(alpha: 0.48),
              letterSpacing: 0.6,
            ),
          ),
        ],
        ),
      ),
    );
  }
}

class _GoogleLogoIcon extends StatelessWidget {
  const _GoogleLogoIcon({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(1.6),
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: SvgPicture.string(
        _googleGLogoSvg24,
        width: size,
        height: size,
        fit: BoxFit.contain,
      ),
    );
  }
}

const _googleGLogoSvg24 =
    '<svg xmlns="http://www.w3.org/2000/svg" height="24" viewBox="0 0 24 24" '
    'width="24"><path d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92'
    'c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 '
    '3.28-8.09z" fill="#4285F4"/><path d="M12 23c2.97 0 5.46-.98 '
    '7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 '
    '0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z" '
    'fill="#34A853"/><path d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09'
    's.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 '
    '3.45 1.18 4.93l2.85-2.22.81-.62z" fill="#FBBC05"/><path d="M12 '
    '5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 '
    '12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 '
    '6.16-4.53z" fill="#EA4335"/><path d="M1 1h22v22H1z" fill="none"/>'
    '</svg>';
