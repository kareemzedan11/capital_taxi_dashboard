import 'dart:convert';
import 'package:capitaltaxi/AnalyticsDashboard/AnalyticsDashboard.dart';
import 'package:capitaltaxi/ComplaintsManagement/ComplaintsManagementApp%20.dart';
import 'package:capitaltaxi/DriversPage.dart';
import 'package:capitaltaxi/NotficationPage.dart';
import 'package:capitaltaxi/PassengerManagementScreen/PassengerManagementScreen.dart';
import 'package:capitaltaxi/PricingZoneManagement/PricingZoneManagement.dart';
import 'package:capitaltaxi/TripManagementDashboard.dart';
import 'package:capitaltaxi/Trips.dart';
import 'package:capitaltaxi/messageManagment/messageManagment.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://mwncdoelxuwhtlrvtnap.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im13bmNkb2VseHV3aHRscnZ0bmFwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDUwMjU4NjUsImV4cCI6MjA2MDYwMTg2NX0.f5Zlz_WSLypyCUn67g2PEA5ZjHa8VsqjJDbxIgtBBTk',
  );
  
 try {
  await Firebase.initializeApp(
    options: FirebaseOptions(
      apiKey: "AIzaSyB4wiUvOp2Lm5UMzNYAjIgKNrjMRKki0QU",
      appId: "1:427656484093:android:ea68129f0b03e3edb29a94",
      messagingSenderId: "427656484093",
      projectId: "capital-taxi-cda68",
      databaseURL: "https://capital-taxi-cda68-default-rtdb.firebaseio.com",
      storageBucket: "capital-taxi-cda68.firebasestorage.app",
    ),
  );
  print("🔥 Firebase تم الاتصال بنجاح!");
} catch (e) {
  print("❌ خطأ في الاتصال بـ Firebase: $e");
}

  runApp(
    MaterialApp(
    
    home: ChangeNotifierProvider(
      create: (context) => EmailService(),
      child:   DashboardScreen(),
    ),
    debugShowCheckedModeBanner: false,
  ));
}

class DashboardScreen extends StatefulWidget {
  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  final DatabaseReference _driversRef = FirebaseDatabase.instance.ref("drivers");

  LatLng? _currentLocation;
  Timer? _timeoutTimer;

  Map<String, DriverData> _driversData = {};
  Map<String, Timer> _trackingTimers = {};
  String? _selectedDriverId;
  TripInfo? _selectedTrip;
  bool _showDriverDetails = false;
  List<LatLng> _routePoints = [];
  bool _isLoadingRoute = false;

  // مفتاح API لـ GraphHopper - استبدله بمفتاحك الخاص
  final String _graphHopperApiKey = 'c69abe50-60d2-43bc-82b1-81cbdcebeddc';

  @override
  void initState() {
    super.initState();
    _listenToDriverLocation();
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _trackingTimers.values.forEach((timer) => timer.cancel());
    super.dispose();
  }

