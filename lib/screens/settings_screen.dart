import 'package:flutter/material.dart';
import 'package:mindgalaxy/l10n/app_localizations.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final textColor = Colors.white.withOpacity(0.92);
    final isJa = Localizations.localeOf(context).languageCode == 'ja';

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
          Container(
            margin: const EdgeInsets.fromLTRB(4, 4, 4, 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.white.withOpacity(0.14),
                  child: Text(
                    '🙂',
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'You',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        isJa ? 'プロフィール' : 'Profile',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.62),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
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
          //     style: TextStyle(color: textColor.withOpacity(0.55)),
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
          //     style: TextStyle(color: textColor.withOpacity(0.55)),
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
