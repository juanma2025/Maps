import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:latlong2/latlong.dart';
import '../models/place.dart';
import '../models/app_route.dart';

class SupabaseService {
  SupabaseClient? get _client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  bool get isConfigured => _client != null;

  User? get currentUser => _client?.auth.currentUser;

  Future<AuthResponse> signUp(String email, String password) async {
    if (!isConfigured) {
      throw Exception('Supabase no configurado');
    }
    return await _client!.auth.signUp(email: email, password: password);
  }

  Future<AuthResponse> signIn(String email, String password) async {
    if (!isConfigured) {
      throw Exception('Supabase no configurado');
    }
    return await _client!.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    if (!isConfigured) return;
    await _client!.auth.signOut();
  }

  Future<List<Place>> fetchPlaces({String? type}) async {
    if (!isConfigured) return [];
    var query = _client!.from('places').select('*').order('created_at', ascending: false);
    if (type != null && type.isNotEmpty) {
      query = _client!.from('places').select('*').eq('type', type).order('created_at', ascending: false);
    }
    final List<dynamic> data = await query;
    return data.map((e) => Place.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<Place> addPlace({
    required String type,
    required String name,
    required double lat,
    required double lng,
    required int rating,
  }) async {
    if (!isConfigured) {
      throw Exception('Supabase no configurado');
    }
    final user = currentUser;
    if (user == null) {
      throw Exception('Debes iniciar sesión para crear lugares');
    }
    final insert = {
      'type': type,
      'name': name,
      'lat': lat,
      'lng': lng,
      'rating': rating,
      'user_id': user.id,
    };
    final Map<String, dynamic> res = await _client!.from('places').insert(insert).select().single();
    return Place.fromMap(res);
  }

  Future<void> deletePlace(String placeId) async {
    if (!isConfigured) {
      throw Exception('Supabase no configurado');
    }
    final user = currentUser;
    if (user == null) {
      throw Exception('Debes iniciar sesión para eliminar lugares');
    }
    
    // Verificar que el lugar pertenece al usuario actual
    final place = await _client!
        .from('places')
        .select('user_id')
        .eq('id', placeId)
        .single();
    
    if (place['user_id'] != user.id) {
      throw Exception('No tienes permisos para eliminar este lugar');
    }
    
    await _client!.from('places').delete().eq('id', placeId);
  }

  Future<List<AppRouteModel>> fetchRoutes() async {
    if (!isConfigured) return [];
    final List<dynamic> data = await _client!.from('routes').select('*').order('created_at', ascending: false);
    return data
        .map((e) => AppRouteModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<AppRouteModel> addRoute({
    required String name,
    required List<LatLng> points,
  }) async {
    if (!isConfigured) {
      throw Exception('Supabase no configurado');
    }
    final user = currentUser;
    if (user == null) {
      throw Exception('Debes iniciar sesión para guardar rutas');
    }
    final insert = {
      'name': name,
      'user_id': user.id,
      'coordinates': points
          .map((p) => {
                'lat': p.latitude,
                'lng': p.longitude,
              })
          .toList(),
    };
    final Map<String, dynamic> res = await _client!.from('routes').insert(insert).select().single();
    return AppRouteModel.fromMap(res);
  }
}