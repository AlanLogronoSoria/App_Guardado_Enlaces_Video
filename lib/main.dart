import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'core/config/app_config.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'shared/providers/core_providers.dart';

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (AppConfig.supabaseUrl != 'YOUR_SUPABASE_URL' &&
      AppConfig.supabaseUrl.isNotEmpty) {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabaseAnonKey,
    );
  }

  runApp(const ProviderScope(child: InventarioVideoApp()));
}

class InventarioVideoApp extends ConsumerStatefulWidget {
  const InventarioVideoApp({super.key});

  @override
  ConsumerState<InventarioVideoApp> createState() =>
      _InventarioVideoAppState();
}

class _InventarioVideoAppState extends ConsumerState<InventarioVideoApp> {
  StreamSubscription<dynamic>? _shareSubscription;

  @override
  void initState() {
    super.initState();
    _handleShareIntent();
    _scheduleBackup();
  }

  @override
  void dispose() {
    _shareSubscription?.cancel();
    super.dispose();
  }

  void _scheduleBackup() {
    Future.microtask(() {
      final scheduler = ref.read(backupSchedulerProvider);
      scheduler.tryScheduledBackup();
    });
  }

  void _handleShareIntent() {
    _shareSubscription = ReceiveSharingIntent.instance
        .getMediaStream()
        .listen((List<SharedMediaFile> value) {
      if (value.isNotEmpty) {
        final sharedText = value.map((f) => f.path).join(' ');
        _processIncomingText(sharedText);
      }
    });

    ReceiveSharingIntent.instance
        .getInitialMedia()
        .then((List<SharedMediaFile> value) {
      if (value.isNotEmpty) {
        final sharedText = value.map((f) => f.path).join(' ');
        _processIncomingText(sharedText);
      }
    });
  }

  void _processIncomingText(String text) {
    final uri = Uri.tryParse(text);
    if (uri != null &&
        uri.hasScheme &&
        (uri.scheme == 'http' || uri.scheme == 'https')) {
      _navigateToAddLink(text);
    } else if (text.contains('http')) {
      final match = RegExp(r'(https?://\S+)').firstMatch(text);
      if (match != null) {
        _navigateToAddLink(match.group(1)!);
      }
    }
  }

  void _navigateToAddLink(String url) {
    final router = ref.read(routerProvider);
    router.go('${AppConfig.addLinkRoute}?url=${Uri.encodeComponent(url)}');
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.read(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
