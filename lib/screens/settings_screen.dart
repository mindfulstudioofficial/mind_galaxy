import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _showPreparingNotice(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final textColor = Colors.white.withOpacity(0.92);

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
            leading: const Icon(Icons.cloud_sync, color: Colors.white70),
            title: Text(
              loc.accountSyncTitle,
              style: TextStyle(color: textColor, letterSpacing: 1.1),
            ),
            subtitle: Text(
              loc.futureLoginFeature,
              style: TextStyle(color: Colors.white.withOpacity(0.55)),
            ),
            onTap: () {
              _showPreparingNotice(
                context,
                "${loc.accountSyncTitle} ${loc.preparing}",
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.workspace_premium, color: Colors.white70),
            title: Text(
              loc.premiumPlanTitle,
              style: TextStyle(color: textColor, letterSpacing: 1.1),
            ),
            subtitle: Text(
              loc.futureBillingPlan,
              style: TextStyle(color: Colors.white.withOpacity(0.55)),
            ),
            onTap: () {
              _showPreparingNotice(
                context,
                "${loc.premiumPlanTitle} ${loc.preparing}",
              );
            },
          ),
        ],
      ),
    );
  }
}
