class Court {
  final String id;
  final String name;
  final String category;
  final String? description;
  final String? rules;
  final String? imageUrl;
  final int priceCents;
  final int slotMinutes;
  final String openingTime;
  final String closingTime;
  final List<int> openDays;

  Court({
    required this.id,
    required this.name,
    required this.category,
    this.description,
    this.rules,
    this.imageUrl,
    required this.priceCents,
    required this.slotMinutes,
    required this.openingTime,
    required this.closingTime,
    required this.openDays,
  });

  factory Court.fromJson(Map<String, dynamic> json) {
    return Court(
      id: json['id'],
      name: json['name'],
      category: json['category'],
      description: json['description'],
      rules: json['rules'],
      imageUrl: json['image_url'],
      priceCents: json['price_cents'],
      slotMinutes: json['slot_minutes'],
      openingTime: json['opening_time'],
      closingTime: json['closing_time'],
      openDays: List<int>.from(json['open_days'] ?? []),
    );
  }
}
