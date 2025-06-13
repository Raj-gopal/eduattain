class UserModel {
  final String uid;
  final String name;
  final String email;
  final String role;
  final bool isApproved;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.isApproved,
  });

  factory UserModel.fromMap(Map<String, dynamic> data) {
    return UserModel(
      uid: data['uid'],
      name: data['name'],
      email: data['email'],
      role: data['role'],
      isApproved: data['isApproved'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'role': role,
      'isApproved': isApproved,
    };
  }
}
