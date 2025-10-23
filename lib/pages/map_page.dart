import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/supabase_service.dart';
import '../models/place.dart';
import '../models/app_route.dart';
import 'login_page.dart';

const defaultCenter = LatLng(1.2068832313599385, -77.28726331962979); 

const kPlaceTypes = <String>['cafe', 'parque', 'mirador', 'otro'];

IconData iconForType(String type) {
  switch (type) {
    case 'cafe':
      return Icons.local_cafe;
    case 'parque':
      return Icons.park;
    case 'mirador':
      return Icons.landscape;
    default:
      return Icons.location_on;
  }
}

class MapPage extends StatefulWidget {
  final bool supabaseConfigured;
  const MapPage({super.key, required this.supabaseConfigured});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final svc = SupabaseService();
  final MapController _controller = MapController();
  List<Place> _places = [];
  List<AppRouteModel> _routes = [];
  Set<String> _filters = {};

  // Ruta en construcción
  bool _routeMode = false;
  final List<LatLng> _routePoints = [];

  bool _loading = false;
  String? _error;

  String _placeTooltip(Place p) {
    return '${p.name}\nTipo: ${p.type}\nCalificación: ${p.rating}\nLat: ${p.lat.toStringAsFixed(6)}  Lng: ${p.lng.toStringAsFixed(6)}';
  }

  Future<void> _deletePlace(Place place) async {
    if (!widget.supabaseConfigured || svc.currentUser == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes iniciar sesión para eliminar lugares')),
      );
      return;
    }

