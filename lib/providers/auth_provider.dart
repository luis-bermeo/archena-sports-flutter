import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile.dart';

class AuthProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;
  User? _user;
  Profile? _profile;
  bool _isLoading = true;
  bool _isAdmin = false;

  User? get user => _user;
  Profile? get profile => _profile;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;
  bool get isAdmin => _isAdmin;

  AuthProvider() {
    _init();
  }

  Future<void> _init() async {
    _user = _supabase.auth.currentUser;
    _supabase.auth.onAuthStateChange.listen((data) {
      _user = data.session?.user;
      _fetchProfile();
    });
    if (_user != null) {
      await _fetchProfile();
    } else {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _fetchProfile() async {
    if (_user == null) {
      _profile = null;
      _isAdmin = false;
      _isLoading = false;
      notifyListeners();
      return;
    }
    try {
      final data = await _supabase
          .from('profiles')
          .select()
          .eq('id', _user!.id)
          .single();
      _profile = Profile.fromJson(data);

      // Check admin role
      final rolesData = await _supabase
          .from('user_roles')
          .select('role')
          .eq('user_id', _user!.id);
      
      _isAdmin = rolesData.any((r) => r['role'] == 'admin' || r['role'] == 'staff');
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching profile: $e');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signIn(String email, String password) async {
    await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signUp(String email, String password, String nombre, String apellidos, String dni, String fechaNacimiento) async {
    final response = await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': '$nombre $apellidos'},
    );
    if (response.user != null) {
      // Creamos el perfil manualmente por si no hay un trigger en la base de datos
      try {
        await _supabase.from('profiles').upsert({
          'id': response.user!.id,
          'full_name': '$nombre $apellidos',
          'dni': dni,
          'fecha_nacimiento': fechaNacimiento,
          'es_residente': false,
        });
      } catch (e) {
        if (kDebugMode) {
          print('Error creando perfil manual: $e');
        }
      }
    }
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }
}
