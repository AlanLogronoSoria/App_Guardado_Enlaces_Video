import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/models/link.dart';
import 'core_providers.dart';

final shareHistoryProvider = FutureProvider<List<LinkModel>>((ref) {
  final repo = ref.watch(linkRepositoryProvider);
  return repo.getShareLinks();
});
