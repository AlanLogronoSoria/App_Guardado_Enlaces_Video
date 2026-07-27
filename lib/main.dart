import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'core/config/app_config.dart';
import 'core/constants/app_constants.dart';
import 'core/services/platform_detector.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'features/quick_save/quick_save_sheet.dart';
import 'shared/providers/core_providers.dart';
import 'shared/providers/link_providers.dart';
import 'shared/providers/category_providers.dart';

enum SaveMode { confirmation, fast, auto }

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);
final shareUrlProvider = StateProvider<String?>((ref) => null);
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
    ReceiveSharingIntent.instance
        .getInitialMedia()
        .then((List<SharedMediaFile> value) {
      debugPrint('[SHARE] getInitialMedia: ${value.length} items');
      for (var i = 0; i < value.length; i++) {
        debugPrint(
            '[SHARE]   item[$i] path="${value[i].path}" type="${value[i].type}"');
      }
      if (value.isNotEmpty) {
        final sharedText = value.map((f) => f.path).join(' ');
        debugPrint('[SHARE] joined text: "$sharedText"');
        _processIncomingText(sharedText);
      }
    });

    _shareSubscription = ReceiveSharingIntent.instance
        .getMediaStream()
        .listen((List<SharedMediaFile> value) {
      debugPrint('[SHARE] getMediaStream: ${value.length} items');
      for (var i = 0; i < value.length; i++) {
        debugPrint(
            '[SHARE]   item[$i] path="${value[i].path}" type="${value[i].type}"');
      }
      if (value.isNotEmpty) {
        final sharedText = value.map((f) => f.path).join(' ');
        debugPrint('[SHARE] joined text: "$sharedText"');
        _processIncomingText(sharedText);
      }
    });
  }

  void _processIncomingText(String text) {
    debugPrint('[SHARE] _processIncomingText input: "$text"');
    String? extractedUrl;
    final uri = Uri.tryParse(text);
    debugPrint('[SHARE] Uri.tryParse result: $uri');
    if (uri != null &&
        uri.hasScheme &&
        (uri.scheme == 'http' || uri.scheme == 'https')) {
      extractedUrl = text.trim();
      debugPrint('[SHARE] direct URL match: "$extractedUrl"');
    } else if (text.contains('http')) {
      final match = RegExp(r'(https?://\S+)').firstMatch(text);
      if (match != null) {
        extractedUrl = match.group(1)!.trim();
        debugPrint('[SHARE] regex URL match: "$extractedUrl"');
      }
    }

    if (extractedUrl != null) {
      debugPrint('[SHARE] setting shareUrlProvider to: "$extractedUrl"');
      Future.microtask(() {
        ref.read(shareUrlProvider.notifier).state = extractedUrl;
        debugPrint('[SHARE] shareUrlProvider state set');
      });
    } else {
      debugPrint('[SHARE] WARNING: no URL extracted from text');
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.read(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    final shareUrl = ref.watch(shareUrlProvider);

    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) {
        if (shareUrl != null) {
          final url = shareUrl;
          ref.read(shareUrlProvider.notifier).state = null;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _handleShareByMode(context, url);
          });
        }
        return child!;
      },
    );
  }

  void _handleShareByMode(BuildContext context, String url) {
    final mode = ref.read(saveModeProvider);

    switch (mode) {
      case SaveMode.confirmation:
        _showQuickSaveSheet(context, url);
      case SaveMode.fast:
        _handleFastMode(context, url);
      case SaveMode.auto:
        _handleAutoMode(context, url);
    }
  }

  void _showQuickSaveSheet(BuildContext context, String url) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => QuickSaveSheet(url: url),
    );
  }

  Future<void> _handleFastMode(BuildContext context, String url) async {
    final platform = PlatformDetector.detect(url);
    if (platform == PlatformType.unknown) {
      _showQuickSaveSheet(context, url);
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

          if (context.mounted) {
            _showSavedToast(context, category);
          }
          return;
        }
      } catch (_) {}
    }

    if (context.mounted) {
      _showQuickSaveSheet(context, url);
    }
  }

  Future<void> _handleAutoMode(BuildContext context, String url) async {
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

      if (context.mounted) {
        _showSavedToast(context, AppConstants.defaultCategory);
      }
    } catch (_) {}

    _enrichInBackground(url, platform, title);
  }

  void _showSavedToast(BuildContext context, String category) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Video guardado en $category'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
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
}
