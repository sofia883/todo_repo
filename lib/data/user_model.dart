class UserModel {
  final String uid;
  final String email;
  final String? name;
  final String? photoUrl;

  UserModel({
    required this.uid,
    required this.email,
    this.name,
    this.photoUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'photoUrl': photoUrl,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'],
      email: map['email'],
      name: map['name'],
      photoUrl: map['photoUrl'],
    );
  }
}