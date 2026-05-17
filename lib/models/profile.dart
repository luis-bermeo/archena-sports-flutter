class Profile {
  final String id;
  final String? email;
  final String? fullName;
  final String? dni;
  final String? fechaNacimiento;
  final bool esResidente;

  Profile({
    required this.id,
    this.email,
    this.fullName,
    this.phone,
    this.dni,
    this.fechaNacimiento,
    required this.esResidente,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'],
      email: json['email'],
      fullName: json['full_name'],
      phone: json['phone'],
      dni: json['dni'],
      fechaNacimiento: json['fecha_nacimiento'],
      esResidente: json['es_residente'] ?? false,
    );
  }
}
