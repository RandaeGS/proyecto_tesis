// lib/entities/center.dart
class Center {
  final int id;      // Cambiamos de String a int y aseguramos que existe
  final String name;
  final String address;

  Center({
    required this.id,
    required this.name,
    required this.address
  });

  factory Center.fromJson(Map<String, dynamic> json) {
    return Center(
      id: json['id'] as int,
      name: json['name'] ?? '',
      address: json['address'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
    };
  }
}
