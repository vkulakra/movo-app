import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'providers/habit_provider.dart';
import 'providers/mood_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/reminder_provider.dart';
import 'providers/ad_provider.dart';
import 'screens/home_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/habits_screen.dart';
import 'screens/mood_journal_screen.dart';
import 'screens/statistics_screen.dart';
import 'theme/app_theme.dart';
import 'services/notification_service.dart';
import 'services/workmanager_service.dart';
import 'services/native_alarm_manager.dart';
import 'widgets/banner_ad_widget.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Google Mobile Ads SDK (privacy-friendly, no tracking).
  // Wrapped in try-catch so missing Google Play Services doesn't crash the app.
  try {
    await MobileAds.instance.initialize();
    await MobileAds.instance.updateRequestConfiguration(
      RequestConfiguration(
        tagForChildDirectedTreatment: TagForChildDirectedTreatment.unspecified,
        tagForUnderAgeOfConsent: TagForUnderAgeOfConsent.unspecified,
      ),
    );
  } catch (e) {
    debugPrint('AdMob initialization failed (non-fatal): $e');
  }

  await NotificationService.instance.initialize();
  await WorkmanagerService.initialize();
  await NativeAlarmManager.initialize();

  // Handle any pending alarm action that arrived during cold start
  // (e.g. user tapped "Task Done" on a notification from setAlarmClock)
  final pendingAction = await NativeAlarmManager.getPendingAlarmAction();
  if (pendingAction != null) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleAlarmAction(pendingAction);
    });
  }

  // Load theme preference before running app
  final themeProvider = ThemeProvider();
  await themeProvider.loadTheme();

  runApp(MovoApp(themeProvider: themeProvider));

  // Set up notification response handler after the widget tree is built
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _setupNotificationHandler();
  });
}

void _setupNotificationHandler() {
  NotificationService.instance.onResponse = (response) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    // Notification body tapped (no action button) → navigate to Habits tab
    if (response.actionId == null) {
      MainScreen.navigateToTab(1);
      return;
    }

    // Handle "Task Done" action — mark all today's uncompleted habits as done
    if (response.actionId == NotificationService.actionTaskDone) {
      final habitProv = context.read<HabitProvider>();
      final uncompleted = habitProv.habits.where((h) =>
          h.id != null &&
          !habitProv.todayCompletions.any((c) => c.habitId == h.id)).toList();

      for (final habit in uncompleted) {
        habitProv.addCompletion(habit.id!);
      }

      // Track that the notification was shown today (prevents duplicate missed check)
      context.read<ReminderProvider>().markReminderShown();

      if (uncompleted.isNotEmpty) {
        NotificationService.instance.showTaskDoneConfirmation(
          uncompleted.length,
        );
      }
    }
    // "Not Done" action — notification is auto-dismissed via cancelNotification: true
    if (response.actionId == NotificationService.actionNotDone) {
      // Track that the notification was seen today (prevents duplicate missed check)
      context.read<ReminderProvider>().markReminderShown();
      return;
    }
  };

  // Handle actions from the native AlarmManager.setAlarmClock
  NativeAlarmManager.onAlarmAction = (action) {
    _handleAlarmAction(action);
  };
}

/// Shared handler for native alarm actions (both warm-start via callback
/// and cold-start via [NativeAlarmManager.getPendingAlarmAction]).
void _handleAlarmAction(String action) {
  final ctx = navigatorKey.currentContext;
  if (ctx == null) return;

  if (action == 'task_done') {
    final habitProv = ctx.read<HabitProvider>();
    final uncompleted = habitProv.habits.where((h) =>
        h.id != null &&
        !habitProv.todayCompletions.any((c) => c.habitId == h.id)).toList();

    for (final habit in uncompleted) {
      habitProv.addCompletion(habit.id!);
    }

    ctx.read<ReminderProvider>().markReminderShown();

    if (uncompleted.isNotEmpty) {
      NotificationService.instance.showTaskDoneConfirmation(
        uncompleted.length,
      );
    }
  } else if (action == 'not_done') {
    ctx.read<ReminderProvider>().markReminderShown();
  } else if (action == 'alarm_fired') {
    // Notification body tapped — navigate to Habits tab
    MainScreen.navigateToTab(1);
  }
}

class MovoApp extends StatelessWidget {
  final ThemeProvider themeProvider;

