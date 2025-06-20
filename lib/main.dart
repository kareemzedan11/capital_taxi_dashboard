import 'dart:convert';
import 'package:capitaltaxi/AnalyticsDashboard/AnalyticsDashboard.dart';
import 'package:capitaltaxi/ComplaintsManagement/ComplaintsManagementApp%20.dart';
import 'package:capitaltaxi/DriversPage.dart';
import 'package:capitaltaxi/LoginPage/LoginPage.dart';
import 'package:capitaltaxi/NotficationPage.dart';
import 'package:capitaltaxi/PassengerManagementScreen/PassengerManagementScreen.dart';
import 'package:capitaltaxi/PricingZoneManagement/PricingZoneManagement.dart';
import 'package:capitaltaxi/RegionSettingsScreen/RegionSettingsScreen.dart';
import 'package:capitaltaxi/TripManagementDashboard.dart';
import 'package:capitaltaxi/Trips.dart';
import 'package:capitaltaxi/messageManagment/messageManagment.dart';
import 'package:capitaltaxi/passengerEmergency.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

//f6b700

String _formatDate(DateTime dateTime) {
  // بصيغة 12 يونيو 2025 - 1:34 م
  return '${_arabicDay(dateTime.day)} ${_arabicMonth(dateTime.month)} ${dateTime.year} - '
      '${dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12}:${dateTime.minute.toString().padLeft(2, '0')} '
      '${dateTime.hour >= 12 ? "م" : "ص"}';
}

String _arabicMonth(int month) {
  const months = [
    'يناير',
    'فبراير',
    'مارس',
    'أبريل',
    'مايو',
    'يونيو',
    'يوليو',
    'أغسطس',
    'سبتمبر',
    'أكتوبر',
    'نوفمبر',
    'ديسمبر'
  ];
  return months[month - 1];
}

String _arabicDay(int day) => day.toString();

Future<void> sendEmergencyMessage({
  required String passengerName,
  required String passengerId,
  required String driverName,
  required String driverId,
  required String tripNumber,
  required String tripFrom,
  required String tripTo,
  required String message,
  String passengerImage = '',
}) async {
  final firestore = FirebaseFirestore.instance;

  try {
    await firestore.collection('emergency_messages').add({
      'passengerName': passengerName,
      'passengerId': passengerId,
      'driverName': driverName,
      'driverId': driverId,
      'tripNumber': tripNumber,
      'tripFrom': tripFrom,
      'tripTo': tripTo,
      'message': message,
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'new', // أو any enum-like string
      'isRead': false,
      'passengerImage': passengerImage,
    });

    print("✅ تم إرسال الرسالة بنجاح.");
  } catch (e) {
    print("❌ حدث خطأ أثناء إرسال الرسالة: $e");
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://mwncdoelxuwhtlrvtnap.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im13bmNkb2VseHV3aHRscnZ0bmFwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDUwMjU4NjUsImV4cCI6MjA2MDYwMTg2NX0.f5Zlz_WSLypyCUn67g2PEA5ZjHa8VsqjJDbxIgtBBTk',
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
        child: DashboardScreen(),
      ),
      debugShowCheckedModeBanner: false,
    ),
  );
}

class DashboardScreen extends StatefulWidget {
  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  final DatabaseReference _driversRef =
      FirebaseDatabase.instance.ref("drivers");
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _driverMovements = [];
  bool _isLoadingMovements = false;
  LatLng? _currentLocation;
  Timer? _timeoutTimer;
  LatLng? _userLocation;
  bool _isLoadingLocation = false;
  bool _showHeatmap = false;
  Map<String, DriverData> _driversData = {};
  Map<String, Timer> _trackingTimers = {};
  String? _selectedDriverId;
  TripInfo? _selectedTrip;
  bool _showDriverDetails = false;
  List<LatLng> _routePoints = [];
  bool _isLoadingRoute = false;
  Map<String, dynamic>? _driverInfo;

  final String _graphHopperApiKey = 'c69abe50-60d2-43bc-82b1-81cbdcebeddc';

