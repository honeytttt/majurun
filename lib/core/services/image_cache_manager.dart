import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Custom cache manager — keeps images for 30 days, caches up to 500 files.
/// Pass this to every CachedNetworkImage to avoid re-downloading avatars/post
/// images on every scroll.
///
/// Usage:
///   CachedNetworkImage(
///     imageUrl: url,
///     cacheManager: AppImageCacheManager.instance,
///   )
class AppImageCacheManager {
  static const key = 'majurun_image_cache';

  static CacheManager get instance => _instance;

  static final CacheManager _instance = CacheManager(
    Config(
      key,
      stalePeriod: const Duration(days: 30),
      maxNrOfCacheObjects: 500,
      repo: JsonCacheInfoRepository(databaseName: key),
      fileService: HttpFileService(),
    ),
  );
}
