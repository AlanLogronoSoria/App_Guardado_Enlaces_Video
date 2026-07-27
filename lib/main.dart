import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'core/config/app_config.dart';
import 'core/constants/app_constants.dart';
import 'core/services/platform_detector.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'shared/providers/core_providers.dart';
import 'shared/providers/link_providers.dart';
import 'shared/providers/category_providers.dart';

enum SaveMode { confirmation, fast, auto }

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);
final saveModeProvider = StateProvider<SaveMode>((ref) => SaveMode.confirmation);

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
  String? _lastSharedUrl;
  DateTime _lastHandledAt = DateTime(2000);

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
      ref.read(backupSchedulerProvider).tryScheduledBackup();
      ref.read(databaseProvider).initializeDefaultCategories();
    });
  }

  bool _shouldHandle(String url) {
    final now = DateTime.now();
    if (url == _lastSharedUrl &&
        now.difference(_lastHandledAt).inSeconds < 5) {
      debugPrint('[SHARE] ignorado: mismo URL en menos de 5s');
      return false;
    }
    _lastSharedUrl = url;
    _lastHandledAt = now;
    return true;
  }

  void _handleShareIntent() {
    ReceiveSharingIntent.instance
        .getInitialMedia()
        .then((List<SharedMediaFile> value) {
      debugPrint('[SHARE] getInitialMedia: ${value.length} items');
      if (value.isNotEmpty) {
        final sharedText = value.map((f) => f.path).join(' ');
        _extractAndHandle(sharedText);
      }

      _shareSubscription = ReceiveSharingIntent.instance
          .getMediaStream()
          .listen((List<SharedMediaFile> value) {
        debugPrint('[SHARE] getMediaStream: ${value.length} items');
        if (value.isNotEmpty) {
          final sharedText = value.map((f) => f.path).join(' ');
          _extractAndHandle(sharedText);
        }
      });
    });
  }

  void _extractAndHandle(String text) {
    debugPrint('[SHARE] _extractAndHandle input: "$text"');
    String? url;
    final uri = Uri.tryParse(text);
    if (uri != null &&
        uri.hasScheme &&
        (uri.scheme == 'http' || uri.scheme == 'https')) {
      url = text.trim();
    } else if (text.contains('http')) {
      final match = RegExp(r'(https?://\S+)').firstMatch(text);
      if (match != null) {
        url = match.group(1)!.trim();
      }
    }

    if (url != null && _shouldHandle(url)) {
      debugPrint('[SHARE] URL válida, procesando: $url');
      final router = ref.read(routerProvider);
      final mode = ref.read(saveModeProvider);

      switch (mode) {
        case SaveMode.confirmation:
          router.push(
              '${AppConfig.addLinkRoute}?url=${Uri.encodeComponent(url)}');
          break;
        case SaveMode.fast:
          _handleFastMode(router, url);
          break;
        case SaveMode.auto:
          _handleAutoMode(router, url);
          break;
      }
    }
  }

  Future<void> _handleFastMode(GoRouter router, String url) async {
    final platform = PlatformDetector.detect(url);
    if (platform == PlatformType.unknown) {
      router.push(
          '${AppConfig.addLinkRoute}?url=${Uri.encodeComponent(url)}');
      return;
    }

    final metadataService = ref.read(metadataServiceProvider);
    final categoryRepo = ref.read(categoryRepositoryProvider);
    final linkRepo = ref.read(linkRepositoryProvider);
    final openaiService = ref.read(openaiServiceProvider);

    String title;
    String? thumbnail;

    try {
      final metadata = await metadataService.fetchMetadata(url, platform);
      title = metadata.title ?? 'Video de ${platform.displayName}';
      thumbnail = metadata.thumbnail;
    } catch (_) {
      title = 'Video de ${platform.displayName}';
      thumbnail = null;
    }

    final categories = await categoryRepo.getAllCategories();
    final categoryNames = categories.map((c) => c.name).toList();

    String category = AppConstants.defaultCategory;

    if (categoryNames.isNotEmpty) {
      try {
        final aiResult = await openaiService.classifyWithCategories(
          title,
          categoryNames,
        );
        if (aiResult.category != null && aiResult.isHighConfidence) {
          category = aiResult.category!;
          await categoryRepo.ensureCategory(category);
          await linkRepo.saveLink(
            url: url, platform: platform.name,
            title: title, thumbnail: thumbnail, category: category,
            source: 'share',
          );
          ref.invalidate(allLinksProvider);
          ref.invalidate(allCategoriesProvider);
          _showSavedToast('Guardado en $category');
          return;
        }
      } catch (_) {}
    }

    router.push(
        '${AppConfig.addLinkRoute}?url=${Uri.encodeComponent(url)}');
  }

  Future<void> _handleAutoMode(GoRouter router, String url) async {
    final platform = PlatformDetector.detect(url);
    final platformName = platform.name;

    final categoryRepo = ref.read(categoryRepositoryProvider);
    final linkRepo = ref.read(linkRepositoryProvider);

    await categoryRepo.ensureCategory(AppConstants.defaultCategory);

    final title = 'Video de ${platform.displayName}';

    try {
      await linkRepo.saveLink(
        url: url,
        platform: platformName,
        title: title,
        category: AppConstants.defaultCategory,
        source: 'share',
      );
      ref.invalidate(allLinksProvider);
      ref.invalidate(allCategoriesProvider);
      _showSavedToast('Video guardado en ${AppConstants.defaultCategory}');
    } catch (_) {}

    _enrichInBackground(url, platform, title);
  }

  void _showSavedToast(String message) {
    final context = rootNavigatorKey.currentContext;
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _enrichInBackground(
      String url, PlatformType platform, String initialTitle) async {
    final metadataService = ref.read(metadataServiceProvider);
    final linkRepo = ref.read(linkRepositoryProvider);
    final categoryRepo = ref.read(categoryRepositoryProvider);

    try {
      final links = await linkRepo.getAllLinks();
      final savedLink = links.where((l) => l.url == url).firstOrNull;
      if (savedLink == null) return;

      String? newTitle;
      String? newThumbnail;

      try {
        final metadata = await metadataService.fetchMetadata(url, platform);
        if (metadata.title != null && metadata.title!.isNotEmpty) {
          newTitle = metadata.title;
        }
        newThumbnail = metadata.thumbnail;
      } catch (_) {}

      final categories = await categoryRepo.getAllCategories();
      final categoryNames = categories.map((c) => c.name).toList();
      String? aiCategory;

      if (categoryNames.isNotEmpty && newTitle != null) {
        try {
          final aiResult = await ref
              .read(openaiServiceProvider)
              .classifyWithCategories(newTitle, categoryNames);
          if (aiResult.category != null && aiResult.isHighConfidence) {
            aiCategory = aiResult.category;
            await categoryRepo.ensureCategory(aiCategory!);
          }
        } catch (_) {}
      }

      await linkRepo.updateLink(
        savedLink.id,
        title: newTitle ?? savedLink.title,
        thumbnail: newThumbnail ?? savedLink.thumbnail,
        category: aiCategory ?? savedLink.category,
      );

      ref.invalidate(allLinksProvider);
      ref.invalidate(allCategoriesProvider);
    } catch (_) {}
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
