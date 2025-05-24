class Center {
  final int id;
  final String name;
  final String address;

  Center({
    required this.id,
    required this.name,
    required this.address,
  });

  factory Center.fromJson(Map<String, dynamic> json) {
    return Center(
      id: json['id'] is String ? int.parse(json['id']) : json['id'] as int,
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

  Center copyWith({
    int? id,
    String? name,
    String? address,
  }) {
    return Center(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
    );
  }

  @override
  String toString() => 'Center(id: $id, name: $name, address: $address)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Center &&
        other.id == id &&
        other.name == name &&
        other.address == address;
  }

  @override
  int get hashCode => id.hashCode ^ name.hashCode ^ address.hashCode;
}