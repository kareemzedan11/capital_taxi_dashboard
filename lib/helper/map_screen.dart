import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:latlong2/latlong.dart';

class MapScreen extends StatefulWidget {
  final String polylinePoints;

  MapScreen({required this.polylinePoints});

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final mapController = MapController();
  PolylinePoints polylinePoints = PolylinePoints();
  List<LatLng> routePoints = [];
  LatLng? startLocation;
  LatLng? endLocation;

  @override
  void initState() {
    super.initState();
    _decodePolyline();
  }

  void _decodePolyline() {
    try {
      List<PointLatLng> result = polylinePoints.decodePolyline(widget.polylinePoints);
      if (result.isNotEmpty) {
        routePoints = result.map((p) => LatLng(p.latitude, p.longitude)).toList();
        startLocation = routePoints.first;
        endLocation = routePoints.last;

        // تحريك الكاميرا على منتصف الرحلة
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final center = LatLng(
            (startLocation!.latitude + endLocation!.latitude) / 2,
            (startLocation!.longitude + endLocation!.longitude) / 2,
          );
          mapController.move(center, 13);
        });

        setState(() {});
      }
    } catch (e) {
      print('Error decoding polyline: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('مسار الرحلة')),
      body: FlutterMap(
        mapController: mapController,
        options: MapOptions(
          initialCenter: startLocation ?? LatLng(24.7136, 46.6753), // الرياض
          initialZoom: 12,
        ),
        children: [
          TileLayer(
            urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
            subdomains: ['a', 'b', 'c'],
            userAgentPackageName: 'com.example.app',
          ),
          if (routePoints.isNotEmpty)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: routePoints,
                  strokeWidth: 4.0,
                  color: Colors.blue,
                ),
              ],
            ),
     MarkerLayer(
  markers: [
    if (startLocation != null)
      Marker(
        point: startLocation!,
        width: 40,
        height: 40,
        child: Icon(Icons.location_on, color: Colors.green, size: 40),
      ),
    if (endLocation != null)
      Marker(
        point: endLocation!,
        width: 40,
        height: 40,
        child: Icon(Icons.flag, color: Colors.red, size: 40),
      ),
  ],
),

        ],
      ),
    );
  }
}
