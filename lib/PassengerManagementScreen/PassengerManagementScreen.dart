import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
double _calculateRating(dynamic ratingData) {
  if (ratingData is Map && ratingData['count'] != null && ratingData['count'] != 0) {
    final total = (ratingData['total'] ?? 0).toDouble();
    final count = (ratingData['count'] ?? 0).toDouble();
    return total / count;
  }
  return 0.0;
}


class PremiumPassengerDashboard extends StatefulWidget {
  @override
  _PremiumPassengerDashboardState createState() => _PremiumPassengerDashboardState();
}

class _PremiumPassengerDashboardState extends State<PremiumPassengerDashboard> {
  int _selectedTab = 0;
  List<Passenger> _passengers = [];
  List<Ride> _rides = [];
  List<DriverRating> _ratings = [];String? _selectedPassengerId;
  String _searchQuery = '';
int _totalTrips = 0;
  double _avgRating = 0;
  // ألوان التصميم المتميز
  final Color _primaryColor = Color(0xFF6C5CE7);
  final Color _secondaryColor = Color(0xFF00CEFF);
  final Color _darkColor = Color(0xFF2D3436);
  final Color _successColor = Color(0xFF00B894);
  final Color _warningColor = Color(0xFFFDCB6E);
  final Color _dangerColor = Color(0xFFD63031);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
@override
void initState() {
  super.initState();
  _loadPassengersFromFirestore();
  _loadRidesFromFirestore(); // بدلاً من _loadSampleData()
  _loadRatingsFromFirestore(); // إذا كنت تريد تحميل التقييمات أيضًا
}

Future<void> _loadPassengersFromFirestore() async {
  try {
    QuerySnapshot querySnapshot = await _firestore.collection('users').get();

    List<Passenger> loadedPassengers = [];
    int totalTrips = 0;
    double totalRating = 0.0;
    int ratingCount = 0;

    for (var doc in querySnapshot.docs) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

      if (data['email'] != null && data['name'] != null && data['phone'] != null) {
        // تحويل عدد الرحلات إلى int بشكل آمن
        int trips = 0;
        if (data['trips'] is int) {
          trips = data['trips'];
        } else if (data['trips'] is double) {
          trips = (data['trips'] as double).toInt();
        } else if (data['trips'] is num) {
          trips = (data['trips'] as num).toInt();
        }

        // استدعاء دالة لحساب التقييم وتحويله إلى double
        double rating = _calculateRating(data['rating']);

        loadedPassengers.add(Passenger(
          id: data['id'] ,
          name: data['name'] ?? 'بدون اسم',
          phone: data['phone'] ?? 'بدون رقم',
          email: data['email'] ?? 'بدون بريد',
          image: data['imageUrl'] ?? '',
          isBlocked: data['isBlocked'] ?? false,
          joinDate: (data['joinDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
          username: data['username'] ?? '',
          role: data['role'] ?? 'user',
          tripNumber: trips,
          rating: rating,
        ));

        totalTrips += trips;
        totalRating += rating;
        if (rating > 0) ratingCount++;
      }
    }

    final avgRating = ratingCount > 0 ? totalRating / ratingCount : 0.0;

    setState(() {
      _passengers = loadedPassengers;
      _totalTrips = totalTrips;
      _avgRating = avgRating;
    });

  } catch (e) {
    print('Error loading passengers: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('حدث خطأ في تحميل بيانات الركاب')));
  }
}

Widget _buildNetworkImage(String? imageUrl) {
  if (imageUrl == null || imageUrl.isEmpty) {
    return CircleAvatar(
      backgroundColor: Colors.grey[200],
      child: Icon(Icons.person, color: Colors.grey),
    );
  }

  return CircleAvatar(
    backgroundImage: NetworkImage(imageUrl),
    backgroundColor: Colors.grey[200],
    onBackgroundImageError: (e, stack) {
      print('Error loading image: $e');
    },
  );
}

Future<void> _loadRatingsFromFirestore() async {
  try {
    QuerySnapshot querySnapshot = await _firestore.collection('ratings')
        .orderBy('date', descending: true)
        .limit(20)
        .get();

    List<DriverRating> loadedRatings = [];
    
    for (var doc in querySnapshot.docs) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      
      loadedRatings.add(DriverRating(
        id: doc.id,
        passengerId: data['userId']?.toString() ?? '',
        passengerName: data['userName']?.toString() ?? 'راكب غير معروف',
        passengerImage: data['userImage']?.toString() ?? 'assets/users/user_default.jpg',
        driverName: data['driverName']?.toString() ?? 'سائق غير معروف',
        driverImage: data['driverImage']?.toString() ?? 'assets/drivers/driver_default.jpg',
        rating: (data['rating'] as num?)?.toDouble() ?? 0.0,
        comment: data['comment']?.toString() ?? 'لا توجد تعليقات',
        date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
        rideId: data['rideId']?.toString() ?? '',
      ));
    }

    setState(() {
      _ratings = loadedRatings;
    });

  } catch (e) {
    print('Error loading ratings: $e');
  }
}
List<DriverRating> _getFilteredRatings() {
  if (_selectedPassengerId == null || _selectedPassengerId!.isEmpty) {
    return _ratings;
  }
  return _ratings.where((rating) => rating.passengerId == _selectedPassengerId).toList();
}
 Future<void> _loadRidesFromFirestore() async {
  try {
    QuerySnapshot querySnapshot = await _firestore.collection('trips')
        .orderBy('createdAt', descending: true)
        .limit(50) // يمكنك تعديل العدد حسب الحاجة
        .get();

    List<Ride> loadedRides = [];
   for (var doc in querySnapshot.docs) {
  Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

  DateTime createdAt;
  if (data['createdAt'] is Timestamp) {
    createdAt = (data['createdAt'] as Timestamp).toDate();
  } else if (data['createdAt'] is String) {
    createdAt = DateTime.tryParse(data['createdAt']) ?? DateTime.now();
  } else {
    createdAt = DateTime.now();
  }

  final driverId = data['driver']?.toString() ?? '';
  String driverName = 'سائق غير معروف';
  String driverImage = 'assets/drivers/driver_default.jpg';
if (driverId.isNotEmpty) {
  try {
    final driverQuery = await _firestore
        .collection('drivers')
        .where('id', isEqualTo: driverId)
        .limit(1)
        .get();

    if (driverQuery.docs.isNotEmpty) {
      final driverData = driverQuery.docs.first.data();
      driverName = driverData['name'] ?? driverName;
      driverImage = driverData['imageUrl'] ?? driverImage;
    }
  } catch (e) {
    print('خطأ أثناء جلب بيانات السائق: $e');
  }
}


  loadedRides.add(Ride(
    id: doc.id,
    passengerId: data['userId']?.toString() ?? '',
    driverId: driverId,
    driverName: driverName,
    driverImage: driverImage,
    pickup: data['origin']?.toString() ?? 'موقع غير معروف',
    destination: data['destination']?.toString() ?? 'وجهة غير معروفة',
    date: createdAt,
    fare: (data['fare'] as num?)?.toDouble() ?? 0.0,
    status: _getRideStatus(data['status']?.toString()),
 duration: _formatDuration(data['time']),

    distance: '${((data['distance'] as num?)?.toDouble() ?? 0).toStringAsFixed(1)} كم',
  ));
}

    setState(() {
      _rides = loadedRides;
    });

  } catch (e) {
    print('Error loading rides: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('حدث خطأ في تحميل بيانات الرحلات')));
  }
}

String _getRideStatus(String? status) {
  switch (status?.toLowerCase()) {
    case 'completed':
      return 'مكتملة';
    case 'cancelled':
      return 'ملغاة';
    case 'in_progress':
      return 'قيد التنفيذ';
    case 'accepted':
      return 'مقبولة';
    default:
      return 'غير معروفة';
  }
}

String _formatDuration(dynamic millisecondsInput) {
  int milliseconds = 0;

  if (millisecondsInput is int) {
    milliseconds = millisecondsInput;
  } else if (millisecondsInput is String) {
    milliseconds = int.tryParse(millisecondsInput) ?? 0;
  }

  final duration = Duration(milliseconds: milliseconds);
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);

  if (hours > 0) {
    return '${hours} ساعة ${minutes} دقيقة';
  } else {
    return '${minutes} دقيقة';
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          _buildAppBar(),
          _buildHeader(),
          _buildTabBar(),
          Expanded(
            child: _buildSelectedTab(),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top, left: 16, right: 16, bottom: 16),
      decoration: BoxDecoration(
        color: _primaryColor,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withOpacity(0.4),
            blurRadius: 15,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {},
          ),
          Expanded(
            child: Text(
              'إدارة الركاب',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                fontFamily: 'Tajawal',
              ),
              textAlign: TextAlign.center,
            ),
          ),
          IconButton(
            icon: Icon(Icons.notifications_none, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
    );
  }
Widget _buildHeader() {
  return Padding(
    padding: EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'إحصائيات الركاب',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: 'Tajawal',
            color: _darkColor,
          ),
        ),
        SizedBox(height: 16),
        Row(
          children: [
            _buildStatCard(
              title: 'إجمالي الركاب',
              value: "${_passengers.length}",
              icon: Icons.people_outline,
              color: _primaryColor,
        
            ),
            SizedBox(width: 10),
            _buildStatCard(
              title: 'إجمالي الرحلات',
              value: "$_totalTrips",
              icon: Icons.directions_car,
              color: _secondaryColor,
 
            ),
            SizedBox(width: 10),
            _buildStatCard(
              title: 'معدل التقييم',
              value: _avgRating.toStringAsFixed(1),
              icon: Icons.star_outline,
              color: _warningColor,
            
            ),
          ],
        ),
      ],
    ),
  );
}
  Widget _buildStatCard({required String title, required String value, required IconData icon, required Color color}) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
              
             
              ],
            ),
            SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey[600],
                fontFamily: 'Tajawal',
                fontSize: 12,
              ),
            ),
            SizedBox(height: 5),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                fontFamily: 'Tajawal',
                color: _darkColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildTabItem(0, 'الركاب', Icons.people_alt_outlined),
          _buildTabItem(1, 'الرحلات', Icons.history),
          _buildTabItem(2, 'التقييمات', Icons.star_rate_rounded),
        ],
      ),
    );
  }

  Widget _buildTabItem(int index, String title, IconData icon) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            setState(() {
              _selectedTab = index;
            });
          },
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: _selectedTab == index ? _primaryColor : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: _selectedTab == index ? _primaryColor : Colors.grey[400],
                  size: 24,
                ),
                SizedBox(height: 4),
                Text(
                  title,
                  style: TextStyle(
                    color: _selectedTab == index ? _primaryColor : Colors.grey[600],
                    fontFamily: 'Tajawal',
                    fontSize: 12,
                    fontWeight: _selectedTab == index ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedTab() {
    switch (_selectedTab) {
      case 0:
        return _buildPassengersTab();
      case 1:
        return _buildRidesTab();
      case 2:
        return _buildRatingsTab();
      default:
        return Container();
    }
  }

  Widget _buildPassengersTab() {
    List<Passenger> filteredPassengers = _passengers.where((passenger) {
      return passenger.name.contains(_searchQuery) || 
             passenger.phone.contains(_searchQuery) ||
             passenger.email.contains(_searchQuery);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(16),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 10,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'ابحث عن راكب...',
                hintStyle: TextStyle(fontFamily: 'Tajawal'),
                prefixIcon: Icon(Icons.search, color: Colors.grey),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              style: TextStyle(fontFamily: 'Tajawal'),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.only(bottom: 16),
            itemCount: filteredPassengers.length,
            itemBuilder: (context, index) {
              return _buildPassengerCard(filteredPassengers[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPassengerCard(Passenger passenger) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Material(
        borderRadius: BorderRadius.circular(15),
        elevation: 2,
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: () {
            // تفاصيل الراكب
          },
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              children: [
                Container(
  width: 60,
  height: 60,
  decoration: BoxDecoration(
    shape: BoxShape.circle,
    border: Border.all(
      color: passenger.isBlocked 
          ? _dangerColor.withOpacity(0.5) 
          : _successColor.withOpacity(0.5),
      width: 2,
    ),
  ),
  child: _buildNetworkImage(passenger.image),
),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            passenger.name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Tajawal',
                              color: _darkColor,
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: passenger.isBlocked ? _dangerColor.withOpacity(0.1) : _successColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              passenger.isBlocked ? 'محظور' : 'نشط',
                              style: TextStyle(
                                color: passenger.isBlocked ? _dangerColor : _successColor,
                                fontFamily: 'Tajawal',
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Text(
                        passenger.phone,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontFamily: 'Tajawal',
                          fontSize: 12,
                        ),
                      ),
                      if (passenger.username.isNotEmpty) ...[
                        SizedBox(height: 4),
                        Text(
                          '@${passenger.username}',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontFamily: 'Tajawal',
                            fontSize: 11,
                          ),
                        ),
                      ],
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.directions_car, size: 14, color: _primaryColor),
                          SizedBox(width: 4),
                          Text(
                            '${passenger.tripNumber} رحلة',
                            style: TextStyle(
                              color: _darkColor,
                              fontFamily: 'Tajawal',
                              fontSize: 12,
                            ),
                          ),
                          SizedBox(width: 12),
                          Icon(Icons.star, size: 14, color: _warningColor),
                          SizedBox(width: 4),
                          Text(
                            passenger.rating.toStringAsFixed(1),
                            style: TextStyle(
                              color: _darkColor,
                              fontFamily: 'Tajawal',
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.more_vert, color: Colors.grey),
                  onPressed: () {
                    _showPassengerOptions(passenger);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  List<Ride> _getFilteredRides() {
  if (_selectedPassengerId == null || _selectedPassengerId!.isEmpty) {
    return _rides;
  }
  return _rides.where((ride) => ride.passengerId == _selectedPassengerId).toList();
}
Widget _buildRidesTab() {
  final filteredRides = _getFilteredRides();
  
  return Column(
    children: [
      if (_selectedPassengerId != null) 
        Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.arrow_back, color: _primaryColor),
              SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedPassengerId = null;
                  });
                },
                child: Text(
                  'عرض جميع الرحلات',
                  style: TextStyle(
                    color: _primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      // باقي الكود كما هو...
      Expanded(
        child: RefreshIndicator(
          onRefresh: _loadRidesFromFirestore,
          child: filteredRides.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history, size: 60, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        _selectedPassengerId != null 
                            ? 'لا توجد رحلات لهذا الراكب'
                            : 'لا توجد رحلات متاحة',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.only(bottom: 16),
                  itemCount: filteredRides.length,
                  itemBuilder: (context, index) {
                    return _buildRideCard(filteredRides[index]);
                  },
                ),
        ),
      ),
    ],
  );
}

Widget _buildRidesChart() {
  // يمكنك إضافة رسم بياني للرحلات هنا
  return SfCartesianChart(
    primaryXAxis: CategoryAxis(
      labelStyle: TextStyle(fontFamily: 'Tajawal'),
    ),
    primaryYAxis: NumericAxis(
      labelStyle: TextStyle(fontFamily: 'Tajawal'),
    ),
    series: <CartesianSeries>[
      ColumnSeries<Map<String, dynamic>, String>(
        dataSource: _getWeeklyRidesData(),
        xValueMapper: (data, _) => data['day'],
        yValueMapper: (data, _) => data['rides'],
        color: _primaryColor,
      ),
    ],
  );
}

List<Map<String, dynamic>> _getWeeklyRidesData() {
  // يمكنك استبدال هذا ببيانات حقيقية من Firestore
  return [
    {'day': 'السبت', 'rides': _rides.where((r) => r.date.weekday == 6).length},
    {'day': 'الأحد', 'rides': _rides.where((r) => r.date.weekday == 7).length},
    {'day': 'الإثنين', 'rides': _rides.where((r) => r.date.weekday == 1).length},
    {'day': 'الثلاثاء', 'rides': _rides.where((r) => r.date.weekday == 2).length},
    {'day': 'الأربعاء', 'rides': _rides.where((r) => r.date.weekday == 3).length},
    {'day': 'الخميس', 'rides': _rides.where((r) => r.date.weekday == 4).length},
    {'day': 'الجمعة', 'rides': _rides.where((r) => r.date.weekday == 5).length},
  ];
}
Widget _buildRideCard(Ride ride) {
  // احصل على بيانات الراكب إذا لزم الأمر
  final passenger = _passengers.firstWhere(
    (p) => p.id == ride.passengerId,
    orElse: () => Passenger(
      id: '',
      name: 'راكب غير معروف',
      phone: '',
      email: '',
      image: '',
      isBlocked: false,
      joinDate: DateTime.now(),
      username: '',
      role: '',
      tripNumber: 0,
      rating: 0,
    ),
  );

  return Container(
    margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Material(
      borderRadius: BorderRadius.circular(15),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () => _showRideDetails(ride),
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Column(
            children: [
              if (_selectedPassengerId == null) ...[
                Row(
                  children: [
                    CircleAvatar(
                      backgroundImage: NetworkImage(passenger.image),
                      onBackgroundImageError: (e, _) => Icon(Icons.person),
                    ),
                    SizedBox(width: 12),
                    Text(passenger.name),
                  ],
                ),
                SizedBox(height: 12),
              ],
              Row(
                children: [
                  CircleAvatar(
                    backgroundImage: NetworkImage(ride.driverImage),
                    onBackgroundImageError: (e, _) => Icon(Icons.person),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(ride.driverName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Tajawal')),
                        SizedBox(height: 4),
                        Text(DateFormat('yyyy/MM/dd - hh:mm a').format(ride.date),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12)),
                      ],
                    ),
                  ),
                  Chip(
                    label: Text('${ride.fare.toStringAsFixed(0)} ج.م'),
                    backgroundColor: _primaryColor.withOpacity(0.1),
                    labelStyle: TextStyle(color: _primaryColor),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  _buildLocationInfo(Icons.location_on, _primaryColor, ride.pickup),
                  _buildLocationInfo(Icons.location_on, _secondaryColor, ride.destination),
                  _buildLocationInfo(Icons.timer, _successColor, ride.duration),
                ],
              ),
              SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Chip(
                    label: Text(ride.status),
                    backgroundColor: _getStatusColor(ride.status),
                  ),
                  TextButton(
                    onPressed: () => _showRideDetails(ride),
                    child: Text('التفاصيل',
                      style: TextStyle(color: _primaryColor)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget _buildLocationInfo(IconData icon, Color color, String text) {
  return Expanded(
    child: Column(
      children: [
        Icon(icon, color: color, size: 20),
        SizedBox(height: 8),
        Text(text,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis),
      ],
    ),
  );
}

Color _getStatusColor(String status) {
  switch (status) {
    case 'مكتملة':
      return _successColor.withOpacity(0.2);
    case 'ملغاة':
      return _dangerColor.withOpacity(0.2);
    case 'قيد التنفيذ':
      return _warningColor.withOpacity(0.2);
    default:
      return Colors.grey.withOpacity(0.2);
  }
}

void _showRideDetails(Ride ride) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('تفاصيل الرحلة', textAlign: TextAlign.center),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildRideDetailItem('السائق', ride.driverName),
            _buildRideDetailItem('التاريخ', DateFormat('yyyy/MM/dd - hh:mm a').format(ride.date)),
            _buildRideDetailItem('النقطة الأولى', ride.pickup),
            _buildRideDetailItem('الوجهة', ride.destination),
            _buildRideDetailItem('المسافة', ride.distance),
            _buildRideDetailItem('المدة', ride.duration),
            _buildRideDetailItem('الحالة', ride.status),
            _buildRideDetailItem('التكلفة', '${ride.fare.toStringAsFixed(0)}  ج.م'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('إغلاق')),
      ],
    ),
  );
}

Widget _buildRideDetailItem(String label, String value) {
  return Padding(
    padding: EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Text('$label: ',
          style: TextStyle(fontWeight: FontWeight.bold)),
        Expanded(child: Text(value)),
      ],
    ),
  );
}

Widget _buildRatingsTab() {
  final filteredRatings = _getFilteredRatings();
  
  return Column(
    children: [
      if (_selectedPassengerId != null) 
        Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.arrow_back, color: _primaryColor),
              SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedPassengerId = null;
                  });
                },
                child: Text(
                  'عرض جميع التقييمات',
                  style: TextStyle(
                    color: _primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      Expanded(
        child: ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: filteredRatings.length,
          itemBuilder: (context, index) {
            return _buildRatingCard(filteredRatings[index]);
          },
        ),
      ),
    ],
  );
}

  Widget _buildRatingCard(DriverRating rating) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    image: DecorationImage(
                      image: AssetImage(rating.passengerImage),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rating.passengerName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Tajawal',
                          color: _darkColor,
                        ),
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.person, size: 14, color: Colors.grey),
                          SizedBox(width: 4),
                          Text(
                            rating.driverName,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontFamily: 'Tajawal',
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _warningColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.star, color: _warningColor, size: 16),
                      SizedBox(width: 4),
                      Text(
                        rating.rating.toString(),
                        style: TextStyle(
                          color: _darkColor,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Tajawal',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Text(
              rating.comment,
              style: TextStyle(
                fontFamily: 'Tajawal',
                color: _darkColor,
              ),
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('yyyy/MM/dd - hh:mm a').format(rating.date),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontFamily: 'Tajawal',
                    fontSize: 12,
                  ),
                ),
                TextButton(
                  onPressed: () {},
                  child: Text(
                    'عرض الرحلة',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      color: _primaryColor,
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

  void _showPassengerOptions(Passenger passenger) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
           
        ListTile(
  leading: Icon(Icons.history, color: _primaryColor),
  title: Text('سجل الرحلات', style: TextStyle(fontFamily: 'Tajawal')),
  onTap: () {
    setState(() {
      _selectedPassengerId = passenger.id;
      _selectedTab = 1;
    });
    Navigator.pop(context);
  },
),
            ListTile(
  leading: Icon(Icons.star, color: _primaryColor),
  title: Text('التقييمات', style: TextStyle(fontFamily: 'Tajawal')),
  onTap: () {
    setState(() {
      _selectedPassengerId = passenger.id;
      _selectedTab = 2;
    });
    Navigator.pop(context);
  },
),
              Divider(),
              ListTile(
                leading: Icon(
                  passenger.isBlocked ? Icons.lock_open : Icons.block,
                  color: passenger.isBlocked ? _successColor : _dangerColor,
                ),
                title: Text(
                  passenger.isBlocked ? 'إلغاء الحظر' : 'حظر المستخدم',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    color: passenger.isBlocked ? _successColor : _dangerColor,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _togglePassengerBlock(passenger.id, !passenger.isBlocked);
                },
              ),
            ],
          ),
        );
      },
    );
  } void _togglePassengerBlock(String passengerId, bool block) async {
    try {
      await _firestore.collection('users').doc(passengerId).update({
        'isBlocked': block,
      });

      setState(() {
        _passengers = _passengers.map((passenger) {
          if (passenger.id == passengerId) {
            return Passenger(
              id: passenger.id,
              name: passenger.name,
              phone: passenger.phone,
              email: passenger.email,
              image: passenger.image,
              isBlocked: block,
              joinDate: passenger.joinDate,
              username: passenger.username,
              role: passenger.role,
              tripNumber: passenger.tripNumber,
              rating: passenger.rating
            );
          }
          return passenger;
        }).toList();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            block ? 'تم حظر المستخدم بنجاح' : 'تم إلغاء حظر المستخدم',
            style: TextStyle(fontFamily: 'Tajawal'),
          ),
          backgroundColor: block ? _dangerColor : _successColor,
        ),
      );
    } catch (e) {
      print('Error updating user block status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'حدث خطأ أثناء تحديث حالة المستخدم',
            style: TextStyle(fontFamily: 'Tajawal'),
          ),
          backgroundColor: _dangerColor,
        ),
      );
    }
  }
}
class Passenger {
  final String id;
  final String name;
  final String phone;
  final String email;
  final String image;
  final bool isBlocked;
  final DateTime joinDate;
  final double rating;
 
  final String username;
  final String role;
  final int tripNumber;

  Passenger({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.image,
    required this.isBlocked,
    required this.joinDate,
    required this.username,
    required this.role,
    required this.tripNumber,
    required this.rating,


  });
}


class Ride {
  final String id;
  
  final String passengerId;
  final String driverId;

  final String driverName;
  final String driverImage;
  final String pickup;
  final String destination;
  final DateTime date;
  final double fare;
  final String status;
  final String duration;
  final String distance;

  Ride({
    required this.id,
    required this.passengerId,
    required this.driverId,

    required this.driverName,
    required this.driverImage,
    required this.pickup,
    required this.destination,
    required this.date,
    required this.fare,
    required this.status,
    required this.duration,
    required this.distance,
  });
}

class DriverRating {
  final String id;
  final String passengerId;
  final String passengerName;
  final String passengerImage;
  final String driverName;
  final String driverImage;
  final double rating;
  final String comment;
  final DateTime date;
  final String rideId;

  DriverRating({
    required this.id,
    required this.passengerId,
    required this.passengerName,
    required this.passengerImage,
    required this.driverName,
    required this.driverImage,
    required this.rating,
    required this.comment,
    required this.date,
    required this.rideId,
  });
}