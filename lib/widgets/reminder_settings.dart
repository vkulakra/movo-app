import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/reminder_provider.dart';
import '../providers/ad_provider.dart';
import '../providers/crash_consent_provider.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';

class ReminderSettings extends StatefulWidget {
  const ReminderSettings({super.key});

  /// Show the reminder settings as a modal bottom sheet.
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ReminderSettings(),
    );
  }

  @override
  State<ReminderSettings> createState() => _ReminderSettingsState();
}

class _ReminderSettingsState extends State<ReminderSettings> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Consumer<ReminderProvider>(
      builder: (context, provider, _) {
        return Container(
          margin: EdgeInsets.only(bottom: bottom),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCardColor : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.2)
                            : Colors.black.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Title
                  Text(
                    'Notifications',
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Get friendly nudges throughout the day',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Toggle row
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.grey.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: SwitchListTile(
                      title: Text(
                        'Enable Notifications',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        provider.isEnabled
                            ? 'You\'ll get up to 4 random check-ins daily'
                            : 'Tap to turn on',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                        ),
                      ),
                      value: provider.isEnabled,
                      activeThumbColor: AppTheme.primaryColor,
                      onChanged: (value) => provider.setEnabled(value),
                    ),
                  ),

                  if (provider.isEnabled) ...[
                    const SizedBox(height: 16),

                    // Time windows explanation
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppTheme.primaryColor.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.schedule_rounded,
                                size: 20,
                                color: AppTheme.primaryColor,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Daily Check-In Times',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? AppTheme.darkTextPrimary
                                      : AppTheme.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _WindowRow(
                            icon: Icons.wb_sunny_rounded,
                            label: 'Morning',
                            time: '6:00 – 10:59',
                            isDark: isDark,
                          ),
                          const SizedBox(height: 8),
                          _WindowRow(
                            icon: Icons.wb_cloudy_rounded,
                            label: 'Afternoon',
                            time: '11:00 – 14:59',
                            isDark: isDark,
                          ),
                          const SizedBox(height: 8),
                          _WindowRow(
                            icon: Icons.nights_stay_rounded,
                            label: 'Evening',
                            time: '15:00 – 18:59',
                            isDark: isDark,
                          ),
                          const SizedBox(height: 8),
                          _WindowRow(
                            icon: Icons.bedtime_rounded,
                            label: 'Night',
                            time: '19:00 – 21:59',
                            isDark: isDark,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Weekly summary toggle
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.grey.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: SwitchListTile(
                        title: Text(
                          'Weekly Summary',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          'Sunday recap of your habit week',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                          ),
                        ),
                        secondary: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.calendar_view_week_rounded,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        value: provider.weeklyEnabled,
                        activeThumbColor: AppTheme.primaryColor,
                        onChanged: (value) => provider.setWeeklyEnabled(value),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Info text
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 20,
                            color: AppTheme.primaryColor.withValues(alpha: 0.8),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Notifications arrive at random times within each window. Tap "Task Done" or "Not Done" to update your progress instantly.',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: AppTheme.primaryColor.withValues(alpha: 0.8),
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Test notification button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await NotificationService.instance.sendTestNotification();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Test notification sent! Check your notification shade.'),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                duration: const Duration(seconds: 4),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.bug_report_rounded, size: 20),
                        label: const Text('Send Test Notification'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryColor,
                          side: BorderSide(
                            color: AppTheme.primaryColor.withValues(alpha: 0.3),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],

                  // ── Remove Ads Section ──
                  const SizedBox(height: 8),
                  Consumer<AdProvider>(
                    builder: (context, adProvider, _) {
                      return _RemoveAdsCard(
                        isDark: isDark,
                        adProvider: adProvider,
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // ── Crash Reporting Section ──
                  Consumer<CrashConsentProvider>(
                    builder: (context, crashProvider, _) {
                      return _CrashConsentCard(
                        isDark: isDark,
                        crashProvider: crashProvider,
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A single row showing a time window's icon, label, and time range.
class _WindowRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String time;
  final bool isDark;

  const _WindowRow({
    required this.icon,
    required this.label,
    required this.time,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.primaryColor),
        const SizedBox(width: 10),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
          ),
        ),
        const Spacer(),
        Text(
          time,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.primaryColor,
          ),
        ),
      ],
    );
  }
}

/// Card widget that shows the "Remove Ads" purchase option or a
/// "Thanks for your support!" message if already purchased.
class _RemoveAdsCard extends StatelessWidget {
  final bool isDark;
  final AdProvider adProvider;

  const _RemoveAdsCard({
    required this.isDark,
    required this.adProvider,
  });

  @override
  Widget build(BuildContext context) {
    if (adProvider.adsRemoved) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.green.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.verified_rounded,
                color: Colors.green,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Movo Premium',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Thanks for your support! \u2764\ufe0f',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.green.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Not purchased yet — show upgrade card
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withValues(alpha: 0.12),
            AppTheme.secondaryColor.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: AppTheme.primaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Go Premium',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppTheme.darkTextPrimary
                            : AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Remove ads and support the app',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: adProvider.isProductAvailable
                  ? () async {
                      final success =
                          await adProvider.purchaseRemoveAds();
                      if (success && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text(
                              'Welcome to Movo Premium! Ads have been removed.',
                            ),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(12),
                            ),
                            duration: const Duration(seconds: 3),
                          ),
                        );
                      }
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    AppTheme.primaryColor.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: Text(
                adProvider.isProductAvailable
                    ? 'Buy for ${adProvider.productPrice}'
                    : adProvider.isLoading
                        ? 'Loading...'
                        : 'Unavailable',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          if (adProvider.isProductAvailable) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => adProvider.restorePurchases(),
                child: Text(
                  'Restore Purchase',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ),
          ],
          if (adProvider.errorMessage != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_rounded,
                      size: 16, color: AppTheme.errorColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      adProvider.errorMessage!,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: AppTheme.errorColor,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => adProvider.clearError(),
                    child: const Icon(Icons.close,
                        size: 16, color: AppTheme.errorColor),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            'One-time purchase. No subscription. No account needed.',
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: isDark
                  ? AppTheme.darkTextSecondary
                  : AppTheme.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

/// Card widget that shows the crash reporting consent toggle.
/// Only visible when Firebase is available and the user has been prompted.
class _CrashConsentCard extends StatelessWidget {
  final bool isDark;
  final CrashConsentProvider crashProvider;

  const _CrashConsentCard({
    required this.isDark,
    required this.crashProvider,
  });

  @override
  Widget build(BuildContext context) {
    // Only show if Firebase is available and user has been prompted
    if (!crashProvider.canToggle) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  crashProvider.consentGiven
                      ? Icons.shield_rounded
                      : Icons.shield_outlined,
                  color: AppTheme.primaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Crash Reports',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppTheme.darkTextPrimary
                            : AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      crashProvider.consentGiven
                          ? 'Anonymous crash reports are enabled. Thank you!'
                          : 'Help us improve by sharing anonymous crash data',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Send anonymous crash reports',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: isDark
                      ? AppTheme.darkTextPrimary
                      : AppTheme.textPrimary,
                ),
              ),
              Switch(
                value: crashProvider.consentGiven,
                onChanged: (value) {
                  if (value) {
                    crashProvider.grantConsent();
                  } else {
                    crashProvider.denyConsent();
                  }
                },
                activeThumbColor: AppTheme.primaryColor,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'No personal data, habits, or journal entries are ever sent. You can change this anytime.',
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: isDark
                  ? AppTheme.darkTextSecondary
                  : AppTheme.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
