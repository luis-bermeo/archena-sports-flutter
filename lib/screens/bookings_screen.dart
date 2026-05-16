import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../models/booking.dart';
import '../widgets/glass_container.dart';

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  final _supabase = Supabase.instance.client;
  List<Booking> _bookings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchBookings();
  }

  Future<void> _fetchBookings() async {
    final userId = Provider.of<AuthProvider>(context, listen: false).user?.id;
    if (userId == null) return;
    
    try {
      final data = await _supabase
          .from('bookings')
          .select()
          .eq('user_id', userId)
          .order('booking_date', ascending: false);

      setState(() {
        _bookings = (data as List).map((b) => Booking.fromJson(b)).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cancelBooking(String bookingId) async {
    try {
      await _supabase.from('bookings').update({'status': 'cancelled'}).eq('id', bookingId);
      _fetchBookings();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Reservas', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF004A98)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : _bookings.isEmpty
                  ? const Center(child: Text('No tienes reservas', style: TextStyle(color: Colors.white70)))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _bookings.length,
                      itemBuilder: (context, index) {
                        final b = _bookings[index];
                        final isCancelled = b.status == 'cancelled';
                        return GlassContainer(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    DateFormat('dd/MM/yyyy').format(DateTime.parse(b.bookingDate)),
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isCancelled ? Colors.redAccent.withOpacity(0.2) : Colors.greenAccent.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      b.status.toUpperCase(),
                                      style: TextStyle(
                                        color: isCancelled ? Colors.redAccent : Colors.greenAccent,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text('${b.startTime.substring(0,5)} - ${b.endTime.substring(0,5)}', style: const TextStyle(color: Colors.white70)),
                              const SizedBox(height: 16),
                              if (!isCancelled)
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton(
                                    onPressed: () => _cancelBooking(b.id),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.redAccent,
                                      side: const BorderSide(color: Colors.redAccent),
                                    ),
                                    child: const Text('Cancelar Reserva'),
                                  ),
                                )
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ),
    );
  }
}
