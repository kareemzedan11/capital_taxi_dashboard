import 'package:audioplayers/audioplayers.dart';
import 'package:capitaltaxi/helper/map_screen.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
 

class TripManagementDashboard extends StatefulWidget {
  @override
  _TripManagementDashboardState createState() => _TripManagementDashboardState();
}

class _TripManagementDashboardState extends State<TripManagementDashboard> {
  String _searchQuery = '';
  DateTime? _selectedDate;
  String? _selectedDriver;
  String? _selectedPassenger;
  String _selectedFilter = 'اليوم';
  Trip? _selectedTrip;
  List<Trip> _trips = [];
  bool _isLoading = true;
  AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
Duration _position = Duration.zero;
  @override
  void initState() {
    super.initState();
    _fetchTrips();
     _loadData();

     // مستمع لتغير المدة الكلية
  _audioPlayer.onDurationChanged.listen((duration) {
    setState(() => _duration = duration);
  });

  // مستمع لتغير الموضع الحالي
  _audioPlayer.onPositionChanged.listen((position) {
    setState(() => _position = position);
  });

  // مستمع عند اكتمال التشغيل
  _audioPlayer.onPlayerComplete.listen((_) {
    setState(() => _isPlaying = false);
  });
  }

  
  Future<void> _fetchTrips() async {
  try {
  FirebaseFirestore.instance
  .collection('trips')
  .orderBy('createdAt', descending: true)
  .snapshots()
  .listen((querySnapshot) async {
    List<Trip> loadedTrips = [];

    for (var doc in querySnapshot.docs) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

      loadedTrips.add(Trip(
        id: doc.id,
        date: _parseDate(data['createdAt']),
        driver: await _getUserName(data['driver'], 'drivers'),
        passenger: await _getUserName(data['userId'], 'users'),
        distance: data['points'] != null ? _calculateDistance(data['points']) : 0,
        price: data['fare'],
        duration: _parseDuration(data['time'] ?? 0),
        paymentMethod: _translatePaymentMethod(data['paymentMethod'] ?? 'cash'),
        status: _translateStatus(data['status'] ?? 'unknown'),
        destination: data['destination'] ?? 'لا توجد وجهة',
        complaints: await _getTripComplaints(doc.id),
        driverDetails: await _getDriverDetails(data['driver']),
        audioRecordingUrl: data['audioRecordingUrl'],
        isActive: ['accepted', 'started', 'inprogress']
            .contains(data['status']?.toString().toLowerCase()),
        points: data['points'],
      ));
    }

    setState(() {
      _trips = loadedTrips;
      _isLoading = false;
    });
  });

  } catch (error) {
    print('Error fetching trips: $error');
    setState(() => _isLoading = false);
  }
}
// دالة لتحليل المدة الزمنية بجميع الاحتمالات
Duration _parseDuration(dynamic timeData) {
  if (timeData == null) return Duration.zero;
  
  try {
    // إذا كانت المدة بالفعل كائن Duration (نادر في Firestore)
    if (timeData is Duration) return timeData;
    
    // إذا كانت قيمة رقمية
    if (timeData is num) {
      // افتراض أنها ثواني إذا كانت القيمة صغيرة (< 10000)
      if (timeData < 10000) return Duration(seconds: timeData.toInt());
      // افتراض أنها ملي ثانية إذا كانت القيمة كبيرة
      return Duration(milliseconds: timeData.toInt());
    }
    
    // إذا كانت نصاً (مثل "00:10:30")
    if (timeData is String) {
      final parts = timeData.split(':');
      if (parts.length == 3) {
        final hours = int.tryParse(parts[0]) ?? 0;
        final minutes = int.tryParse(parts[1]) ?? 0;
        final seconds = int.tryParse(parts[2]) ?? 0;
        return Duration(hours: hours, minutes: minutes, seconds: seconds);
      }
    }
    
    return Duration.zero;
  } catch (e) {
    print('Error parsing duration: $e');
    return Duration.zero;
  }
}

DateTime _parseDate(String dateString) {
  try {
    return DateTime.parse(dateString); // بدون استبدال النقاط
  } catch (e) {
    return DateTime.now(); // في حالة الخطأ، يرجع التاريخ الحالي
  }
}
Future<String> _getUserName(String? userId, String collection) async {
  if (userId == null) return 'غير معروف';
  
  try {
    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection(collection)
        .where('id', isEqualTo: userId)
        .limit(1)
        .get();
    return snapshot.docs.first['name'] ?? 'غير معروف';
  } catch (e) {
    return 'غير معروف';
  }
}
 