  @override
  void initState() {
    super.initState();

    _listenToDriverLocation();
    _getUserLocation();
  }

  void _toggleHeatmap() {
    setState(() {
      _showHeatmap = !_showHeatmap;
    });
  }

  Future<void> _getUserLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return;
      }

      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _userLocation = LatLng(position.latitude, position.longitude);
      });
    } catch (e) {
      print("❌ خطأ في الحصول على الموقع: $e");
    } finally {
      setState(() {
        _isLoadingLocation = false;
      });
    }
  }

  Future<void> _fetchDriverInfo(String driverId) async {
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection('drivers')
          .where('id', isEqualTo: driverId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        DocumentSnapshot driverDoc = querySnapshot.docs.first;
        Map<String, dynamic> data = driverDoc.data() as Map<String, dynamic>;

        final Timestamp? createdAtTimestamp = data['createdAt'];
        final DateTime? createdAtDateTime = createdAtTimestamp?.toDate();
        final Map<String, dynamic>? ratingData =
            data['rating'] as Map<String, dynamic>?;
        double calculatedRating = 0.0;

        if (ratingData != null) {
          final int count = ratingData['count'] ?? 0;
          final int total = ratingData['total'] ?? 0;

          if (count > 0) {
            calculatedRating = total / count;
          }
        }

        setState(() {
          _driverInfo = {
            'name': data['name'] ?? 'غير معروف',
            'phone': data['phone'] ?? 'غير متوفر',
            'email': data['email'] ?? 'غير متوفر',
            'rating': calculatedRating.toStringAsFixed(1), // مثل: 4.7
            'imageUrl': data['imageUrl'] ?? 'https://via.placeholder.com/150',
            'carModel': data['carModel'] ?? 'غير معروف',
            'licensePlate': data['carNumber'] ?? 'غير متوفر',
            'createdAt': createdAtDateTime != null
                ? _formatDate(createdAtDateTime)
                : 'غير متوفر',
          };
        });
      } else {
        print('❌ لا يوجد بيانات للسائق في Firestore');
        setState(() {
          _driverInfo = null;
        });
      }
    } catch (e) {
      print('❌ خطأ في جلب بيانات السائق: $e');
      setState(() {
        _driverInfo = null;
      });
    }
  }

  void showDriverDetails(String driverId) async {
    setState(() {
      _selectedDriverId = driverId;
      _showDriverDetails = true;
      _isLoadingRoute = true;
      _isLoadingMovements = true;
    });

    await Future.wait([
      _fetchDriverTrip(driverId),
      _fetchDriverInfo(driverId),
      _fetchDriverMovements(driverId),
    ]);

    setState(() {
      _isLoadingRoute = false;
      _isLoadingMovements = false;
    });
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
          _routePoints =
              decodePolyline(points); // تأكد من استخدام _routePoints هنا
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

  Future<void> _fetchDriverMovements(String driverId) async {
    setState(() {
      _isLoadingMovements = true;
      _driverMovements = [];
    });

    try {
      final today = DateTime.now().toIso8601String().split('T')[0];
      final querySnapshot = await FirebaseFirestore.instance
          .collection('driverTracking')
          .doc(driverId)
          .collection(today)
          .orderBy('timestamp', descending: true)
          .get();

      setState(() {
        _driverMovements = querySnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'from': data['from'],
            'to': data['to'],
            'timestamp': data['timestamp'],
            'id': doc.id,
          };
        }).toList();
      });
    } catch (e) {
      print('❌ خطأ في جلب تحركات السائق: $e');
    } finally {
      setState(() {
        _isLoadingMovements = false;
      });
    }
  }

