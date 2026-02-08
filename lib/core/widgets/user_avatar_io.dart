import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
        fit: BoxFit.cover,
        placeholder: (context, url) => CircleAvatar(
          radius: radius,
          backgroundColor: Colors.grey.shade200,
          child: const CircularProgressIndicator(strokeWidth: 2),
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