// بدلاً من جلب بيانات كل سائق على حدة
// يمكنك جلب جميع السائقين مرة واحدة ثم البحث فيهم
Future<Map<String, String>> _fetchAllDrivers() async {
  QuerySnapshot querySnapshot = await FirebaseFirestore.instance
      .collection('drivers')
      .get();
  return {for (var doc in querySnapshot.docs) doc.id: doc['name']};
}
Future<Map<String, String>> _fetchAllUsers() async {
  QuerySnapshot querySnapshot = await FirebaseFirestore.instance
      .collection('users')
      .get();
  return {for (var doc in querySnapshot.docs) doc.id: doc['name']};
}
final Map<String, Map<String, dynamic>> _driverDetailsCache = {};

Future<Map<String, dynamic>> _getDriverDetails(String? driverId) async {
  if (driverId == null || driverId.isEmpty) return {};
  
  // التحقق من التخزين المؤقت
  if (_driverDetailsCache.containsKey(driverId)) {
    return _driverDetailsCache[driverId]!;
  }
  
  try {
    QuerySnapshot querySnapshot = await FirebaseFirestore.instance
        .collection('drivers')
        .where('id', isEqualTo: driverId)
        .limit(1)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      var driverData = querySnapshot.docs.first.data() as Map<String, dynamic>;
      var details = {
        'carModel': driverData['carModel'] ?? 'غير معروف',
        'carNumber': driverData['carNumber'] ?? 'غير معروف',
        'carType': driverData['carType'] ?? 'غير معروف',
        'rating': (driverData['rating'] ?? 0).toDouble(),
        'phone': driverData['phone'] ?? 'غير متوفر',
        'status': _translateDriverStatus(driverData['status'] ?? ''),
       'name': driverData['name'] ?? 'غير معروف',

      };
      
      // تخزين في الذاكرة المؤقتة
      _driverDetailsCache[driverId] = details;
      
      return details;
    }
    return {};
  } catch (e) {
    print('Error fetching driver details: $e');
    return {};
  }
}

 String _translateDriverStatus(String status) {
  switch (status.toLowerCase()) {
    case 'active': return 'نشط';
    case 'inactive': return 'غير نشط';
    case 'banned': return 'محظور';
    default: return status;
  }
}

  // دالة لترجمة حالة الرحلة
  String _translateStatus(String status) {
    switch (status) {
      case 'accepted': return 'مقبول';
      case 'Completed': return 'مكتمل';
      case 'Cancelled': return 'ملغى';
      case 'InProgress': return 'قيد التنفيذ';
      default: return status;
    }
  }
Future<String> _getDriverName(String? driverId) async {
  if (driverId == null || driverId.isEmpty) return 'غير معروف';
  
  try {
    DocumentSnapshot driverDoc = await FirebaseFirestore.instance
        .collection('drivers')
        .doc(driverId)
        .get();

    if (driverDoc.exists) {
      return driverDoc['name'] ?? 'غير معروف';
    }
    return 'غير معروف';
  } catch (e) {
    print('Error fetching driver: $e');
    return 'غير معروف';
  }
}
  // دالة لترجمة طريقة الدفع
  String _translatePaymentMethod(String method) {
    switch (method) {
      case 'cash': return 'نقدي';
      case 'card': return 'بطاقة ائتمانية';
      default: return method;
    }
  }

  // دالة لجلب الشكاوى المتعلقة بالرحلة
  Future<List<String>> _getTripComplaints(String tripId) async {
    try {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('complaints')
          .where('tripId', isEqualTo: tripId)
          .get();

      return querySnapshot.docs.map((doc) => doc['description'] as String).toList();
    } catch (error) {
      print('Error fetching complaints: $error');
      return [];
    }
  }

  // دالة لحساب المسافة (مثال - تحتاج للتعديل حسب منطق التطبيق)
  double _calculateDistance(String points) {
    // هنا يمكنك حساب المسافة الحقيقية بناء على نقاط الطريق
    return 10.0 + (points.length / 10); // مثال فقط
  }

  // دالة لحساب السعر (مثال - تحتاج للتعديل حسب منطق التطبيق)
  double _calculatePrice(String points, int time) {
    // هنا يمكنك حساب السعر الحقيقي بناء على المسافة والزمن
    return 20.0 + (points.length / 5) + (time / 60); // مثال فقط
  }
    Map<String, String> _drivers = {};
    Map<String, String> _users = {};