// دالة لعرض بيانات الرحلة وجلب المسار
  Future<void> _fetchDriverTrip(String driverId) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('trips')
          .where('driver', isEqualTo: driverId)
          .where('status', isNotEqualTo: 'Completed')
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        final data = doc.data();

        // تحقق من وجود نقاط المسار
        if (data['points'] != null) {
          final polylineString = data['points'] as String;
          final decodedPoints = decodePolyline(polylineString);

          setState(() {
            _routePoints = decodedPoints;
          });
        }

        final originMap = data['originMap'] as Map<String, dynamic>;
        final destinationMap = data['destinationMap'] as Map<String, dynamic>;

        final origin = LatLng(originMap['lat'], originMap['lng']);
        final destination =
            LatLng(destinationMap['lat'], destinationMap['lng']);

        setState(() {
          _selectedTrip = TripInfo(
            origin: origin,
            destination: destination,
            status: data['status'] ?? 'unknown',
          );
        });
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
              final location =
                  Map<String, dynamic>.from(driverInfo['location']);
              if (location.containsKey('latitude') &&
                  location.containsKey('longitude')) {
                LatLng newLocation =
                    LatLng(location['latitude'], location['longitude']);
                LatLng previousLocation =
                    _driversData[driverId]?.currentLocation ?? newLocation;
                double angle = _calculateBearing(previousLocation, newLocation);

                if (!_trackingTimers.containsKey(driverId)) {
                  _saveDriverMovement(driverId, previousLocation, newLocation);

                  _trackingTimers[driverId] =
                      Timer.periodic(Duration(seconds: 30), (timer) {
                    final current = _driversData[driverId]?.currentLocation;
                    final previous = _driversData[driverId]?.previousLocation;
                    if (current != null &&
                        previous != null &&
                        current != previous) {
                      _saveDriverMovement(driverId, previous, current);
                    }
                  });
                }
                updatedDrivers[driverId] = DriverData(
                  currentLocation: newLocation,
                  previousLocation: previousLocation,
                  rotationAngle: angle,
                  previousRotationAngle:
                      _driversData[driverId]?.rotationAngle ?? angle,
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
    double lon1 = start.longitude * math.pi / 180;
    double lat2 = end.latitude * math.pi / 180;
    double lon2 = end.longitude * math.pi / 180;

    double dLon = lon2 - lon1;
    double y = math.sin(dLon) * math.cos(lat2);
    double x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);

    double bearing = math.atan2(y, x) * 180 / math.pi;
    return (bearing + 360) % 360; // تطبيع الزاوية لتصبح بين 0 و 360
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
            backgroundColor: Color(0xfff6b700),
            selectedLabelTextStyle: TextStyle(color: Colors.white),
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
                  icon: Icon(Icons.sync_problem), label: Text("اداره الشكاوي")),
              NavigationRailDestination(
                  icon: Icon(Icons.money), label: Text("اداره الماليات")),
              NavigationRailDestination(
                  icon: Icon(Icons.emergency), label: Text("طوارئ الركاب")),
              NavigationRailDestination(
                  icon: Icon(Icons.location_city),
                  label: Text("إعدادات النطاق الجغرافي")),
              //       NavigationRailDestination(icon: Icon(Icons.notification_important), label: Text("الاشعارات")),
              NavigationRailDestination(
                  icon: Icon(Icons.notification_important),
                  label: Text("التواصل")),
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
                            initialCenter:
                                _userLocation ?? LatLng(30.0444, 31.2357),
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
                            if (_userLocation != null)
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    point: _userLocation!,
                                    width: 40,
                                    height: 40,
                                    child: Icon(
                                      Icons.person_pin_circle,
                                      color: Colors.blue,
                                      size: 40,
                                    ),
                                  ),
                                ],
                              ),
                            if (_selectedTrip != null &&
                                _routePoints.isNotEmpty)
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
                                    child: Icon(Icons.location_pin,
                                        color: Colors.green),
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
                                          begin: _driversData[driverId]
                                                  ?.previousRotationAngle ??
                                              0,
                                          end: _driversData[driverId]
                                                  ?.rotationAngle ??
                                              0,
                                        ),
                                        duration: Duration(
                                            milliseconds:
                                                1000), // زيادة مدة الحركة
                                        curve: Curves
                                            .easeInOut, // إضافة منحنى للحركة
                                        builder: (context, angle, child) {
                                          return Transform.rotate(
                                            angle: angle * (math.pi / 180),
                                            child: Image.asset(
                                              "assets/car_icon.png",
                                              color:
                                                  _selectedDriverId == driverId
                                                      ? Colors.blue
                                                      : null,
                                            ),
                                          );
                                        },
                                      )),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                        if (_isLoadingLocation)
                          Center(child: CircularProgressIndicator()),
                        if (_isLoadingRoute)
                          Center(child: CircularProgressIndicator()),
                      ],
                    ),
                    TripManagementDashboard(),
                    DriversPage(),
                    PremiumPassengerDashboard(),
                    ProfessionalComplaintsDashboard(),
                    AnalyticsDashboard(),
                    PassengerEmergency(),
                    RegionSettingsScreen(),
                    //  NotificationsPage(),
                    EmailContact()
                  ],
                ),
                if (_showDriverDetails && _selectedDriverId != null)
                  Center(
                    child: Container(
                      height: MediaQuery.of(context).size.height * 0.85,
                      width: MediaQuery.of(context).size.width * 0.85,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Header with gradient
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.blue[800]!, Colors.blue[600]!],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(20)),
                            ), // ← هنا كان القوس ناقص
                            padding: EdgeInsets.all(16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "تفاصيل السائق",
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.close,
                                      color: Colors.white, size: 28),
                                  onPressed: _hideDriverDetails,
                                ),
                              ],
                            ),
                          ),

                          Expanded(
                            child: SingleChildScrollView(
                              padding: EdgeInsets.all(20),
                              child: Column(
                                children: [
                                  // Driver Profile Section
                                  Container(
                                    padding: EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: Colors.blue[50],
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    child: Row(
                                      children: [
                                        // Driver Avatar
                                        Container(
                                          width: 100,
                                          height: 100,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.blue,
                                              width: 3,
                                            ),
                                            image: DecorationImage(
                                              image: NetworkImage(_driverInfo?[
                                                      'imageUrl'] ??
                                                  'https://cdn-icons-png.flaticon.com/512/3135/3135715.png'),
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 20),

                                        // Driver Info
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                _driverInfo?['name'] ??
                                                    'غير معروف',
                                                style: TextStyle(
                                                  fontSize: 22,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.blue[900],
                                                ),
                                              ),
                                              SizedBox(height: 8),
                                              Row(
                                                children: [
                                                  Icon(Icons.star,
                                                      color: Colors.amber,
                                                      size: 22),
                                                  SizedBox(width: 5),
                                                  Text(
                                                    _driverInfo?['rating'] ??
                                                        '0.0',
                                                    style: TextStyle(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              SizedBox(height: 8),
                                              Row(
                                                children: [
                                                  Icon(Icons.directions_car,
                                                      size: 18,
                                                      color: Colors.grey[700]),
                                                  SizedBox(width: 5),
                                                  Text(
                                                    _driverInfo?['carModel'] ??
                                                        'غير معروف',
                                                    style:
                                                        TextStyle(fontSize: 16),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  SizedBox(height: 25),

                                  // Info Cards Grid
                                  GridView.count(
                                    shrinkWrap: true,
                                    physics: NeverScrollableScrollPhysics(),
                                    crossAxisCount: 2,
                                    crossAxisSpacing: 15,
                                    mainAxisSpacing: 15,
                                    childAspectRatio: 3,
                                    children: [
                                      _buildInfoCard(
                                        icon: Icons.phone,
                                        title: "الهاتف",
                                        value: _driverInfo?['phone'] ??
                                            'غير متوفر',
                                        color: Colors.green,
                                      ),
                                      _buildInfoCard(
                                        icon: Icons.email,
                                        title: "البريد الإلكتروني",
                                        value: _driverInfo?['email'] ??
                                            'غير متوفر',
                                        color: Colors.blue,
                                      ),
                                      _buildInfoCard(
                                        icon: Icons.confirmation_number,
                                        title: "رقم اللوحة",
                                        value: _driverInfo?['licensePlate'] ??
                                            'غير متوفر',
                                        color: Colors.orange,
                                      ),
                                      _buildInfoCard(
                                        icon: Icons.calendar_today,
                                        title: "تاريخ الانضمام",
                                        value: _driverInfo?['createdAt'] ??
                                            'غير متوفر',
                                        color: Colors.purple,
                                      ),
                                    ],
                                  ),

                                  SizedBox(height: 25),
                                  // داخل Column الرئيسية في واجهة التفاصيل، بعد قسم Location Map

                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        "تحركات السائق اليوم",
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue[800],
                                        ),
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.refresh,
                                            color: Colors.blue),
                                        onPressed: () => _fetchDriverMovements(
                                            _selectedDriverId!),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 15),

                                  if (_isLoadingMovements)
                                    Center(child: CircularProgressIndicator())
                                  else if (_driverMovements.isEmpty)
                                    Text(
                                      "لا توجد تحركات مسجلة اليوم",
                                      style: TextStyle(color: Colors.grey),
                                    )
                                  else
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black12,
                                            blurRadius: 5,
                                            spreadRadius: 1,
                                          ),
                                        ],
                                      ),
                                      child: ListView.builder(
                                        shrinkWrap: true,
                                        physics: NeverScrollableScrollPhysics(),
                                        itemCount: _driverMovements.length,
                                        itemBuilder: (context, index) {
                                          final movement =
                                              _driverMovements[index];
                                          final from = movement['from']
                                              as Map<String, dynamic>;
                                          final to = movement['to']
                                              as Map<String, dynamic>;
                                          final timestamp =
                                              movement['timestamp']
                                                  as Timestamp;

                                          return Padding(
                                            padding: const EdgeInsets.all(12.0),
                                            child: Column(
                                              children: [
                                                Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Icon(Icons.directions,
                                                        color: Colors.blue),
                                                    SizedBox(width: 10),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            "من: ${from['place']}",
                                                            style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold),
                                                          ),
                                                          SizedBox(height: 5),
                                                          Text(
                                                            "إلى: ${to['place']}",
                                                            style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold),
                                                          ),
                                                          SizedBox(height: 5),
                                                          Text(
                                                            "الوقت: ${_formatDate(timestamp.toDate())}",
                                                            style: TextStyle(
                                                                color: Colors
                                                                    .grey),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                if (index !=
                                                    _driverMovements.length - 1)
                                                  Divider(
                                                      height: 20, thickness: 1),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  SizedBox(height: 25),
                                  // Trip Details Section
                                  if (_selectedTrip != null) ...[
                                    Text(
                                      "معلومات الرحلة الحالية",
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue[800],
                                      ),
                                    ),
                                    SizedBox(height: 15),
                                    Container(
                                      padding: EdgeInsets.all(15),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[100],
                                        borderRadius: BorderRadius.circular(15),
                                        border: Border.all(
                                            color: Colors.grey[300]!),
                                      ),
                                      child: Column(
                                        children: [
                                          _buildTripDetailRow(
                                            "الحالة",
                                            _selectedTrip!.status,
                                            Icons.info,
                                            Colors.blue,
                                          ),
                                          Divider(height: 20, thickness: 1),
                                          _buildTripDetailRow(
                                            "نقطة البداية",
                                            "${_selectedTrip!.origin.latitude.toStringAsFixed(4)}, "
                                                "${_selectedTrip!.origin.longitude.toStringAsFixed(4)}",
                                            Icons.location_on,
                                            Colors.green,
                                          ),
                                          Divider(height: 20, thickness: 1),
                                          _buildTripDetailRow(
                                            "نقطة الوصول",
                                            "${_selectedTrip!.destination.latitude.toStringAsFixed(4)}, "
                                                "${_selectedTrip!.destination.longitude.toStringAsFixed(4)}",
                                            Icons.flag,
                                            Colors.red,
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(height: 20),
                                  ],

                                  // Location Map
                                  Text(
                                    "الموقع على الخريطة",
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue[800],
                                    ),
                                  ),
                                  SizedBox(height: 15),

                                  Container(
                                    height: 250,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(15),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black12,
                                          blurRadius: 10,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(15),
                                      child: FlutterMap(
                                        options: MapOptions(
                                          initialCenter: _userLocation ??
                                              LatLng(30.0444, 31.2357),
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
                                          if (_routePoints.isNotEmpty)
                                            PolylineLayer(
                                              polylines: [
                                                Polyline(
                                                  points: _routePoints,
                                                  color: Colors.blue
                                                      .withOpacity(0.7),
                                                  strokeWidth: 4,
                                                ),
                                              ],
                                            ),
                                          MarkerLayer(
                                            markers: [
                                              if (_driversData[
                                                      _selectedDriverId] !=
                                                  null)
                                                Marker(
                                                  point: _driversData[
                                                          _selectedDriverId]!
                                                      .currentLocation,
                                                  width: 40,
                                                  height: 40,
                                                  child: Transform.rotate(
                                                      angle: _driversData[
                                                                  _selectedDriverId]!
                                                              .rotationAngle *
                                                          (math.pi / 180),
                                                      child: Image(
                                                          image: AssetImage(
                                                              "assets/car_icon.png"))),
                                                ),
                                              if (_selectedTrip != null) ...[
                                                Marker(
                                                  point: _selectedTrip!.origin,
                                                  width: 30,
                                                  height: 30,
                                                  child: Icon(
                                                      Icons.location_pin,
                                                      color: Colors.green,
                                                      size: 30),
                                                ),
                                                Marker(
                                                  point: _selectedTrip!
                                                      .destination,
                                                  width: 30,
                                                  height: 30,
                                                  child: Icon(Icons.flag,
                                                      color: Colors.red,
                                                      size: 30),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

//           // Action Buttons
//           Padding(
//             padding: EdgeInsets.all(15),
//             child: Row(
//               children: [
//                 Expanded(
//                   child: ElevatedButton.icon(
//                     icon: Icon(Icons.message, color: Colors.white),
//                     label: Text("مراسلة"),
//               onPressed: () {
//   showDialog(
//     context: context,
//     builder: (context) {
//       final TextEditingController _messageController = TextEditingController();
//       return AlertDialog(
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
//         title: Text("إرسال رسالة إلى السائق"),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             TextField(
//               controller: _messageController,
//               maxLines: 4,
//               decoration: InputDecoration(
//                 hintText: "اكتب رسالتك هنا...",
//                 border: OutlineInputBorder(),
//               ),
//             ),
//           ],
//         ),
//         actions: [
//           TextButton(
//             onPressed: () {
//               Navigator.of(context).pop(); // إغلاق النافذة
//             },
//             child: Text("إلغاء"),
//           ),
//           ElevatedButton(
//             onPressed: () {
//               String message = _messageController.text.trim();
//               if (message.isNotEmpty) {
//                 // ✉️ هنا ترسل الرسالة مثلاً إلى Firebase أو API
//                 print("📤 تم إرسال الرسالة: $message");

//                 // بعد الإرسال، أغلق النافذة
//                 Navigator.of(context).pop();

//                 ScaffoldMessenger.of(context).showSnackBar(
//                   SnackBar(content: Text("✅ تم إرسال الرسالة")),
//                 );
//               }
//             },
//             child: Text("إرسال"),
//           ),
//         ],
//       );
//     },
//   );
// },

//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: Colors.blue[800],
//                       padding: EdgeInsets.symmetric(vertical: 15),
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(12),
//                       ),
//                     ),
//                   ),
//                 ),

//               ],
//             ),
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
  double previousRotationAngle; // إضافة هذا المتغير

  DriverData({
    required this.currentLocation,
    required this.previousLocation,
    required this.rotationAngle,
    required this.previousRotationAngle,
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

Widget _buildInfoRow(IconData icon, String title, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8.0),
    child: Row(
      children: [
        Icon(icon, color: Colors.blue),
        SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _buildInfoCard({
  required IconData icon,
  required String title,
  required String value,
  required Color color,
}) {
  return Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black12,
          blurRadius: 5,
          spreadRadius: 1,
        ),
      ],
    ),
    padding: EdgeInsets.all(12),
    child: Row(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

Widget _buildTripDetailRow(
    String title, String value, IconData icon, Color color) {
  return Row(
    children: [
      Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      SizedBox(width: 15),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 5),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
