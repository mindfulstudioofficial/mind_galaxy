import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mindgalaxy/l10n/app_localizations.dart';
import 'package:mindgalaxy/services/auth_service.dart';
import 'package:mindgalaxy/services/app_settings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _authProvider = '';
  String _authDisplayName = '';
  bool _authBusy = false;

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
    setState(() => _authBusy = true);

    final result = provider == 'google'
        ? await AuthService.signInWithGoogle()
        : await AuthService.signInWithApple();
    await _loadAuthState();
    if (!mounted) return;
    setState(() => _authBusy = false);

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
      body: ListView(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 16),
        children: [
          ListTile(
            leading: Icon(
              isLoggedIn ? Icons.verified_user : Icons.cloud_sync,
              color: textColor.withValues(alpha: isLoggedIn ? 0.8 : 0.65),
            ),
            title: Text(
              loc.accountSyncTitle,
              style: TextStyle(
                color: textColor.withValues(alpha: 0.85),
                letterSpacing: 1.1,
              ),
            ),
            subtitle: Text(
              accountSubtitle,
              style: TextStyle(color: textColor.withValues(alpha: 0.68)),
            ),
          ),
          if (!isLoggedIn) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                loc.loginOptionalDescription,
                style: TextStyle(color: textColor.withValues(alpha: 0.56)),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 18,
                      color: textColor.withValues(alpha: 0.62),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        loc.loginBenefitSummary,
                        style: TextStyle(
                          color: textColor.withValues(alpha: 0.66),
                          height: 1.35,
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
                      onPressed: _authBusy ? null : () => _signIn('google'),
                      icon: const Icon(Icons.account_circle_outlined),
                      label: Text(loc.loginWithGoogle),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _authBusy ? null : () => _signIn('apple'),
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
                style: TextStyle(color: textColor.withValues(alpha: 0.5)),
              ),
            ),
          ],
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
    );
  }
}