Future<void> _loadData() async {
  final drivers = await _fetchAllDrivers();
  final users = await _fetchAllUsers();

  setState(() {
    _drivers = drivers;
    _users=users ;
    _selectedPassenger=null;
    _selectedDriver = null; // أو drivers.keys.first إذا أردت تحديد أول سائق
  });
}
  @override
  Widget build(BuildContext context) {
    final filteredTrips = _filterTrips();
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor:Color(0xFF2A2A3A) ,
      appBar: AppBar(
        title: Text('إدارة الرحلات'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _fetchTrips,
          ),
          IconButton(
            icon: Icon(Icons.notifications),
            onPressed: () {},
          ),
        ],
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: 0,
            labelType: NavigationRailLabelType.all,
            destinations: [
              NavigationRailDestination(
                icon: Icon(Icons.directions_car),
                label: Text('الرحلات'),
              ),
            ],
            onDestinationSelected: (int index) {},
          ),
          VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: SingleChildScrollView(
              physics: BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSearchAndFilterBar(),
                    SizedBox(height: 20),
                    _buildQuickStats(),
                    SizedBox(height: 20),
_buildActiveTripsSection(),
SizedBox(height: 20),
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('إحصاء الرحلات الأسبوعية',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            SizedBox(height: 10),
                          Container(
  height: 250,
  child: SfCartesianChart(
    primaryXAxis: CategoryAxis(
      title: AxisTitle(text: 'أيام الأسبوع'),
    ),
    primaryYAxis: NumericAxis(
      title: AxisTitle(text: 'عدد الرحلات'),
      numberFormat: NumberFormat.compact(),
    ),
    axes: <ChartAxis>[
      NumericAxis(
        name: 'secondaryYAxis',
        opposedPosition: true,
        title: AxisTitle(text: 'الإيرادات (ج.م)'),
        numberFormat: NumberFormat.currency(symbol: 'ج.م'),
      ),
    ],
    series: <CartesianSeries>[
      ColumnSeries<WeeklyData, String>(
        dataSource: _getWeeklyData(),
        xValueMapper: (WeeklyData data, _) => data.day,
        yValueMapper: (WeeklyData data, _) => data.trips,
        name: 'الرحلات',
        color: Colors.blue,
        dataLabelSettings: DataLabelSettings(
          isVisible: true,
          labelAlignment: ChartDataLabelAlignment.outer,
        ),
      ),
      LineSeries<WeeklyData, String>(
        dataSource: _getWeeklyData(),
        xValueMapper: (WeeklyData data, _) => data.day,
        yValueMapper: (WeeklyData data, _) => data.income,
        name: 'الإيرادات',
        color: Colors.green,
        yAxisName: 'secondaryYAxis',
        markerSettings: MarkerSettings(isVisible: true),
      ),
    ],
    legend: Legend(isVisible: true),
    tooltipBehavior: TooltipBehavior(enable: true),
  ),
)

                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: MediaQuery.of(context).size.height * 0.5,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 2,
                            child: Card(
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('الرحلات الحديثة', style: theme.textTheme.bodyMedium),
                                        Chip(label: Text('${filteredTrips.length} رحلة')),
                                      ],
                                    ),
                                  ),
                                  ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxHeight: MediaQuery.of(context).size.height * 0.5,
                                    ),
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.vertical,
                                      child: _buildTripsTable(filteredTrips),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            flex: 1,
                            child: _buildTripDetailsCard(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildSearchAndFilterBar() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            // شريط البحث
            TextField(
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'ابحث برقم الرحلة أو السائق أو الراكب...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
            SizedBox(height: 12),
            // خيارات التصفية
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedFilter,
                    items: ['اليوم', 'الأمس', 'هذا الأسبوع', 'هذا الشهر', 'الكل']
                        .map((e) => DropdownMenuItem(
                              value: e,
                              child: Text(e),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedFilter = value!;
                      });
                    },
                    decoration: InputDecoration(
                      labelText: 'الفترة',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now().subtract(Duration(days: 365)),
                        lastDate: DateTime.now(),
                      );
                      setState(() {
                        _selectedDate = date;
                      });
                    },
                    icon: Icon(Icons.calendar_today),
                    label: Text(_selectedDate != null
                        ? DateFormat('yyyy-MM-dd').format(_selectedDate!)
                        : 'اختر تاريخ'),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
  child: DropdownButtonFormField<String>(
    value: _selectedDriver,
    items: [
      DropdownMenuItem(
        value: null, // Use null for "All drivers"
        child: Text('جميع السائقين'),
      ),
      ..._drivers.entries.map((entry) => DropdownMenuItem(
        value: entry.value, // Use driver ID as value
        child: Text(entry.value), // Show driver name
      )).toList(),
    ],
    onChanged: (value) {
      setState(() {
        _selectedDriver = value;
      });
    },
    decoration: InputDecoration(
      labelText: 'السائق',
      border: OutlineInputBorder(),
    ),
  ),

                ),
                SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
    value: _selectedPassenger,
    items: [
      DropdownMenuItem(
        value: null, // Use null for "All drivers"
        child: Text('جميع الركاب'),
      ),
      ..._users.entries.map((entry) => DropdownMenuItem(
        value: entry.value, // Use driver ID as value
        child: Text(entry.value), // Show driver name
      )).toList(),
    ],
    onChanged: (value) {
      setState(() {
        _selectedPassenger = value;
      });
    },
    decoration: InputDecoration(
      labelText: 'الراكب',
      border: OutlineInputBorder(),
    ),
  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
