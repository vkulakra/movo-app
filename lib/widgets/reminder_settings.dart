import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/reminder_provider.dart';
import '../providers/habit_provider.dart';
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
                    'Daily Reminder',
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Get a friendly nudge to complete your habits',
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
                        'Enable Reminders',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        provider.isEnabled
                            ? 'Reminder set for ${provider.timeDisplay}'
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

                    // Time picker
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.grey.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ListTile(
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.schedule_rounded,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        title: Text(
                          'Reminder Time',
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                          ),
                        ),
                        trailing: Text(
                          provider.timeDisplay,
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        onTap: () async {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay(
                              hour: provider.hour,
                              minute: provider.minute,
                            ),
                            builder: (context, child) {
                              return Theme(
                                data: theme.copyWith(
                                  colorScheme: theme.colorScheme.copyWith(
                                    primary: AppTheme.primaryColor,
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (time != null && mounted) {
                            await provider.setTime(time.hour, time.minute);
                          }
                        },
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

                    const SizedBox(height: 20),

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
                              'You\'ll get a notification with "Task Done" and "Not Done" buttons to quickly update your progress.',
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

                    // Battery optimization tip — important for Realme/OPPO/Xiaomi
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.battery_alert_rounded,
                            size: 20,
                            color: Colors.orange.shade400,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Scheduled reminders not arriving?',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.orange.shade700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'On some phones (Realme, OPPO, Xiaomi), battery optimization blocks scheduled alarms. Please open Battery Settings and select "No restrictions" / "Allow background activity" for Movo.',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: Colors.orange.shade600,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () => provider.openBatterySettings(),
                                        icon: const Icon(Icons.battery_charging_full_rounded, size: 16),
                                        label: const Text('⚙ Battery', style: TextStyle(fontSize: 12)),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.orange.shade600,
                                          side: BorderSide(color: Colors.orange.withValues(alpha: 0.3)),
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () => provider.openAppSettings(),
                                        icon: const Icon(Icons.settings_rounded, size: 16),
                                        label: const Text('⚙ App Info', style: TextStyle(fontSize: 12)),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.orange.shade600,
                                          side: BorderSide(color: Colors.orange.withValues(alpha: 0.3)),
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Immediate test notification button
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
                        label: const Text('Send Instant Test'),
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

                    const SizedBox(height: 12),

                    // Scheduled test notification button — verifies exact alarm timing
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await NotificationService.instance.sendTestScheduledReminder();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Scheduled test sent! It will arrive in ~1 minute to verify exact alarm timing.'),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                duration: const Duration(seconds: 5),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.timer_rounded, size: 20),
                        label: const Text('Test Exact Scheduling (1 min)'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryColor.withValues(alpha: 0.8),
                          side: BorderSide(
                            color: AppTheme.primaryColor.withValues(alpha: 0.15),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Check for missed reminder button — safety net for when scheduled alarms fail
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          // Access HabitProvider from the widget tree
                          final habitProv = context.read<HabitProvider>();
                          final shown = await provider.showReminderIfDue(habitProv);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  shown
                                      ? 'Reminder shown! Check your notification shade.'
                                      : (provider.hasScheduledTimePassed
                                          ? 'Reminder was already shown today.'
                                          : 'Scheduled time (${provider.timeDisplay}) has not passed yet.'),
                                ),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                duration: const Duration(seconds: 4),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.notifications_active_rounded, size: 20),
                        label: const Text('Show Reminder Now (Missed Check)'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.green.shade600,
                          side: BorderSide(
                            color: Colors.green.withValues(alpha: 0.3),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Diagnostics section
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.04)
                            : Colors.grey.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.bug_report_outlined,
                                  size: 16,
                                  color: isDark
                                      ? AppTheme.darkTextSecondary
                                      : AppTheme.textSecondary),
                              const SizedBox(width: 8),
                              Text(
                                'Scheduling Diagnostics',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? AppTheme.darkTextSecondary
                                      : AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _DiagnosticRow(
                            label: 'Schedule mode',
                            value: 'inexactAllowWhileIdle',
                            isDark: isDark,
                          ),
                          _DiagnosticRow(
                            label: 'Reminder time',
                            value: provider.timeDisplay,
                            isDark: isDark,
                          ),
                          _DiagnosticRow(
                            label: 'Time passed',
                            value: provider.hasScheduledTimePassed ? 'Yes' : 'No',
                            isDark: isDark,
                          ),
                          FutureBuilder<bool>(
                            future: provider.wasReminderShownToday(),
                            builder: (context, snapshot) {
                              return _DiagnosticRow(
                                label: 'Shown today',
                                value: snapshot.data == true ? 'Yes' : 'No',
                                isDark: isDark,
                              );
                            },
                          ),
                        ],
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
                activeColor: AppTheme.primaryColor,
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

/// A small row widget for showing diagnostic key-value pairs.
class _DiagnosticRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;

  const _DiagnosticRow({
    required this.label,
    required this.value,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
