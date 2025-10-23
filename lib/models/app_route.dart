import 'package:latlong2/latlong.dart';

class AppRouteModel {
  final String id;
  final String userId;
  final String name;
  final List<LatLng> coordinates;
  final DateTime createdAt;

  AppRouteModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.coordinates,
    required this.createdAt,
  });

  factory AppRouteModel.fromMap(Map<String, dynamic> map) {
    final coords = (map['coordinates'] as List?)
            ?.map((e) => LatLng((e['lat'] as num).toDouble(), (e['lng'] as num).toDouble()))
            .toList() ??
        const <LatLng>[];
    return AppRouteModel(
      id: map['id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      name: map['name'] ?? '',
      coordinates: coords,
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'name': name,
      'user_id': userId,
      'coordinates': coordinates
          .map((p) => {
                'lat': p.latitude,
                'lng': p.longitude,
              })
          .toList(),
    };
  }
}