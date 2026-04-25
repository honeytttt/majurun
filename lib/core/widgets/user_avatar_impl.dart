import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:majurun/core/services/image_cache_manager.dart';

Widget buildUserAvatar({required String photoUrl, required double radius}) {
  final url = photoUrl.trim();

  if (url.isEmpty) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey.shade200,
      child: Icon(Icons.person, size: radius, color: Colors.grey.shade700),
    );
  }

  // Cap the decoded image size to 3× the display size (handles high-DPI screens).
  // On Android, decoding a 500×500 profile photo for a 40px circle was causing
  // a 2–3 second delay because the full image had to be decoded into memory.
  // Constraining memCache dimensions makes Android avatar loads near-instant.
  final cacheSize = (radius * 2 * 3).ceil();

  return ClipOval(
    child: SizedBox(
      width: radius * 2,
      height: radius * 2,
      child: CachedNetworkImage(
        imageUrl: url,
        cacheManager: AppImageCacheManager.instance,
        fit: BoxFit.cover,
        memCacheWidth: cacheSize,
        memCacheHeight: cacheSize,
        placeholder: (context, url) => CircleAvatar(
          radius: radius,
          backgroundColor: Colors.grey.shade200,
          child: Icon(Icons.person, size: radius, color: Colors.grey.shade700),
        ),
        errorWidget: (context, url, error) => CircleAvatar(
          radius: radius,
          backgroundColor: Colors.grey.shade200,
          child: Icon(Icons.person, size: radius, color: Colors.grey.shade700),
        ),
      ),
    ),
  );
}
