import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:majurun/core/widgets/shimmer_loading.dart';

Widget buildUserAvatar({required String photoUrl, required double radius}) {
  final url = photoUrl.trim();

  if (url.isEmpty) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey.shade200,
      child: Icon(Icons.person, size: radius, color: Colors.grey),
    );
  }

  return ClipOval(
    child: SizedBox(
      width: radius * 2,
      height: radius * 2,
      child: CachedNetworkImage(
        imageUrl: url,
        memCacheWidth: 200,
        fit: BoxFit.cover,
        // Soft shimmer placeholder (skeleton) — feels instant and polished
        // vs a spinner while the image downloads.
        placeholder: (context, url) => ShimmerBox(
          width: radius * 2,
          height: radius * 2,
          borderRadius: BorderRadius.circular(radius),
        ),
        errorWidget: (context, url, error) => CircleAvatar(
          radius: radius,
          backgroundColor: Colors.grey.shade200,
          child: Icon(Icons.person, size: radius, color: Colors.grey),
        ),
      ),
    ),
  );
}
