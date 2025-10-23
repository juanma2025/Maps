import 'package:latlong2/latlong.dart';

class Place {
  final String id;
  final String type;
  final String name;
  final double lat;
  final double lng;
  final int rating;
  final String userId;
  final DateTime createdAt;

  Place({
    required this.id,
    required this.type,
    required this.name,
    required this.lat,
    required this.lng,
    required this.rating,
    required this.userId,
    required this.createdAt,
  });

  LatLng get latLng => LatLng(lat, lng);

  factory Place.fromMap(Map<String, dynamic> map) {
    return Place(
      id: map['id']?.toString() ?? '',
      type: map['type'] ?? 'otro',
      name: map['name'] ?? '',
      lat: (map['lat'] as num).toDouble(),
      lng: (map['lng'] as num).toDouble(),
      rating: (map['rating'] as num?)?.toInt() ?? 0,
      userId: map['user_id']?.toString() ?? '',
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'type': type,
      'name': name,
      'lat': lat,
      'lng': lng,
      'rating': rating,
      'user_id': userId,
    };
  }
}