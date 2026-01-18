import 'package:equatable/equatable.dart';

class AppUser extends Equatable {
  final String uid;
  final String email;
  final String? firstName;
  final String? lastName;
  final String? displayName;
  final String? photoUrl;
  final DateTime? dob;
  final String? gender;
  final String? phoneNumber;
  final bool isGuest;

  const AppUser({
    required this.uid,
    required this.email,
    this.firstName,
    this.lastName,
    this.displayName,
    this.photoUrl,
    this.dob,
    this.gender,
    this.phoneNumber,
    this.isGuest = false,
  });

  @override
  List<Object?> get props => [
        uid, email, firstName, lastName, displayName, 
        photoUrl, dob, gender, phoneNumber, isGuest,
      ];
}