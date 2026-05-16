class Profile {
  final String id;
  final String? email;
  final String? fullName;
  final String? phone;
  final bool esResidente;

  Profile({
    required this.id,
    this.email,
    this.fullName,
    this.phone,
    required this.esResidente,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'],
      email: json['email'],
      fullName: json['full_name'],
      phone: json['phone'],
      esResidente: json['es_residente'] ?? false,
    );
  }
}
