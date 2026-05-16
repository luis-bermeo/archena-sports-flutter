import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../models/court.dart';
import '../widgets/glass_container.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final _supabase = Supabase.instance.client;
  List<Court> _courts = [];
  List<Map<String, dynamic>> _blocks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final courtsData = await _supabase.from('courts').select().eq('active', true).order('name');
      final blocksData = await _supabase.from('court_blocks').select('*, courts(name)').order('blocked_date', ascending: false);

      setState(() {
        _courts = (courtsData as List).map((c) => Court.fromJson(c)).toList();
        _blocks = List<Map<String, dynamic>>.from(blocksData);
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addBlock() async {
    Court? selectedCourt;
    DateTime? selectedDate = DateTime.now();
    final reasonCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF0F172A),
              title: const Text('Bloquear Pista', style: TextStyle(color: Colors.white)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<Court>(
                      dropdownColor: const Color(0xFF0F172A),
                      items: _courts.map((c) => DropdownMenuItem(value: c, child: Text(c.name, style: const TextStyle(color: Colors.white)))).toList(),
                      onChanged: (v) => setDialogState(() => selectedCourt = v),
                      decoration: const InputDecoration(labelText: 'Pista', labelStyle: TextStyle(color: Colors.white70)),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Text('Fecha:', style: TextStyle(color: Colors.white)),
                        const Spacer(),
                        TextButton(
                          onPressed: () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: selectedDate!,
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (d != null) setDialogState(() => selectedDate = d);
                          },
                          child: Text(DateFormat('dd/MM/yyyy').format(selectedDate!), style: const TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: reasonCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'Motivo (opcional)', labelStyle: TextStyle(color: Colors.white70)),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                ElevatedButton(
                  onPressed: () async {
                    if (selectedCourt == null) return;
                    Navigator.pop(context);
                    final userId = Provider.of<AuthProvider>(this.context, listen: false).user!.id;
                    try {
                      await _supabase.from('court_blocks').insert({
                        'court_id': selectedCourt!.id,
                        'blocked_date': DateFormat('yyyy-MM-dd').format(selectedDate!),
                        'reason': reasonCtrl.text,
                        'created_by': userId,
                      });
                      _fetchData();
                    } catch (e) {
                      ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          }
        );
      },
    );
  }

  Future<void> _removeBlock(String id) async {
    try {
      await _supabase.from('court_blocks').delete().eq('id', id);
      _fetchData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel Admin', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: _addBlock),
        ],
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
              : _blocks.isEmpty
                  ? const Center(child: Text('No hay pistas bloqueadas', style: TextStyle(color: Colors.white70)))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _blocks.length,
                      itemBuilder: (context, index) {
                        final b = _blocks[index];
                        return GlassContainer(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(b['courts']['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text('Fecha: ${DateFormat('dd/MM/yyyy').format(DateTime.parse(b['blocked_date']))}', style: const TextStyle(color: Colors.white70)),
                                if (b['reason'] != null && b['reason'].toString().isNotEmpty)
                                  Text('Motivo: ${b['reason']}', style: const TextStyle(color: Colors.white50)),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.redAccent),
                              onPressed: () => _removeBlock(b['id']),
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ),
    );
  }
}