Widget _buildQuickStats() {
    final completedTrips = _trips.where((t) => t.status == 'مكتمل').length;
    final canceledTrips = _trips.where((t) => t.status == 'ملغى').length;
    final totalEarnings = _trips.fold(0.0, (sum, t) => sum + t.price);

    return Row(
      children: [
        _buildStatCard(
          icon: Icons.check_circle,
          color: Colors.green,
          title: 'مكتمل',
          value: '$completedTrips',
        ),
        SizedBox(width: 12),
        _buildStatCard(
          icon: Icons.cancel,
          color: Colors.red,
          title: 'ملغى',
          value: '$canceledTrips',
        ),
        SizedBox(width: 12),
        _buildStatCard(
          icon: Icons.monetization_on,
          color: Colors.blue,
          title: 'إجمالي الأرباح',
          value: '${totalEarnings.toStringAsFixed(2)} ج.م',
        ),
        SizedBox(width: 12),
        _buildStatCard(
          icon: Icons.timelapse,
          color: Colors.orange,
          title: 'متوسط الوقت',
          value: '${_calculateAverageDuration().inMinutes} دقيقة',
        ),
      ],
    );
  }

  Duration _calculateAverageDuration() {
    if (_trips.isEmpty) return Duration();
    int totalSeconds = _trips.fold(0, (sum, trip) => sum + trip.duration.inSeconds);
    return Duration(seconds: totalSeconds ~/ _trips.length);
  }
Widget _buildActiveTripsSection() {
  final activeTrips = _trips.where((trip) => trip.isActive).toList();
  
  return Card(
    elevation: 4,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'الرحلات الجارية الآن',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Chip(
                label: Text('${activeTrips.length} رحلة'),
                backgroundColor: Colors.blue.withOpacity(0.2),
              ),
            ],
          ),
          SizedBox(height: 12),
          activeTrips.isEmpty
              ? Center(
                  child: Column(
                    children: [
                      Icon(Icons.directions_car, size: 50, color: Colors.grey),
                      SizedBox(height: 8),
                      Text(
                        'لا توجد رحلات جارية حالياً',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: activeTrips.map((trip) => _buildActiveTripCard(trip)).toList(),
                ),
        ],
      ),
    ),
  );
}

