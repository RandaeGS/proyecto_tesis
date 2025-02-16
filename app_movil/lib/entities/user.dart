class User {
  final String email;
  final String password;
  final String? name;

  User({
    required this.email,
    required this.password,
    this.name,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      email: json['email'],
      password: json['password'],
      name: json['name'],
    );
  }
}