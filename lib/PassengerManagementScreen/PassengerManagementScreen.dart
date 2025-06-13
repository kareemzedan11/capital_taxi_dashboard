import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class PremiumPassengerDashboard extends StatefulWidget {
  @override
  _PremiumPassengerDashboardState createState() => _PremiumPassengerDashboardState();
}

class _PremiumPassengerDashboardState extends State<PremiumPassengerDashboard> {
  int _selectedTab = 0;
  List<Passenger> _passengers = [];
  List<Ride> _rides = [];
  List<DriverRating> _ratings = [];
  String _searchQuery = '';

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
    _loadSampleData(); // نبقى على بيانات الرحلات والتقييمات النموذجية مؤقتاً
  }

  Future<void> _loadPassengersFromFirestore() async {
    try {
      QuerySnapshot querySnapshot = await _firestore.collection('users').get();
      
      List<Passenger> loadedPassengers = [];
      
      for (var doc in querySnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        
        // تحقق من وجود الحقول الأساسية
        if (data['email'] != null && data['name'] != null && data['phone'] != null) {
          loadedPassengers.add(Passenger(
            id: doc.id,
            name: data['name'] ?? 'بدون اسم',
            phone: data['phone'] ?? 'بدون رقم',
            email: data['email'] ?? 'بدون بريد',
            image: 'assets/users/user${(loadedPassengers.length % 3) + 1}.jpg', // صور افتراضية
            isBlocked: data['isBlocked'] ?? false,
            joinDate: (data['joinDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
           
            username: data['username'] ?? '',
            role: data['role'] ?? 'user',
            tripNumber: data['tripNumber']??"غير معروف",
            rating: data['rating']??"غير معروف",
          ));
        }
      }
      
      setState(() {
        _passengers = loadedPassengers;
      });
      
    } catch (e) {
      print('Error loading passengers: $e');
      // يمكنك عرض رسالة خطأ للمستخدم هنا إذا لزم الأمر
    }
  }

  void _loadSampleData() {
    // نبقى على بيانات الرحلات والتقييمات النموذجية كما هي
    _rides = [
      Ride(
        id: '1',
        passengerId: '1',
        driverName: 'خالد عبدالله',
        driverImage: 'assets/drivers/driver1.jpg',
        pickup: 'حي النخيل، الرياض',
        destination: 'حي السفارات، الرياض',
        date: DateTime.now().subtract(Duration(days: 5)),
        fare: 45.0,
        status: 'مكتملة',
        duration: '25 دقيقة',
        distance: '12.5 كم',
      ),
      Ride(
        id: '2',
        passengerId: '1',
        driverName: 'محمد علي',
        driverImage: 'assets/drivers/driver2.jpg',
        pickup: 'حي العليا، الرياض',
        destination: 'مطار الملك خالد',
        date: DateTime.now().subtract(Duration(days: 2)),
        fare: 60.0,
        status: 'مكتملة',
        duration: '40 دقيقة',
        distance: '22 كم',
      ),
    ];

    _ratings = [
      DriverRating(
        id: '1',
        passengerId: '1',
        passengerName: 'أحمد محمد',
        passengerImage: 'assets/users/user1.jpg',
        driverName: 'خالد عبدالله',
        driverImage: 'assets/drivers/driver1.jpg',
        rating: 4.5,
        comment: 'قيادة ممتازة ومركبة نظيفة. كان مهذبًا ومحترمًا للوقت.',
        date: DateTime.now().subtract(Duration(days: 5)),
        rideId: '1',
      ),
      DriverRating(
        id: '2',
        passengerId: '1',
        passengerName: 'أحمد محمد',
        passengerImage: 'assets/users/user1.jpg',
        driverName: 'محمد علي',
        driverImage: 'assets/drivers/driver2.jpg',
        rating: 3.0,
        comment: 'تأخر قليلاً في الوصول لكن الرحلة كانت مريحة.',
        date: DateTime.now().subtract(Duration(days: 2)),
        rideId: '2',
      ),
    ];
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
                change: '0',
              ),
              SizedBox(width: 10),
              _buildStatCard(
                title: 'رحلات اليوم',
                value: '0',
                icon: Icons.directions_car,
                color: _secondaryColor,
                change: '00%',
              ),
              SizedBox(width: 10),
              _buildStatCard(
                title: 'معدل التقييم',
                value: '0',
                icon: Icons.star_outline,
                color: _warningColor,
                change: '0',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({required String title, required String value, required IconData icon, required Color color, required String change}) {
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
                Text(
                  change,
                  style: TextStyle(
                    color: change.startsWith('+') ? _successColor : _dangerColor,
                    fontFamily: 'Tajawal',
                    fontWeight: FontWeight.bold,
                  ),
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
                    image: DecorationImage(
                      image: AssetImage(passenger.image),
                      fit: BoxFit.cover,
                    ),
                    border: Border.all(
                      color: passenger.isBlocked ? _dangerColor.withOpacity(0.5) : _successColor.withOpacity(0.5),
                      width: 2,
                    ),
                  ),
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
  Widget _buildRidesTab() {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Container(
  height: 200,
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
  padding: EdgeInsets.all(16),
  child: SfCartesianChart(
    primaryXAxis: CategoryAxis(
      labelStyle: TextStyle(fontFamily: 'Tajawal'),
    ),
    primaryYAxis: NumericAxis(
      labelStyle: TextStyle(fontFamily: 'Tajawal'),
    ),
    series: <CartesianSeries>[
      ColumnSeries<Map<String, dynamic>, String>(
        dataSource: [
          {'day': 'السبت', 'rides': 45},
          {'day': 'الأحد', 'rides': 60},
          {'day': 'الإثنين', 'rides': 30},
          {'day': 'الثلاثاء', 'rides': 55},
          {'day': 'الأربعاء', 'rides': 70},
          {'day': 'الخميس', 'rides': 80},
          {'day': 'الجمعة', 'rides': 65},
        ],
        xValueMapper: (data, _) => data['day'],
        yValueMapper: (data, _) => data['rides'],
        color: _primaryColor,
        dataLabelSettings: DataLabelSettings(
          isVisible: true,
          labelAlignment: ChartDataLabelAlignment.top,
          textStyle: TextStyle(fontFamily: 'Tajawal', fontSize: 10),
        ),
      ),
    ],
  ),
)

              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.only(bottom: 16),
            itemCount: _rides.length,
            itemBuilder: (context, index) {
              return _buildRideCard(_rides[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRideCard(Ride ride) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Material(
        borderRadius: BorderRadius.circular(15),
        elevation: 2,
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: () {
            // تفاصيل الرحلة
          },
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        image: DecorationImage(
                          image: AssetImage(ride.driverImage),
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
                            ride.driverName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Tajawal',
                              color: _darkColor,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            DateFormat('yyyy/MM/dd - hh:mm a').format(ride.date),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontFamily: 'Tajawal',
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${ride.fare.toStringAsFixed(0)} ر.س',
                        style: TextStyle(
                          color: _primaryColor,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Tajawal',
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _primaryColor.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.location_on, color: _primaryColor, size: 20),
                          ),
                          SizedBox(height: 8),
                          Text(
                            ride.pickup,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 12,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _secondaryColor.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.location_on, color: _secondaryColor, size: 20),
                          ),
                          SizedBox(height: 8),
                          Text(
                            ride.destination,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 12,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _successColor.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.timer, color: _successColor, size: 20),
                          ),
                          SizedBox(height: 8),
                          Text(
                            ride.duration,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.star, color: _warningColor, size: 16),
                        SizedBox(width: 4),
                        Text(
                          '4.5',
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            color: _darkColor,
                          ),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: () {},
                      child: Text(
                        'عرض التفاصيل',
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
        ),
      ),
    );
  }

  Widget _buildRatingsTab() {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _ratings.length,
      itemBuilder: (context, index) {
        return _buildRatingCard(_ratings[index]);
      },
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
                leading: Icon(Icons.remove_red_eye, color: _primaryColor),
                title: Text('عرض التفاصيل', style: TextStyle(fontFamily: 'Tajawal')),
                onTap: () {
                  Navigator.pop(context);
                  // عرض التفاصيل
                },
              ),
              ListTile(
                leading: Icon(Icons.history, color: _primaryColor),
                title: Text('سجل الرحلات', style: TextStyle(fontFamily: 'Tajawal')),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _selectedTab = 1;
                  });
                },
              ),
              ListTile(
                leading: Icon(Icons.star, color: _primaryColor),
                title: Text('التقييمات', style: TextStyle(fontFamily: 'Tajawal')),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _selectedTab = 2;
                  });
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
  final String tripNumber;

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