Widget _buildActiveTripCard(Trip trip) {
  return Card(
    margin: EdgeInsets.symmetric(vertical: 8),
    elevation: 2,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    ),
    child: Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'الرحلة #${trip.id.substring(0, 6)}',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'إلى: ${trip.destination}',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
              Chip(
                label: Text('جارية'),
                backgroundColor: Colors.orange.withOpacity(0.2),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.person, size: 16, color: Colors.blue),
              SizedBox(width: 8),
              Text('السائق: ${trip.driver}'),
            ],
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.person_outline, size: 16, color: Colors.green),
              SizedBox(width: 8),
              Text('الراكب: ${trip.passenger}'),
            ],
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.timer, size: 16, color: Colors.purple),
              SizedBox(width: 8),
              Text('المدة: ${trip.duration.inMinutes} دقيقة'),
            ],
          ),
          SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
          ElevatedButton.icon(
  icon: Icon(Icons.location_on, size: 18),
  label: Text('اعرض مسار الرحله'),
  style: ElevatedButton.styleFrom(
    backgroundColor: Colors.blue,
    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  ),
  onPressed: () {
    if (trip.points != null && trip.points!.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MapScreen(polylinePoints: trip.points!),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('لا تتوفر بيانات المسار لهذه الرحلة')),
      );
    }
  },
),
              OutlinedButton.icon(
                icon: Icon(Icons.phone, size: 18),
                label: Text('اتصال'),
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onPressed: () {
                  // إجراء الاتصال
                },
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
  Widget _buildStatCard({
    required IconData icon,
    required Color color,
    required String title,
    required String value,
  }) {
    return Expanded(
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 28),
              SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTripsTable(List<Trip> trips) {
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: DataTable(
        columns: [
          DataColumn(label: Text('رقم الرحلة')),
          DataColumn(label: Text('التاريخ')),
          DataColumn(label: Text('السائق')),
          DataColumn(label: Text('الراكب')),
          DataColumn(label: Text('الحالة')),
          DataColumn(label: Text('الإجراءات')),
        ],
        rows: trips.map((trip) {
          return DataRow(
            cells: [
              DataCell(Text(trip.id)),
              DataCell(Text(DateFormat('yyyy-MM-dd HH:mm').format(trip.date))),
              DataCell(Text(trip.driver)),
              DataCell(Text(trip.passenger)),
              DataCell(
                Chip(
                  label: Text(trip.status),
                  backgroundColor: trip.status == 'مكتمل'
                      ? Colors.green.withOpacity(0.2)
                      : trip.status == 'ملغى'
                          ? Colors.red.withOpacity(0.2)
                          : Colors.blue.withOpacity(0.2),
                ),
              ),
              DataCell(
                IconButton(
                  icon: Icon(Icons.info_outline),
                  onPressed: () {
                    setState(() {
                      _selectedTrip = trip;
                    });
                  },
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
Widget _buildTripDetailsCard() {
  final theme = Theme.of(context);
  final isDarkMode = theme.brightness == Brightness.dark;
  
  // ألوان مخصصة للتطبيق
  final Color primaryColor = isDarkMode ? Colors.blue.shade200 : Colors.blue.shade700;
  final Color cardColor = isDarkMode ? Colors.grey.shade800 : Colors.white;
  final Color textColor = isDarkMode ? Colors.white : Colors.black87;

  if (_selectedTrip == null) {
    return Container(
      height: 400,
      child: Card(
        elevation: 4,
        color: cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.directions_car, 
                  size: 60, 
                  color: Colors.grey.withOpacity(0.5)),
              SizedBox(height: 20),
              Text(
                'اختر رحلة لعرض التفاصيل',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 30),

              
              ElevatedButton.icon(
                onPressed: () {
                  // يمكنك إضافة إجراء عند النقر هنا
                },

                
                icon: Icon(Icons.search, size: 20),
                label: Text('تصفح الرحلات',style: TextStyle(color: Colors.white),),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  final trip = _selectedTrip!;
  
  return IntrinsicHeight(
    child: Container(
 
      child: Card(
        elevation: 4,
        color: cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header مع زر الإغلاق
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'تفاصيل الرحلة',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.grey),
                    onPressed: () {
                      setState(() {
                        _selectedTrip = null;
                      });
                    },
                  ),
                ],
              ),
               Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'معلومات السائق',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  _buildDetailRow('الاسم', _selectedTrip!.driver, textColor),
                  _buildDetailRow('هاتف', _selectedTrip!.driverDetails['phone'] ?? 'غير متوفر', textColor),
                  _buildDetailRow('نوع السيارة', _selectedTrip!.driverDetails['carType'] ?? 'غير معروف', textColor),
                  _buildDetailRow('موديل السيارة', _selectedTrip!.driverDetails['carModel'] ?? 'غير معروف', textColor),
                  _buildDetailRow('رقم السيارة', _selectedTrip!.driverDetails['carNumber'] ?? 'غير معروف', textColor),
                  _buildDetailRow('التقييم', '${_selectedTrip!.driverDetails['rating'] ?? 0} / 5', textColor),
                ],
              ),
            ),
            
              Divider(color: Colors.grey.withOpacity(0.3)),
              SizedBox(height: 10),
              
              // معلومات الرحلة الأساسية
              Text(
                'رقم الرحلة: ${trip.id}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              SizedBox(height: 15),
              
              // تفاصيل الرحلة مع تمرير إذا لزم الأمر
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailRow('التاريخ', DateFormat('yyyy-MM-dd HH:mm').format(trip.date), textColor),
                      _buildDetailRow('السائق', trip.driver, textColor),
                      _buildDetailRow('الراكب', trip.passenger, textColor),
                      _buildDetailRow('المسافة', '${trip.distance} كم', textColor),
                      _buildDetailRow('السعر', '${trip.price} ج.م', textColor),
                      _buildDetailRow('المدة', '${trip.duration.inMinutes} دقيقة', textColor),
                      _buildDetailRow('طريقة الدفع', trip.paymentMethod, textColor),
                      _buildDetailRow('الحالة', trip.status, textColor),
                    Divider(color: Colors.grey.withOpacity(0.3)),
              SizedBox(height: 10),
              Text(
                'تسجيل الرحلة الصوتي',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                  
                ),
                textAlign: TextAlign.left,
              ),
              SizedBox(height: 8),
          if (_selectedTrip?.audioRecordingUrl != null && _selectedTrip!.audioRecordingUrl!.isNotEmpty)
  Column(
    children: [
      Row(
        children: [
          IconButton(
            icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
            onPressed: () async {
              if (_isPlaying) {
                await _audioPlayer.pause();
              } else {
                await _audioPlayer.play(UrlSource(_selectedTrip!.audioRecordingUrl!));
              }
              setState(() => _isPlaying = !_isPlaying);
            },
          ),
          SizedBox(width: 8),
          Expanded(
            child: Slider(
              min: 0,
              max: _duration.inMilliseconds.toDouble(),
              value: _position.inMilliseconds.clamp(0, _duration.inMilliseconds).toDouble(),
              onChanged: (value) async {
                await _audioPlayer.seek(Duration(milliseconds: value.toInt()));
              },
            ),
          ),
        ],
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_formatDuration(_position)),
            Text(_formatDuration(_duration)),
          ],
        ),
      ),
    ],
  ),
      Divider(color: Colors.grey.withOpacity(0.3)),
              SizedBox(height: 16),
                      Text(
                        'الشكاوى',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      ...trip.complaints.map((complaint) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.warning, 
                                    color: Colors.orange, 
                                    size: 18),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    complaint,
                                    style: TextStyle(color: textColor),
                                )),
                              ],
                            ),
                          )),
                      if (trip.complaints.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(
                            'لا توجد شكاوى',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              
              // أزرار الإجراءات
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                             if (trip.points != null && trip.points!.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MapScreen(polylinePoints: trip.points!),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('لا تتوفر بيانات المسار لهذه الرحلة')),
      );
    }
                        },
                        child: Text("عرض المسار"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          // إجراء حل الشكاوى
                        },
                        child: Text('حل الشكاوى'),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: primaryColor,
                          side: BorderSide(color: primaryColor),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

String _formatDuration(Duration duration) {
  String twoDigits(int n) => n.toString().padLeft(2, '0');
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);

  return [
    if (hours > 0) twoDigits(hours),
    twoDigits(minutes),
    twoDigits(seconds),
  ].join(':');
}
List<WeeklyData> _getWeeklyData() {
  // إنشاء خريطة لتخزين عدد الرحلات لكل يوم
  final Map<String, int> tripsPerDay = {
    'السبت': 0,
    'الأحد': 0,
    'الإثنين': 0,
    'الثلاثاء': 0,
    'الأربعاء': 0,
    'الخميس': 0,
    'الجمعة': 0,
  };

  // إنشاء خريطة لتخزين الإيرادات لكل يوم
  final Map<String, double> incomePerDay = {
    'السبت': 0,
    'الأحد': 0,
    'الإثنين': 0,
    'الثلاثاء': 0,
    'الأربعاء': 0,
    'الخميس': 0,
    'الجمعة': 0,
  };

  // حساب عدد الرحلات والإيرادات لكل يوم
  for (final trip in _trips) {
    final dayName = _getDayName(trip.date);
    tripsPerDay[dayName] = (tripsPerDay[dayName] ?? 0) + 1;
    incomePerDay[dayName] = (incomePerDay[dayName] ?? 0) + trip.price;
  }

  // تحويل الخرائط إلى قائمة WeeklyData
  return [
    WeeklyData('السبت', tripsPerDay['السبت']!, incomePerDay['السبت']!),
    WeeklyData('الأحد', tripsPerDay['الأحد']!, incomePerDay['الأحد']!),
    WeeklyData('الإثنين', tripsPerDay['الإثنين']!, incomePerDay['الإثنين']!),
    WeeklyData('الثلاثاء', tripsPerDay['الثلاثاء']!, incomePerDay['الثلاثاء']!),
    WeeklyData('الأربعاء', tripsPerDay['الأربعاء']!, incomePerDay['الأربعاء']!),
    WeeklyData('الخميس', tripsPerDay['الخميس']!, incomePerDay['الخميس']!),
    WeeklyData('الجمعة', tripsPerDay['الجمعة']!, incomePerDay['الجمعة']!),
  ];
}

