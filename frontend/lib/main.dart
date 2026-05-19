import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:secure_application/secure_application.dart';
import 'theme/app_theme.dart';
import 'services/database_service.dart';
import 'services/vault_session.dart';
import 'screens/setup_screen.dart';
import 'screens/lock_screen.dart';
import 'screens/vault_screen.dart';
import 'screens/entry_detail_screen.dart';
import 'screens/edit_entry_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/chrome_import_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const PassMgrApp());
}

class PassMgrApp extends StatelessWidget {
  const PassMgrApp({super.key});

  @override
  Widget build(BuildContext context) {
    return SecureApplication(
      child: MaterialApp(
        title: 'PassMgr',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const AppGate(),
        routes: {
          '/setup': (_) => const SetupScreen(),
          '/lock': (_) => const LockScreen(),
          '/vault': (_) => const VaultScreen(),
          '/settings': (_) => const SettingsScreen(),
          '/import': (_) => const ChromeImportScreen(),
        },
        onGenerateRoute: (settings) {
          if (settings.name == '/detail') {
            final entryId = settings.arguments as int;
            return MaterialPageRoute(
              builder: (_) => EntryDetailScreen(entryId: entryId),
            );
          }
          if (settings.name == '/edit') {
            final entryId = settings.arguments as int?;
            return MaterialPageRoute(
              builder: (_) => EditEntryScreen(entryId: entryId),
            );
          }
          return null;
        },
      ),
    );
  }
}

class AppGate extends StatefulWidget {
  const AppGate({super.key});

  @override
  State<AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<AppGate> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _route();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      if (VaultSession.instance.isUnlocked) {
        VaultSession.instance.lock();
      }
    }
  }

  Future<void> _route() async {
    final initialized = await DatabaseService.instance.isVaultInitialized();
    if (!mounted) return;
    if (initialized) {
      Navigator.of(context).pushReplacementNamed('/lock');
    } else {
      Navigator.of(context).pushReplacementNamed('/setup');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.paper,
      body: Center(
        child: CircularProgressIndicator(color: AppColors.emerald),
      ),
    );
  }
}
