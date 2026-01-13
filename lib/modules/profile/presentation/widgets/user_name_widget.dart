import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/profile_repository.dart';

class UserNameWidget extends StatelessWidget {
  final String userId;
  final TextStyle? style;

  const UserNameWidget({super.key, required this.userId, this.style});

  @override
  Widget build(BuildContext context) {
    final profileRepo = context.read<ProfileRepository>();
    
    return StreamBuilder<UserEntity?>(
      stream: profileRepo.streamUser(userId),
      builder: (context, snapshot) {
        // While loading or if data is missing, show a placeholder
        if (!snapshot.hasData || snapshot.data == null) {
          return Text("Maju Runner", style: style?.copyWith(color: Colors.grey));
        }
        
        return Text(
          snapshot.data!.displayName,
          style: style,
        );
      },
    );
  }
}