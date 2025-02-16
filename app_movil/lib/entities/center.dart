class Center {
  final String name;
  final String address;

  Center({required this.name, required this.address});

  factory Center.fromJson(Map<String, dynamic> json) {
    return Center(
      name: json['name'],
      address: json['address'],
    );
  }
}
