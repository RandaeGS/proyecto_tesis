/// Modelo para representar un usuario del sistema
class User {
  final String email;
  final String? password; // Opcional, solo para creación
  final String name;
  final bool isSuperuser;
  final bool isStaff;
  final int? centerId; // ID del centro asignado (opcional)

  User({
    required this.email,
    this.password,
    required this.name,
    this.isSuperuser = false,
    this.isStaff = true,
    this.centerId,
  });

  /// Crea una instancia desde un mapa JSON
  factory User.fromJson(Map<String, dynamic> json) {
    // Manejar diferentes formatos de centerId
    int? parsedCenterId;

    if (json.containsKey('center_id')) {
      if (json['center_id'] is int) {
        parsedCenterId = json['center_id'];
      } else if (json['center_id'] is String && json['center_id'].isNotEmpty) {
        parsedCenterId = int.tryParse(json['center_id']);
      }
    }

    return User(
      email: json['email'] as String,
      name: json['name'] as String? ?? '',
      isSuperuser: json['is_superuser'] as bool? ?? false,
      isStaff: json['is_staff'] as bool? ?? true,
      centerId: parsedCenterId,
    );
  }

  /// Convierte la instancia a un mapa JSON
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'email': email,
      'name': name,
      'is_superuser': isSuperuser,
      'is_staff': isStaff,
    };

    // Solo incluir password si está presente
    if (password != null && password!.isNotEmpty) {
      data['password'] = password;
    }

    // Solo incluir centerId si está presente
    if (centerId != null) {
      data['center_id'] = centerId;
    }

    return data;
  }

  /// Crea una copia de este usuario con los campos especificados actualizados
  User copyWith({
    String? email,
    String? password,
    String? name,
    bool? isSuperuser,
    bool? isStaff,
    int? centerId,
  }) {
    return User(
      email: email ?? this.email,
      password: password ?? this.password,
      name: name ?? this.name,
      isSuperuser: isSuperuser ?? this.isSuperuser,
      isStaff: isStaff ?? this.isStaff,
      centerId: centerId ?? this.centerId,
    );
  }

  @override
  String toString() => 'User(email: $email, name: $name, isSuperuser: $isSuperuser, isStaff: $isStaff, centerId: $centerId)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is User &&
        other.email == email &&
        other.name == name &&
        other.isSuperuser == isSuperuser &&
        other.isStaff == isStaff;
  }

  @override
  int get hashCode => email.hashCode ^ name.hashCode ^ isSuperuser.hashCode ^ isStaff.hashCode;
}