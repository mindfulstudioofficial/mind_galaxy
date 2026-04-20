import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
          // Reserved for future release:
          // - Account / Sync
          // - Premium Plan
          // Keeping these blocks commented-out for planned implementation.
          //
          // ListTile(
          //   leading: const Icon(Icons.cloud_sync, color: Colors.white70),
          //   title: Text(
          //     loc.accountSyncTitle,
          //     style: TextStyle(color: textColor, letterSpacing: 1.1),
          //   ),
          //   subtitle: Text(
          //     loc.futureLoginFeature,
          //     style: TextStyle(color: Colors.white.withOpacity(0.55)),
          //   ),
          //   onTap: () {},
          // ),
          // ListTile(
          //   leading: const Icon(Icons.workspace_premium, color: Colors.white70),
          //   title: Text(
          //     loc.premiumPlanTitle,
          //     style: TextStyle(color: textColor, letterSpacing: 1.1),
          //   ),
          //   subtitle: Text(
          //     loc.futureBillingPlan,
          //     style: TextStyle(color: Colors.white.withOpacity(0.55)),
          //   ),
          //   onTap: () {},
          // ),
          const SizedBox(height: 6),
          Text(
            loc.comingSoonLabel,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textColor.withOpacity(0.48),
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}