// دالة مساعدة للحصول على اسم اليوم العربي
String _getDayName(DateTime date) {
  switch (date.weekday) {
    case DateTime.saturday:
      return 'السبت';
    case DateTime.sunday:
      return 'الأحد';
    case DateTime.monday:
      return 'الإثنين';
    case DateTime.tuesday:
      return 'الثلاثاء';
    case DateTime.wednesday:
      return 'الأربعاء';
    case DateTime.thursday:
      return 'الخميس';
    case DateTime.friday:
      return 'الجمعة';
    default:
      return 'غير معروف';
  }
}
// دالة مساعدة لعرض صف التفاصيل
Widget _buildDetailRow(String label, String value, Color textColor) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8.0),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey,
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: textColor,
            fontSize: 14,
          ),
        ),
      ],
    ),
  );
}

  List<Trip> _filterTrips() {
 
  var trips = _trips.where((trip) => !trip.isActive).toList(); // استبعاد الرحلات الجارية

    // التصفية حسب نص البحث
    if (_searchQuery.isNotEmpty) {
      trips = trips.where((trip) {
        return trip.id.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            trip.driver.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            trip.passenger.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }

    // التصفية حسب التاريخ المحدد
    if (_selectedDate != null) {
      trips = trips.where((trip) {
        return trip.date.year == _selectedDate!.year &&
            trip.date.month == _selectedDate!.month &&
            trip.date.day == _selectedDate!.day;
      }).toList();
    }

    // التصفية حسب الفترة الزمنية
    switch (_selectedFilter) {
      case 'اليوم':
        trips = trips.where((trip) {
          return trip.date.day == DateTime.now().day;
        }).toList();
        break;
      case 'الأمس':
        trips = trips.where((trip) {
          return trip.date.day == DateTime.now().subtract(Duration(days: 1)).day;
        }).toList();
        break;
      case 'هذا الأسبوع':
        trips = trips.where((trip) {
          return trip.date.isAfter(DateTime.now().subtract(Duration(days: 7)));
        }).toList();
        break;
      case 'هذا الشهر':
        trips = trips.where((trip) {
          return trip.date.month == DateTime.now().month;
        }).toList();
        break;
    }

    // التصفية حسب السائق
  // التصفية حسب السائق
  if (_selectedDriver != null) {
    trips = trips.where((trip) {
      return trip.driver == _selectedDriver; // قارن بـ ID السائق وليس الاسم
    }).toList();
  }


    // التصفية حسب الراكب
    if (_selectedPassenger != null) {
      trips = trips.where((trip) => trip.passenger == _selectedPassenger).toList();
    }

    return trips;
  }   
}
class Trip {
  final String id;
  final DateTime date;
  final String driver;
  final String passenger;
  final double distance;
  final double price;
  final Duration duration;
  final String paymentMethod;
  final String status;
  final String destination;
  final List<String> complaints;
  final Map<String, dynamic> driverDetails;
  final String? audioRecordingUrl;
  final bool isActive; // أضف هذا الحقل الجديد
  final String? points; // إضافة حقل نقاط المسار
  
  Trip({
    required this.id,
    required this.date,
    required this.driver,
    required this.passenger,
    required this.distance,
    required this.price,
    required this.duration,
    required this.paymentMethod,
    required this.status,
    required this.destination,
    required this.complaints,
    required this.driverDetails,
    this.audioRecordingUrl,
    this.isActive = false, // قيمة افتراضية
        this.points,
  });
}
class WeeklyData {
  final String day;
  final int trips;
  final double income;

  WeeklyData(this.day, this.trips, this.income);
}