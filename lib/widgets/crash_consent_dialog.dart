import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/crash_consent_provider.dart';
import '../theme/app_theme.dart';

/// Shows an opt-in consent dialog for Firebase Crashlytics crash reporting.
///
/// Displays only once on first launch. The user can change their choice
/// later in the Settings (Reminder Settings) bottom sheet.
class CrashConsentDialog extends StatelessWidget {
  const CrashConsentDialog({super.key});

  /// Show the consent dialog if the user hasn't been prompted yet.
  static void showIfNeeded(BuildContext context) {
    final provider = context.read<CrashConsentProvider>();
    if (provider.hasPrompted || !provider.firebaseAvailable) return;

    showDialog(
      context: context,
      barrierDismissible: false, // Must make a choice
      builder: (_) => const CrashConsentDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      backgroundColor: isDark ? AppTheme.darkCardColor : Colors.white,
      elevation: 0,
      contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Shield icon
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.shield_rounded,
              color: AppTheme.primaryColor,
              size: 32,
            ),
          ),
          const SizedBox(height: 20),

          // Title
          Text(
            'Help Improve Movo',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),

          // Explanation
          Text(
            'Would you like to help us improve Movo by automatically '
            'sending anonymous crash reports?\n\n'
            'No personal data, habits, or journal entries are collected. '
            'Only crash and error data is sent to make the app more stable.',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // Privacy policy link
          Text(
            'You can change this anytime in Settings.',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      actions: [
        // "No Thanks" button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: TextButton(
            onPressed: () {
              context.read<CrashConsentProvider>().denyConsent();
              Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(
              foregroundColor: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              'No, Thanks',
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),

        // "Help Improve" button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: () {
              context.read<CrashConsentProvider>().grantConsent();
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              'Help Improve Movo',
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
