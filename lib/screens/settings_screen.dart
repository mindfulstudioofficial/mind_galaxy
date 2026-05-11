import 'package:flutter/material.dart';
import 'package:mindgalaxy/l10n/app_localizations.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final textColor = Colors.white.withValues(alpha: 0.92);

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
            enabled: false,
            leading: Icon(
              Icons.cloud_sync,
              color: textColor.withValues(alpha: 0.38),
            ),
            title: Text(
              loc.accountSyncTitle,
              style: TextStyle(
                color: textColor.withValues(alpha: 0.55),
                letterSpacing: 1.1,
              ),
            ),
            subtitle: Text(
              loc.futureLoginFeature,
              style: TextStyle(color: textColor.withValues(alpha: 0.42)),
            ),
          ),
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