  const MovoApp({super.key, required this.themeProvider});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider(create: (_) {
          final adProv = AdProvider();
          // Fire-and-forget: catch any errors so they don't crash the app
          adProv.initialize().catchError((e) {
            debugPrint('AdProvider init error (non-fatal): $e');
          });
          return adProv;
        }),
        ChangeNotifierProvider(create: (_) => HabitProvider()),
        ChangeNotifierProvider(create: (_) => MoodProvider()),
        ChangeNotifierProvider(create: (_) => ReminderProvider()
          ..loadSettings()
          ..requestPermissions()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProv, _) {
          return _AnimatedThemeApp(
            isDarkMode: themeProv.isDarkMode,
            themeProvider: themeProv,
            child: MainScreen(),
          );
        },
      ),
    );
  }
}

class _AnimatedThemeApp extends StatefulWidget {
  final bool isDarkMode;
  final ThemeProvider themeProvider;
  final Widget child;

  const _AnimatedThemeApp({
    required this.isDarkMode,
    required this.themeProvider,
    required this.child,
  });

  @override
  State<_AnimatedThemeApp> createState() => _AnimatedThemeAppState();
}

class _AnimatedThemeAppState extends State<_AnimatedThemeApp>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Start at the correct position based on initial theme
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
      value: widget.isDarkMode ? 1.0 : 0.0,
    );
    // Defer system brightness update to avoid calling notifyListeners() during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateSystemBrightness();
      // Check for missed reminder on first launch
      _checkMissedReminder();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkMissedReminder();
    }
  }

  void _checkMissedReminder() {
    final context = navigatorKey.currentContext;
    if (context == null) return;
    final reminderProv = context.read<ReminderProvider>();
    final habitProv = context.read<HabitProvider>();
    reminderProv.showReminderIfDue(habitProv);
  }

  @override
  void didChangePlatformBrightness() {
    _updateSystemBrightness();
  }

  void _updateSystemBrightness() {
    final brightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    widget.themeProvider.updateSystemBrightness(brightness);
  }

  @override
  void didUpdateWidget(_AnimatedThemeApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isDarkMode != oldWidget.isDarkMode) {
      if (widget.isDarkMode) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          title: 'Movo',
          debugShowCheckedModeBanner: false,
          theme: ThemeData.lerp(
            AppTheme.lightTheme,
            AppTheme.darkTheme,
            _controller.value,
          ),
          home: SplashScreen(home: child!),
        );
      },
      child: widget.child,
    );
  }
}

class MainScreen extends StatefulWidget {
  static final GlobalKey<_MainScreenState> _tabKey =
      GlobalKey<_MainScreenState>();

  MainScreen() : super(key: _tabKey);

  /// Programmatically navigate to a tab by index (0=Home, 1=Habits, 2=Journal, 3=Stats).
  static void navigateToTab(int index) {
    _tabKey.currentState?.setTab(index);
  }

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  void setTab(int index) {
    if (index != _currentIndex) {
      setState(() => _currentIndex = index);
    }
  }

  final List<Widget> _screens = [
    const HomeScreen(),
    const HabitsScreen(),
    const MoodJournalScreen(),
    const StatisticsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Banner ad — only shown when ads are not removed
          Consumer<AdProvider>(
            builder: (context, adProvider, _) {
              if (adProvider.adsRemoved) return const SizedBox.shrink();
              return const BannerAdWidget();
            },
          ),
          // Existing bottom navigation bar
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            margin: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.3)
                      : Colors.black.withValues(alpha: 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BottomNavigationBar(
                currentIndex: _currentIndex,
                onTap: (index) => setState(() => _currentIndex = index),
                backgroundColor:
                    isDark ? AppTheme.darkCardColor : Colors.white,
                selectedItemColor: AppTheme.primaryColor,
                unselectedItemColor:
                    isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                type: BottomNavigationBarType.fixed,
                elevation: 0,
                selectedFontSize: 12,
                unselectedFontSize: 12,
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.home_outlined),
                    activeIcon: Icon(Icons.home_rounded),
                    label: 'Home',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.checklist_outlined),
                    activeIcon: Icon(Icons.checklist_rounded),
                    label: 'Habits',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.mood_outlined),
                    activeIcon: Icon(Icons.mood_rounded),
                    label: 'Journal',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.bar_chart_outlined),
                    activeIcon: Icon(Icons.bar_chart_rounded),
                    label: 'Stats',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