    // Verificar que el lugar pertenece al usuario actual
    if (place.userId != svc.currentUser!.id) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solo puedes eliminar tus propios lugares')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar lugar'),
        content: Text('¿Estás seguro de que quieres eliminar "${place.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await svc.deletePlace(place.id);
        setState(() {
          _places.removeWhere((p) => p.id == place.id);
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lugar eliminado correctamente')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar: $e')),
        );
      }
    }
  }

  Future<void> _showHoverMenu(Place p, Offset globalPosition) async {
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        globalPosition.dx + 1,
        globalPosition.dy + 1,
      ),
      items: [
        PopupMenuItem<String>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                p.name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text('Tipo: ${p.type}'),
              Text('Calificación: ${p.rating}'),
              Text('Lat: ${p.lat.toStringAsFixed(6)}  Lng: ${p.lng.toStringAsFixed(6)}'),
            ],
          ),
        ),
        if (widget.supabaseConfigured && svc.currentUser != null && p.userId == svc.currentUser!.id)
          const PopupMenuItem<String>(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete, color: Colors.red, size: 18),
                SizedBox(width: 8),
                Text('Eliminar', style: TextStyle(color: Colors.red)),
              ],
            ),
          ),
      ],
    );

    if (selected == 'delete') {
      await _deletePlace(p);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final places = await svc.fetchPlaces();
      final routes = await svc.fetchRoutes();
      setState(() {
        _places = places;
        _routes = routes;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _onLongPress(TapPosition tapPos, LatLng latlng) async {
    await _showAddPlaceDialog(latlng);
  }

  void _onTapMap(TapPosition tp, LatLng latlng) {
    if (_routeMode) {
      setState(() {
        _routePoints.add(latlng);
      });
    }
  }

  List<Marker> _buildMarkers() {
    final filtered = _filters.isEmpty
        ? _places
        : _places.where((p) => _filters.contains(p.type)).toList();
    return filtered
        .map(
          (p) => Marker(
            point: p.latLng,
            width: 40,
            height: 40,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (e) => _showHoverMenu(p, e.position),
              child: GestureDetector(
                onTap: () {
                  if (_routeMode) {
                    setState(() {
                      _routePoints.add(p.latLng);
                    });
                  } else {
                    _showPlaceInfo(p);
                  }
                },
                child: Icon(iconForType(p.type), color: Colors.deepOrange, size: 32),
              ),
            ),
          ),
        )
        .toList();
  }

  List<Polyline> _buildPolylines() {
    final List<Polyline> lines = [];
    // Rutas persistidas
    for (final r in _routes) {
      if (r.coordinates.isNotEmpty) {
        lines.add(
          Polyline(points: r.coordinates, strokeWidth: 4, color: Colors.blueAccent.withValues(alpha: 0.6)),
        );
      }
    }
    // Ruta temporal
    if (_routePoints.length >= 2) {
      lines.add(
        Polyline(points: _routePoints, strokeWidth: 4, color: Colors.redAccent),
      );
    }
    return lines;
  }

  void _showPlaceInfo(Place p) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(iconForType(p.type)),
                const SizedBox(width: 8),
                Text(p.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Text('Tipo: ${p.type}'),
            Text('Rating: ${p.rating}'),
            Text('Lat: ${p.lat.toStringAsFixed(6)}  Lng: ${p.lng.toStringAsFixed(6)}'),
            const SizedBox(height: 8),
            Text('Creado por: ${p.userId}'),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddPlaceDialog(LatLng latlng) async {
    if (!widget.supabaseConfigured || svc.currentUser == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes iniciar sesión para agregar lugares')),
      );
      return;
    }

    final nameCtrl = TextEditingController();
    String type = kPlaceTypes.first;
    int rating = 3;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nuevo lugar favorito'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Lat: ${latlng.latitude.toStringAsFixed(6)}  Lng: ${latlng.longitude.toStringAsFixed(6)}'),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: type,
              items: kPlaceTypes
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (v) => type = v ?? type,
              decoration: const InputDecoration(labelText: 'Tipo'),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              initialValue: rating,
              items: [1, 2, 3, 4, 5]
                  .map((r) => DropdownMenuItem(value: r, child: Text('Calificación $r')))
                  .toList(),
              onChanged: (v) => rating = v ?? rating,
              decoration: const InputDecoration(labelText: 'Calificación'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar')),
        ],
      ),
    );

    if (saved == true) {
      try {
        final created = await svc.addPlace(
          type: type,
          name: nameCtrl.text.trim(),
          lat: latlng.latitude,
          lng: latlng.longitude,
          rating: rating,
        );
        setState(() {
          _places.insert(0, created);
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lugar guardado')));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _saveRoute() async {
    if (!widget.supabaseConfigured || svc.currentUser == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes iniciar sesión para guardar rutas')),
      );
      return;
    }
    if (_routePoints.length < 2) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agrega al menos 2 puntos a la ruta')),
      );
      return;
    }
    final nameCtrl = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Guardar ruta'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(labelText: 'Nombre de la ruta'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar')),
        ],
      ),
    );
    if (saved == true) {
      try {
        final created = await svc.addRoute(name: nameCtrl.text.trim(), points: _routePoints);
        setState(() {
          _routes.insert(0, created);
          _routePoints.clear();
          _routeMode = false;
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ruta guardada')));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  List<Widget> _buildFilterChips() {
    return kPlaceTypes
        .map((t) => FilterChip(
              label: Text(t),
              selected: _filters.contains(t),
              onSelected: (v) {
                setState(() {
                  if (v) {
                    _filters.add(t);
                  } else {
                    _filters.remove(t);
                  }
                });
              },
            ))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final user = svc.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('MyFavoriteMap'),
        actions: [
          if (widget.supabaseConfigured && user != null)
            IconButton(
              onPressed: () async {
                await svc.signOut();
                if (!mounted) return;
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                );
              },
              icon: const Icon(Icons.logout),
              tooltip: 'Salir',
            ),
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
          )
        ],
      ),
      body: Column(
        children: [
          if (!widget.supabaseConfigured)
            Container(
              width: double.infinity,
              color: Colors.orange.shade100,
              padding: const EdgeInsets.all(8),
              child: const Text(
                'Supabase no configurado. El mapa funciona sin backend, pero no podrás guardar lugares o rutas.',
                textAlign: TextAlign.center,
              ),
            ),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            Container(
              width: double.infinity,
              color: Colors.red.shade100,
              padding: const EdgeInsets.all(8),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          // Filtros por tipo
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(children: _buildFilterChips()),
          ),
          Expanded(
            child: FlutterMap(
              mapController: _controller,
              options: MapOptions(
                initialCenter: defaultCenter,
                initialZoom: 13.0,
                onLongPress: _onLongPress,
                onTap: _onTapMap,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.myfavoritemap',
                ),
                MarkerLayer(markers: _buildMarkers()),
                PolylineLayer(polylines: _buildPolylines()),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            onPressed: () {
              if (!widget.supabaseConfigured || user == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Debes iniciar sesión para dibujar/guardar rutas')),
                );
                return;
              }
              setState(() {
                _routeMode = !_routeMode;
                if (!_routeMode) _routePoints.clear();
              });
            },
            label: Text(_routeMode ? 'Salir modo ruta' : 'Entrar modo ruta'),
            icon: Icon(_routeMode ? Icons.route : Icons.edit_location_alt),
          ),
          const SizedBox(height: 10),
          if (_routeMode)
            FloatingActionButton.extended(
              onPressed: () {
                if (!widget.supabaseConfigured || user == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Debes iniciar sesión para guardar rutas')),
                  );
                  return;
                }
                _saveRoute();
              },
              label: const Text('Guardar ruta'),
              icon: const Icon(Icons.save),
              backgroundColor: Colors.green,
            ),
        ],
      ),
    );
  }
}