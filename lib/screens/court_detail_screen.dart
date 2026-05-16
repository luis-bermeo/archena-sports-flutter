import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:math';

import '../providers/auth_provider.dart';
import '../models/court.dart';
import '../widgets/glass_container.dart';

class CourtDetailScreen extends StatefulWidget {
  const CourtDetailScreen({super.key});

  @override
  State<CourtDetailScreen> createState() => _CourtDetailScreenState();
}

class _CourtDetailScreenState extends State<CourtDetailScreen> {
  final _supabase = Supabase.instance.client;
  Court? _court;
  DateTime _selectedDate = DateTime.now();
  String? _selectedSlotStart;
  String? _selectedSlotEnd;
  List<String> _busySlots = [];
  List<String> _blockedDates = [];
  bool _isLoading = true;
  String? _qrToken;
  String _step = 'select'; // select, summary, done

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_court == null) {
      _court = ModalRoute.of(context)!.settings.arguments as Court;
      _fetchAvailability();
    }
  }

  Future<void> _fetchAvailability() async {
    setState(() => _isLoading = true);
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    try {
      // Fetch bookings for this date
      final busyData = await _supabase
          .from('bookings')
          .select('start_time')
          .eq('court_id', _court!.id)
          .eq('booking_date', dateStr)
          .eq('status', 'confirmed');
      
      // Fetch blocks
      final blockData = await _supabase
          .from('court_blocks')
          .select('blocked_date')
          .eq('court_id', _court!.id);

      setState(() {
        _busySlots = (busyData as List).map((b) => b['start_time'].toString()).toList();
        _blockedDates = (blockData as List).map((b) => b['blocked_date'].toString()).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, String>> _generateSlots() {
    if (_court == null) return [];
    List<Map<String, String>> slots = [];
    final openParts = _court!.openingTime.split(':').map(int.parse).toList();
    final closeParts = _court!.closingTime.split(':').map(int.parse).toList();
    
    int cur = openParts[0] * 60 + openParts[1];
    int end = closeParts[0] * 60 + closeParts[1];
    
    while (cur + _court!.slotMinutes <= end) {
      int e = cur + _court!.slotMinutes;
      String fmt(int m) => '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}:00';
      slots.add({'start': fmt(cur), 'end': fmt(e)});
      cur = e;
    }
    return slots;
  }

  Future<void> _confirmBooking() async {
    if (_selectedSlotStart == null || _selectedSlotEnd == null) return;
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isResident = authProvider.profile?.esResidente ?? false;
    final finalPrice = isResident ? (_court!.priceCents * 0.8).round() : _court!.priceCents;
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

    try {
      final response = await _supabase.from('bookings').insert({
        'court_id': _court!.id,
        'user_id': authProvider.user!.id,
        'booking_date': dateStr,
        'start_time': _selectedSlotStart,
        'end_time': _selectedSlotEnd,
        'price_cents': finalPrice,
        'resident_discount': isResident,
      }).select('qr_token').single();

      setState(() {
        _qrToken = response['qr_token'];
        _step = 'done';
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_court == null) return const Scaffold();

    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final isBlocked = _blockedDates.contains(dateStr);
    
    int dow = _selectedDate.weekday; // 1 = Mon, 7 = Sun
    final isOpenDay = _court!.openDays.contains(dow);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF004A98)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            if (_court!.imageUrl != null)
              Image.network(_court!.imageUrl!, height: 250, width: double.infinity, fit: BoxFit.cover),
            if (_court!.imageUrl == null)
              Container(height: 250, color: Colors.black26, child: const Center(child: Icon(Icons.sports, size: 80, color: Colors.white50))),
            
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GlassContainer(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_court!.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                          const SizedBox(height: 8),
                          Text('${_court!.slotMinutes} min | ${(_court!.priceCents / 100).toStringAsFixed(2)} €', style: const TextStyle(color: Colors.white70)),
                          if (_court!.description != null) ...[
                            const SizedBox(height: 12),
                            Text(_court!.description!, style: const TextStyle(color: Colors.white)),
                          ]
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    if (_step == 'select') ...[
                      // Select Date
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Fecha:', style: TextStyle(color: Colors.white, fontSize: 16)),
                          ElevatedButton.icon(
                            onPressed: () async {
                              final d = await showDatePicker(
                                context: context,
                                initialDate: _selectedDate,
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(const Duration(days: 14)),
                              );
                              if (d != null) {
                                setState(() {
                                  _selectedDate = d;
                                  _selectedSlotStart = null;
                                });
                                _fetchAvailability();
                              }
                            },
                            icon: const Icon(Icons.calendar_month),
                            label: Text(DateFormat('dd/MM/yyyy').format(_selectedDate)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      if (_isLoading)
                        const Center(child: CircularProgressIndicator(color: Colors.white))
                      else if (!isOpenDay)
                        const Center(child: Text('Cerrado en este día de la semana', style: TextStyle(color: Colors.redAccent)))
                      else if (isBlocked)
                        const Center(child: Text('Pista bloqueada por mantenimiento', style: TextStyle(color: Colors.redAccent)))
                      else
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: _generateSlots().map((s) {
                            final isTaken = _busySlots.contains(s['start']);
                            final isSelected = _selectedSlotStart == s['start'];
                            return ChoiceChip(
                              label: Text(s['start']!.substring(0, 5)),
                              selected: isSelected,
                              onSelected: isTaken ? null : (v) {
                                setState(() {
                                  _selectedSlotStart = s['start'];
                                  _selectedSlotEnd = s['end'];
                                });
                              },
                              selectedColor: Colors.white,
                              disabledColor: Colors.white10,
                              labelStyle: TextStyle(
                                color: isSelected ? const Color(0xFF004A98) : (isTaken ? Colors.grey : Colors.white),
                                decoration: isTaken ? TextDecoration.lineThrough : null,
                              ),
                              backgroundColor: Colors.white24,
                            );
                          }).toList(),
                        ),
                      
                      const SizedBox(height: 30),
                      ElevatedButton(
                        onPressed: _selectedSlotStart == null ? null : () => setState(() => _step = 'summary'),
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                        child: const Text('Continuar', style: TextStyle(fontSize: 18)),
                      )
                    ] else if (_step == 'summary') ...[
                      GlassContainer(
                        child: Column(
                          children: [
                            const Text('Resumen de Reserva', style: TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold)),
                            const Divider(color: Colors.white24),
                            ListTile(title: const Text('Pista', style: TextStyle(color: Colors.white70)), trailing: Text(_court!.name, style: const TextStyle(color: Colors.white))),
                            ListTile(title: const Text('Fecha', style: TextStyle(color: Colors.white70)), trailing: Text(DateFormat('dd/MM/yyyy').format(_selectedDate), style: const TextStyle(color: Colors.white))),
                            ListTile(title: const Text('Hora', style: TextStyle(color: Colors.white70)), trailing: Text('${_selectedSlotStart!.substring(0,5)} - ${_selectedSlotEnd!.substring(0,5)}', style: const TextStyle(color: Colors.white))),
                            
                            Builder(builder: (c) {
                              final isRes = Provider.of<AuthProvider>(context).profile?.esResidente ?? false;
                              final fPrice = isRes ? (_court!.priceCents * 0.8).round() : _court!.priceCents;
                              return Column(
                                children: [
                                  if (isRes) const ListTile(title: Text('Descuento Residente', style: TextStyle(color: Colors.greenAccent)), trailing: Text('-20%', style: TextStyle(color: Colors.greenAccent))),
                                  ListTile(title: const Text('Total', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), trailing: Text('${(fPrice / 100).toStringAsFixed(2)} €', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))),
                                ],
                              );
                            }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _confirmBooking,
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                        child: const Text('Confirmar y Pagar', style: TextStyle(fontSize: 18)),
                      ),
                      TextButton(
                        onPressed: () => setState(() => _step = 'select'),
                        child: const Text('Volver', style: TextStyle(color: Colors.white)),
                      )
                    ] else if (_step == 'done' && _qrToken != null) ...[
                      GlassContainer(
                        child: Column(
                          children: [
                            const Text('¡Reserva Confirmada!', style: TextStyle(fontSize: 22, color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 20),
                            Container(
                              padding: const EdgeInsets.all(16),
                              color: Colors.white,
                              child: QrImageView(
                                data: _qrToken!,
                                version: QrVersions.auto,
                                size: 200.0,
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text('Muestra este QR en el acceso.', style: TextStyle(color: Colors.white70), textAlign: TextAlign.center),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () => Navigator.popUntil(context, ModalRoute.withName('/home')),
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                        child: const Text('Volver al Inicio', style: TextStyle(fontSize: 18)),
                      )
                    ]
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
