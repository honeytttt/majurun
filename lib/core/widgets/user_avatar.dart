import 'package:flutter/material.dart';

import 'user_avatar_impl.dart'
  if (dart.library.html) 'user_avatar_web.dart'
  if (dart.library.io) 'user_avatar_io.dart';

class UserAvatar extends StatelessWidget {
  final String photoUrl;
  final double radius;

  const UserAvatar({
    super.key,
    required this.photoUrl,
    this.radius = 24,
  });

  @override
  Widget build(BuildContext context) {
    return buildUserAvatar(photoUrl: photoUrl, radius: radius);
  }
}