  Future<String> _getPlaceName(LatLng location) async {
    final url =
        'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=${location.latitude}&lon=${location.longitude}';

    final response = await http.get(
      Uri.parse(url),
      headers: {
        'User-Agent': 'CapitalTaxiApp/1.0',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['display_name'] ?? "Unknown Place";
    }
    return "Unknown Place";
  }

  void _saveDriverMovement(String driverId, LatLng from, LatLng to) async {
    final String today = DateTime.now().toIso8601String().split("T")[0];
    String fromPlace = await _getPlaceName(from);
    String toPlace = await _getPlaceName(to);
    final String timestamp = DateTime.now().toIso8601String();

    final DocumentReference trackingRef = FirebaseFirestore.instance
        .collection('driverTracking')
        .doc(driverId)
        .collection(today)
        .doc(timestamp);

    try {
      await trackingRef.set({
        "from": {
          "latitude": from.latitude,
          "longitude": from.longitude,
          "place": fromPlace,
        },
        "to": {
          "latitude": to.latitude,
          "longitude": to.longitude,
          "place": toPlace,
        },
        "timestamp": FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print("❌ خطأ أثناء حفظ تتبع السائق $driverId: $e");
    }
  }

Future<void> _fetchRouteFromGraphHopper(LatLng start, LatLng end) async {
  setState(() {
    _isLoadingRoute = true;
    _routePoints = []; // تأكد من تهيئة _routePoints
  });

  try {
    final url = Uri.parse(
      'https://graphhopper.com/api/1/route?'
      'point=${start.latitude},${start.longitude}&'
      'point=${end.latitude},${end.longitude}&'
      'vehicle=car&'
      'locale=ar&'
      'key=$_graphHopperApiKey&'
      'instructions=false&'
      'calc_points=true',
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final paths = data['paths'] as List;
      if (paths.isNotEmpty) {
        final points = paths[0]['points'] as String;
        _routePoints = decodePolyline(points); // تأكد من استخدام _routePoints هنا
      }
    } else {
      print('❌ فشل في جلب المسار: ${response.statusCode}');
    }
  } catch (e) {
    print('❌ خطأ أثناء جلب المسار: $e');
  } finally {
    setState(() {
      _isLoadingRoute = false;
    });
  }
}
 
// دالة للتحقق من صحة الإحداثيات
bool _isValidCoordinate(LatLng point) {
  return point.latitude >= -90 && 
         point.latitude <= 90 && 
         point.longitude >= -180 && 
         point.longitude <= 180;
}

// تعريف المتغير _polyline
Polyline _polyline = Polyline(
  points: [],
  strokeWidth: 5,
  color: Colors.blue,
);

// دالة لرسم المسار على الخريطة باستخدام Polyline
void _drawRouteOnMap() {
  if (_routePoints.isNotEmpty) {
    setState(() {
      // قم بتحديث _polyline فقط وليس _routePoints
      _polyline = Polyline(
        points: _routePoints,
        strokeWidth: 5,
        color: Colors.blue,
      );
    });
  }
}

List<LatLng> decodePolyline(String encoded) {
  PolylinePoints polylinePoints = PolylinePoints();
  List<PointLatLng> points = polylinePoints.decodePolyline(encoded);
  return points.map((e) => LatLng(e.latitude, e.longitude)).toList();
}

// دالة لعرض بيانات الرحلة وجلب المسار
Future<void> _fetchDriverTrip(String driverId) async {
  try {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('trips')
        .where('driver', isEqualTo: driverId)
        .where('status', isNotEqualTo: 'completed')
        .limit(1)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      final doc = querySnapshot.docs.first;
      final data = doc.data();
final polylineString = data['points'] as String;

final decodedPoints = decodePolyline(polylineString);

setState(() {
  _routePoints = decodedPoints;
});

      final originMap = data['originMap'] as Map<String, dynamic>;
      final destinationMap = data['destinationMap'] as Map<String, dynamic>;

      final origin = LatLng(originMap['lat'], originMap['lng']);
      final destination = LatLng(destinationMap['lat'], destinationMap['lng']);

      setState(() {
        _selectedTrip = TripInfo(
          origin: origin,
          destination: destination,
          status: data['status'] ?? 'unknown',
        );
      });

      // جلب المسار من GraphHopper
      await _fetchRouteFromGraphHopper(origin, destination);

      // رسم المسار على الخريطة
      _drawRouteOnMap();
    } else {
      setState(() {
        _selectedTrip = null;
        _routePoints = [];
      });
    }
  } catch (e) {
    print("❌ خطأ أثناء جلب بيانات الرحلة: $e");
    setState(() {
      _selectedTrip = null;
      _routePoints = [];
    });
  }
}

  void _listenToDriverLocation() {
    _driversRef.onValue.listen((DatabaseEvent event) {
      try {
        if (event.snapshot.value != null && event.snapshot.value is Map) {
          final Map<String, dynamic> driversMap =
              Map<String, dynamic>.from(event.snapshot.value as Map);

          Map<String, DriverData> updatedDrivers = {};

          driversMap.forEach((driverId, driverInfo) {
            if (driverInfo is Map && driverInfo.containsKey('location')) {
              final location = Map<String, dynamic>.from(driverInfo['location']);
              if (location.containsKey('latitude') && location.containsKey('longitude')) {
                LatLng newLocation = LatLng(location['latitude'], location['longitude']);
                LatLng previousLocation = _driversData[driverId]?.currentLocation ?? newLocation;
                double angle = _calculateBearing(previousLocation, newLocation);

                if (!_trackingTimers.containsKey(driverId)) {
                  _saveDriverMovement(driverId, previousLocation, newLocation);

                  _trackingTimers[driverId] = Timer.periodic(Duration(seconds: 30), (timer) {
                    final current = _driversData[driverId]?.currentLocation;
                    final previous = _driversData[driverId]?.previousLocation;
                    if (current != null && previous != null && current != previous) {
                      _saveDriverMovement(driverId, previous, current);
                    }
                  });
                }

                updatedDrivers[driverId] = DriverData(
                  currentLocation: newLocation,
                  previousLocation: previousLocation,
                  rotationAngle: angle,
                );
              }
            }
          });

          setState(() {
            _driversData = updatedDrivers;
          });

          _resetTimeout();
        }
      } catch (e) {
        print("❌ خطأ أثناء تحديث مواقع السائقين: $e");
      }
    });
  }

  void _resetTimeout() {
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(Duration(seconds: 30), () {
      setState(() {
        _currentLocation = null;
      });
      print("🚫 لم يتم تحديث الموقع لمدة 30 ثانية، إخفاء السيارة!");
    });
  }

  double _calculateBearing(LatLng start, LatLng end) {
    double lat1 = start.latitude * math.pi / 180;
    double lat2 = end.latitude * math.pi / 180;
    double dLon = (end.longitude - start.longitude) * math.pi / 180;
    double y = math.sin(dLon) * math.cos(lat2);
    double x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  void showDriverDetails(String driverId) async {
    setState(() {
      _selectedDriverId = driverId;
      _showDriverDetails = true;
    });
    
    await _fetchDriverTrip(driverId);
  }

  void _hideDriverDetails() {
    setState(() {
      _selectedDriverId = null;
      _selectedTrip = null;
      _showDriverDetails = false;
      _routePoints = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            labelType: NavigationRailLabelType.all,
            destinations: [
              
              NavigationRailDestination(
                  icon: Icon(Icons.map), label: Text("الخريطة")),
            
              NavigationRailDestination(
                  icon: Icon(Icons.bar_chart), label: Text("اداره الرحلات")),
              NavigationRailDestination(

                  icon: Icon(Icons.directions_car), label: Text("السائقون")),
                    NavigationRailDestination(

                  icon: Icon(Icons.person), label: Text("الركاب")),
                          NavigationRailDestination(
                  icon: Icon(Icons.home), label: Text("اداره الشكاوي")),
                    NavigationRailDestination(

                  icon: Icon(Icons.money), label: Text("اداره الماليات")),
                    NavigationRailDestination(
  icon: Icon(Icons.attach_money),
  label: Text("إدارة تسعير المناطق"),
),               NavigationRailDestination(
  icon: Icon(Icons.notification_important),
  label: Text("الاشعارات"),
),
 NavigationRailDestination(
  icon: Icon(Icons.notification_important),
  label: Text("التواصل"),
),

            ],
          ),
          Expanded(
            child: Stack(
              children: [
                IndexedStack(
                  index: _selectedIndex,
                  children: [
                 
                    Stack(
                      children: [
                        FlutterMap(
                          options: MapOptions(
                            initialCenter: LatLng(30.0444, 31.2357),
                            initialZoom: 14,
                            onTap: (_, __) {
                              _hideDriverDetails();
                            },
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                              subdomains: ['a', 'b', 'c'],
                            ),
                            if (_selectedTrip != null && _routePoints.isNotEmpty)
                              PolylineLayer(
                                polylines: [
                                  Polyline(
                                    points: _routePoints,
                                    color: Colors.blue.withOpacity(0.7),
                                    strokeWidth: 4,
                                  ),
                                ],
                              ),
                            if (_selectedTrip != null)
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    point: _selectedTrip!.origin,
                                    width: 30,
                                    height: 30,
                                    child: Icon(Icons.location_pin, color: Colors.green),
                                  ),
                                  Marker(
                                    point: _selectedTrip!.destination,
                                    width: 30,
                                    height: 30,
                                    child: Icon(Icons.flag, color: Colors.red),
                                  ),
                                ],
                              ),
                            MarkerLayer(
                              markers: _driversData.entries.map((entry) {
                                final driverId = entry.key;
                                final driver = entry.value;
                                return Marker(
                                  point: driver.currentLocation,
                                  width: 40,
                                  height: 40,
                                  child: GestureDetector(
                                    onTap: () => showDriverDetails(driverId),
                                    child: TweenAnimationBuilder<double>(
                                      tween: Tween<double>(
                                          begin: 0, end: driver.rotationAngle),
                                      duration: Duration(milliseconds: 500),
                                      builder: (context, angle, child) {
                                        return Transform.rotate(
                                          angle: angle * (math.pi / 180),
                                          child: Image.asset(
                                            "assets/car_icon.png",
                                            color: _selectedDriverId == driverId
                                                ? Colors.blue
                                                : null,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                        if (_isLoadingRoute)
                          Center(
                            child: CircularProgressIndicator(),
                          ),
                      ],
                    ),
   
                  TripManagementDashboard(),
                     DriversPage(), 
PremiumPassengerDashboard(),
                    ProfessionalComplaintsDashboard(),
                     AnalyticsDashboard(),
                     PricingZoneManagement(),
                     NotificationsPage()  ,
                     EmailContact()
                  ],
                ),
                
                if (_showDriverDetails && _selectedDriverId != null)
                  Center(
                    child: Container(
                      height: MediaQuery.of(context).size.height * 0.5,
                      width: 1000,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: _hideDriverDetails,
                            child: Container(
                              width: 40,
                              height: 4,
                              margin: EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.grey[400],
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          
                          Expanded(
                            child: SingleChildScrollView(
                              padding: EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "تفاصيل السائق",
                                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                  ),
                                  SizedBox(height: 16),
                                  ListTile(
                                    leading: Icon(Icons.person),
                                    title: Text("معرف السائق"),
                                    subtitle: Text(_selectedDriverId!),
                                  ),
                                  if (_driversData[_selectedDriverId] != null)
                                    ListTile(
                                      leading: Icon(Icons.location_on),
                                      title: Text("الموقع الحالي"),
                                      subtitle: Text(
                                          "${_driversData[_selectedDriverId]!.currentLocation.latitude.toStringAsFixed(4)}, ${_driversData[_selectedDriverId]!.currentLocation.longitude.toStringAsFixed(4)}"),
                                    ),
                                  Divider(),
                                  Text(
                                    "معلومات الرحلة",
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  SizedBox(height: 8),
                                  if (_selectedTrip != null)
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        ListTile(
                                          leading: Icon(Icons.flag, color: Colors.green),
                                          title: Text("نقطة البداية"),
                                          subtitle: Text(
                                              "${_selectedTrip!.origin.latitude.toStringAsFixed(4)}, ${_selectedTrip!.origin.longitude.toStringAsFixed(4)}"),
                                        ),
                                        ListTile(
                                          leading: Icon(Icons.flag, color: Colors.red),
                                          title: Text("نقطة النهاية"),
                                          subtitle: Text(
                                              "${_selectedTrip!.destination.latitude.toStringAsFixed(4)}, ${_selectedTrip!.destination.longitude.toStringAsFixed(4)}"),
                                        ),
                                        ListTile(
                                          leading: Icon(Icons.info),
                                          title: Text("حالة الرحلة"),
                                          subtitle: Text(_selectedTrip!.status),
                                        ),
                                        SizedBox(height: 16),
                                        Container(
                                          height: 200,
                                          child:FlutterMap(
  options: MapOptions(
    initialCenter: _driversData[_selectedDriverId]?.currentLocation ?? LatLng(30.0444, 31.2357),
    initialZoom: 13,
  ),
  children: [
    TileLayer(
      urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
      subdomains: ['a', 'b', 'c'],
    ),
    // رسم المسار إذا كانت النقاط موجودة
    if (_routePoints.isNotEmpty)
      PolylineLayer(
        polylines: [
          Polyline(
            points: _routePoints,  // استخدام _routePoints هنا
            color: Colors.blue.withOpacity(0.7),
            strokeWidth: 4,
          ),
        ],
      ),
    // إضافة علامات المواقع
    MarkerLayer(
      markers: [
        // Marker للسائق
        if (_driversData[_selectedDriverId] != null)
          Marker(
            point: _driversData[_selectedDriverId]!.currentLocation,
            width: 30,
            height: 30,
            child: Transform.rotate(
              angle: _driversData[_selectedDriverId]!.rotationAngle * (math.pi / 180),
              child: Image.asset("assets/car_icon.png"),
            ),
          ),
        // Marker للموقع الأصلي
        if (_selectedTrip != null)
          Marker(
            point: _selectedTrip!.origin,
            width: 30,
            height: 30,
            child: Icon(Icons.location_pin, color: Colors.green),
          ),
        // Marker للموقع النهائي
        if (_selectedTrip != null)
          Marker(
            point: _selectedTrip!.destination,
            width: 30,
            height: 30,
            child: Icon(Icons.flag, color: Colors.red),
          ),
      ],
    ),
  ],
)
,
                                        ),
                                      ],
                                    )
                                  else
                                    Padding(
                                      padding: EdgeInsets.symmetric(vertical: 16),
                                      child: Center(
                                        child: Text(
                                          "لا توجد رحلة نشطة حالياً",
                                          style: TextStyle(color: Colors.grey),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          
                          Padding(
                            padding: EdgeInsets.all(16),
                            child: ElevatedButton(
                              onPressed: _hideDriverDetails,
                              style: ElevatedButton.styleFrom(
                                minimumSize: Size(double.infinity, 50),
                              ),
                              child: Text("إغلاق التفاصيل"),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DriverData {
  LatLng currentLocation;
  LatLng previousLocation;
  double rotationAngle;

  DriverData({
    required this.currentLocation,
    required this.previousLocation,
    required this.rotationAngle,
  });
}

class TripInfo {
  final LatLng origin;
  final LatLng destination;
  final String status;

  TripInfo({
    required this.origin,
    required this.destination,
    required this.status,
  });
}