class User {
  final String email;
  final String? password;  // Hacemos password opcional
  final String name;      // Name no debería ser null ya que siempre viene en la respuesta
  final bool isSuperuser;
  final bool isStaff;

  User({
    required this.email,
    this.password,       // Password opcional
    required this.name,  // Name requerido
    this.isSuperuser = true,
    this.isStaff = true,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      email: json['email'] as String,
      name: json['name'] as String,
      isSuperuser: json['is_superuser'] as bool,
      isStaff: json['is_staff'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'name': name,
      'is_superuser': isSuperuser,
      'is_staff': isStaff,
    };
  }
}