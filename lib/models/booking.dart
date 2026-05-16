class Booking {
  final String id;
  final String courtId;
  final String userId;
  final String bookingDate;
  final String startTime;
  final String endTime;
  final int priceCents;
  final bool residentDiscount;
  final String status;
  final String qrToken;

  Booking({
    required this.id,
    required this.courtId,
    required this.userId,
    required this.bookingDate,
    required this.startTime,
    required this.endTime,
    required this.priceCents,
    required this.residentDiscount,
    required this.status,
    required this.qrToken,
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    return Booking(
      id: json['id'],
      courtId: json['court_id'],
      userId: json['user_id'],
      bookingDate: json['booking_date'],
      startTime: json['start_time'],
      endTime: json['end_time'],
      priceCents: json['price_cents'],
      residentDiscount: json['resident_discount'] ?? false,
      status: json['status'],
      qrToken: json['qr_token'] ?? '',
    );
  }
}
