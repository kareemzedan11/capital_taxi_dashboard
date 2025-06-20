import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
double calculateAverageRating(Map<String, dynamic>? ratingMap) {
  if (ratingMap == null || ratingMap['count'] == 0) return 0.0;

  final count = ratingMap['count'] ?? 0;
  final total = ratingMap['total'] ?? 0;

  return (total / count).toDouble();
}

 

class AnalyticsDashboard extends StatefulWidget {
  @override
  _AnalyticsDashboardState createState() => _AnalyticsDashboardState();
}

class _AnalyticsDashboardState extends State<AnalyticsDashboard> {
String topDriver = 'غير معروف';

 final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  double totalRevenue = 0;
  int totalTrips = 0;
  Map<String, double> dailyRevenue = {};
  Map<String, double> driverEarnings = {};

  @override
  void initState() {
    super.initState();
    _fetchTripsData();
  }
Future<void> _fetchTripsData() async {
  try {
    QuerySnapshot tripsSnapshot = await _firestore.collection('trips').get();
    
    double revenue = 0;
    Map<String, double> daily = {};
    Map<String, double> driverEarns = {};

    for (var doc in tripsSnapshot.docs) {
      // التأكد من صحة السعر
      final rawFare = doc['fare'];
      double fare = 0;
      if (rawFare is int) {
        fare = rawFare.toDouble();
      } else if (rawFare is double) {
        fare = rawFare;
      } else if (rawFare is String) {
        fare = double.tryParse(rawFare) ?? 0;
      }

      revenue += fare;

      // قراءة createdAt سواء كان String أو Timestamp
      DateTime? date;
      final createdAt = doc['createdAt'];
      if (createdAt is String) {
        date = DateTime.tryParse(createdAt);
      } else if (createdAt is Timestamp) {
        date = createdAt.toDate();
      }

      if (date != null) {
        String dateKey = DateFormat('yyyy-MM-dd').format(date);
        daily[dateKey] = (daily[dateKey] ?? 0) + fare;
      }

      // Driver earnings
      String driverId = 'unknown';
      if (doc['driver'] != null) {
        driverId = doc['driver'].toString();
      } else if (doc['driver'] != null && doc['driver']['id'] != null) {
        driverId = doc['driver']['id'].toString();
      }

      driverEarns[driverId] = (driverEarns[driverId] ?? 0) + fare;

 

    }
 

      String topDriverName = 'غير معروف';

if (driverEarns.isNotEmpty) {
  final topDriverId = driverEarns.entries.reduce((a, b) => a.value > b.value ? a : b).key;

  try {
   final driverQuery = await _firestore
    .collection('drivers')
    .where('id', isEqualTo: topDriverId)
    .limit(1)
    .get();

if (driverQuery.docs.isNotEmpty) {
  final driverData = driverQuery.docs.first.data();
  topDriverName = driverData['name'] ?? 'غير معروف';
}

  } catch (e) {
    print('Error fetching top driver: $e');
  }
}
setState(() {
  totalRevenue = revenue;
  totalTrips = tripsSnapshot.docs.length;
  dailyRevenue = daily;
  driverEarnings = driverEarns;
  topDriver = topDriverName;
});

  } catch (e) {
    print('Error fetching trips: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('حدث خطأ أثناء تحميل بيانات الرحلة: $e')),
    );
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text('لوحة الاداره الماليه  '),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.blue[800],
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _fetchTripsData,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary Cards
            Row(
              children: [
                _buildSummaryCard(
                  title: 'إجمالي الإيرادات',
                  value: '${NumberFormat.currency(locale: 'ar', symbol: 'ج.م').format(totalRevenue)}',
                  icon: Icons.attach_money,
                  color: Colors.green,
                ),
                SizedBox(width: 16),
                _buildSummaryCard(
                  title: 'إجمالي الرحلات',
                  value: '$totalTrips',
                  icon: Icons.directions_car,
                  color: Colors.blue,
                ),
              ],
            ),
            SizedBox(height: 16),
            Row(
              children: [
                _buildSummaryCard(
                  title: 'متوسط الرحلة',
                  value: totalTrips > 0 
                    ? '${NumberFormat.currency(locale: 'ar', symbol:  'ج.م').format(totalRevenue / totalTrips)}' 
                    : '0 ج.م',
                  icon: Icons.trending_up,
                  color: Colors.orange,
                ),
                SizedBox(width: 16),
                _buildSummaryCard(
                  title: 'أعلى سائق',
                value: topDriver,
                  icon: Icons.person,
                  color: Colors.purple,
                ),
              ],
            ),
            SizedBox(height: 24),
            
            // Revenue Chart
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'الإيرادات اليومية',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16),
              Container(
  height: 300,
  child: SfCartesianChart(
    tooltipBehavior: TooltipBehavior(enable: true),
    primaryXAxis: CategoryAxis(
      labelStyle: TextStyle(fontFamily: 'Tajawal'),
    ),
    primaryYAxis: NumericAxis(
      numberFormat: NumberFormat.currency(symbol: 'ج.م'),
    ),
    series: <CartesianSeries<MapEntry<String, double>, String>>[ // ✅ نوع السلسلة
      ColumnSeries<MapEntry<String, double>, String>(
        dataSource: dailyRevenue.entries.toList(),
        xValueMapper: (entry, _) => entry.key,
        yValueMapper: (entry, _) => entry.value,
        color: Colors.blue[800],
        pointColorMapper: (entry, _) =>
            entry.value < 100 ? Colors.red : Colors.blue[800],
        dataLabelSettings: DataLabelSettings(
          isVisible: true,
          labelAlignment: ChartDataLabelAlignment.outer,
          textStyle: TextStyle(fontSize: 10, fontFamily: 'Tajawal'),
        ),
      ),
    ],
  ),
),

                  ],
                ),
              ),
            ),
            SizedBox(height: 24),
            
            // Recent Trips
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'أحدث الرحلات',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16),
                    Container(
                      height: 300,
                      child: StreamBuilder<QuerySnapshot>(
                      stream: _firestore.collection('trips')
  .orderBy('createdAt', descending: true)
  .limit(10)
  .snapshots(),

                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return Center(child: CircularProgressIndicator());
                          }
                          
                          var trips = snapshot.data!.docs;
                          
                          return ListView.builder(
                            itemCount: trips.length,
                            itemBuilder: (context, index) {
                              var trip = trips[index];
                              return ListTile(
                                leading: Icon(Icons.directions_car, color: Colors.blue),
                                title: Text('رحلة #${trip.id.substring(0, 6)}'),
                               subtitle: trip['createdAt'] is Timestamp
  ? Text(DateFormat('yyyy-MM-dd - HH:mm').format(trip['createdAt'].toDate()))
  : trip['createdAt'] is String
    ? Text(trip['createdAt'])
    : Text('تاريخ غير متوفر'),

                                trailing: Text(
                                  '${NumberFormat.currency(locale: 'ar', symbol: 'ر.س').format(trip['fare'])}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green[700],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(icon, size: 40, color: color),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//   String _selectedTimeFrame = 'أسبوعي';
//   String _selectedView = 'الإيرادات';
//   String _selectedRegion = 'الكل';

//   // بيانات حقيقية من Firestore
//   double totalRevenue = 0;
//   double growthRate = 0;
//   int totalOrders = 0;
//   List<RevenueData> weeklyRevenue = [];
//   List<DriverPerformance> drivers = [];
//   List<RegionPerformance> regions = [];
//   bool _isLoading = true; // إضافة حالة تحميل

//   @override
//   void initState() {
//     super.initState();
//     _fetchDashboardData();
//   }

//   Future<void> _fetchDashboardData() async {
//     try {
//       setState(() => _isLoading = true);
      
//       // جلب جميع الرحلات
//       final tripsSnapshot = await _firestore.collection('trips').get();
//       final now = DateTime.now();
//       final currentMonthStart = DateTime(now.year, now.month, 1);
//       final previousMonthStart = DateTime(now.year, now.month - 1, 1);
//       final previousMonthEnd = currentMonthStart;

//       // 1. حساب إيرادات الشهر الحالي
//       final currentMonthTrips = await _firestore
//           .collection('trips')
//           .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(currentMonthStart))
//           .get();

//       double currentMonthRevenue = 0;
//       for (var doc in currentMonthTrips.docs) {
//         final fare = doc['fare'];
//         if (fare != null) {
//           currentMonthRevenue += fare is int ? fare.toDouble() : fare;
//         }
//       }

//       // 2. حساب إيرادات الشهر السابق
//       final previousMonthTrips = await _firestore
//           .collection('trips')
//           .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(previousMonthStart))
//           .where('timestamp', isLessThan: Timestamp.fromDate(previousMonthEnd))
//           .get();

//       double previousMonthRevenue = 0;
//       for (var doc in previousMonthTrips.docs) {
//         final fare = doc['fare'];
//         if (fare != null) {
//           previousMonthRevenue += fare is int ? fare.toDouble() : fare;
//         }
//       }

//       // 3. حساب معدل النمو
//       if (previousMonthRevenue == 0) {
//         growthRate = currentMonthRevenue > 0 ? 100.0 : 0.0;
//       } else {
//         growthRate = ((currentMonthRevenue - previousMonthRevenue) / previousMonthRevenue) * 100;
//       }

//       // 4. حساب إجمالي الإيرادات والطلبات
//       totalRevenue = 0;
//       totalOrders = tripsSnapshot.size;
//       for (var doc in tripsSnapshot.docs) {
//         final fare = doc['fare'];
//         if (fare != null) {
//           totalRevenue += fare is int ? fare.toDouble() : fare;
//         }
//       }

//       // 5. حساب الإيرادات الأسبوعية
//       final weekStart = now.subtract(Duration(days: now.weekday));
//       List<RevenueData> weeklyData = [];

//       for (int i = 0; i < 7; i++) {
//         final day = weekStart.add(Duration(days: i));
//         final dayName = _getDayName(day.weekday);
//         final dayStart = DateTime(day.year, day.month, day.day);
//         final dayEnd = dayStart.add(Duration(days: 1));

//         final dayTrips = await _firestore.collection('trips')
//             .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
//             .where('timestamp', isLessThan: Timestamp.fromDate(dayEnd))
//             .get();

//         double dayRevenue = 0;
//         for (var doc in dayTrips.docs) {
//           final fare = doc['fare'];
//           if (fare != null) {
//             dayRevenue += fare is int ? fare.toDouble() : fare;
//           }
//         }
//         weeklyData.add(RevenueData(dayName, dayRevenue));
//       }

//       // 6. حساب أداء السائقين
   
//     // 6. حساب أداء السائقين - الجزء المعدل
//     Map<String, int> driverTripCounts = {};
//     Map<String, double> driverTotalRatings = {};
// for (var doc in tripsSnapshot.docs) {
//   final driverData = doc['driver'];
//   if (driverData != null) {
//     String? driverId;

//     if (driverData['id'] is String || driverData['id'] is int) {
//       driverId = driverData['id'].toString();
//     }

//     if (driverId == null) continue;

//     driverTripCounts[driverId] = (driverTripCounts[driverId] ?? 0) + 1;
//   }
// }


//     List<DriverPerformance> driversList = [];
//     final allDrivers = await _firestore.collection('drivers').get();

//     for (var driverDoc in allDrivers.docs) {
//       // استخدام ID المستند كمعرف إذا لم يوجد حقل id
//       final driverId = driverDoc.id;
//       final tripCount = driverTripCounts[driverId] ?? 0;
//       if (tripCount == 0) continue;

//       final driverData = driverDoc.data(); 
//       final rating = calculateAverageRating(driverData['rating']);
      
//       driversList.add(DriverPerformance(
//         driverData['name']?.toString() ?? 'غير معروف',
//         tripCount,
//         rating,
//       ));
//     }

//     driversList.sort((a, b) => b.deliveries.compareTo(a.deliveries));

//       // 7. حساب أداء المناطق (مثال - تحتاج لتعديله حسب هيكل بياناتك)
//       List<RegionPerformance> regionsList = [];
//       final regionTrips = await _firestore.collection('trips').get();
      
//       Map<String, double> regionRevenues = {};
//       Map<String, int> regionDrivers = {};

//       for (var doc in regionTrips.docs) {
//         final region = doc['region'] ?? 'غير معروف';
//         final fare = doc['fare']?.toDouble() ?? 0;
//         regionRevenues[region] = (regionRevenues[region] ?? 0) + fare;
        
//         if (doc['driver'] != null) {
//           regionDrivers[region] = (regionDrivers[region] ?? 0) + 1;
//         }
//       }

//       regionRevenues.forEach((region, revenue) {
//         regionsList.add(RegionPerformance(
//           region,
//           revenue,
//           regionDrivers[region] ?? 0,
//         ));
//       });

//       regionsList.sort((a, b) => b.revenue.compareTo(a.revenue));

//        setState(() {
//       weeklyRevenue = weeklyData;
//       drivers = driversList.take(4).toList();
//       regions = regionsList;
//       _isLoading = false;
//     });

//     } catch (e) {
//       print('Error fetching data: $e');
//       setState(() => _isLoading = false);
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('حدث خطأ في جلب البيانات: $e')),
//       );
//     }
//   }

// String _getDayName(int weekday) {
//   switch (weekday) {
//     case 1: return 'الاثنين';
//     case 2: return 'الثلاثاء';
//     case 3: return 'الأربعاء';
//     case 4: return 'الخميس';
//     case 5: return 'الجمعة';
//     case 6: return 'السبت';
//     case 7: return 'الأحد';
//     default: return '';
//   }
// } @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Color(0xFFF8F9FA),
//       body: SingleChildScrollView(
//         child: Column(
//           children: [
//             _buildHeader(),
//             _buildTimeFrameSelector(),
//             _buildMainMetrics(),
//             _buildInteractiveCharts(),
//             _buildPerformanceBySection(),
//           ],
//         ),
//       ),
//     );
//   }
//   Widget _buildHeader() {
//     return Container(
//       padding: EdgeInsets.symmetric(vertical: 20, horizontal: 16),
//       decoration: BoxDecoration(
//         gradient: LinearGradient(
//           colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
//           begin: Alignment.topLeft,
//           end: Alignment.bottomRight,
//         ),
//         borderRadius: BorderRadius.only(
//           bottomLeft: Radius.circular(30),
//           bottomRight: Radius.circular(30),
//         ),
//       ),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 'لوحة التحكم الإحصائية',
//                 style: TextStyle(
//                   color: Colors.white,
//                   fontSize: 24,
//                   fontWeight: FontWeight.bold,
//                   fontFamily: 'Tajawal',
//                 ),
//               ),
//               SizedBox(height: 5),
//               Text(
//                 'نظرة شاملة على أداء الأعمال',
//                 style: TextStyle(
//                   color: Colors.white.withOpacity(0.9),
//                   fontSize: 14,
//                   fontFamily: 'Tajawal',
//                 ),
//               ),
//             ],
//           ),
//           Icon(Icons.analytics_outlined, color: Colors.white, size: 40),
//         ],
//       ),
//     );
//   }

//   Widget _buildTimeFrameSelector() {
//     List<String> timeFrames = ['يومي', 'أسبوعي', 'شهري', 'سنوي'];
    
//     return Padding(
//       padding: EdgeInsets.symmetric(vertical: 20),
//       child: Wrap(
//         spacing: 10,
//         runSpacing: 10,
//         alignment: WrapAlignment.center,
//         children: timeFrames.map((frame) {
//           return ChoiceChip(
//             label: Text(frame, style: TextStyle(fontFamily: 'Tajawal')),
//             selected: _selectedTimeFrame == frame,
//             selectedColor: Color(0xFF2575FC),
//             labelStyle: TextStyle(
//               color: _selectedTimeFrame == frame ? Colors.white : Colors.black,
//             ),
//             onSelected: (selected) {
//               setState(() {
//                 _selectedTimeFrame = frame;
//               });
//             },
//             shape: StadiumBorder(
//               side: BorderSide(
//                 color: _selectedTimeFrame == frame ? Colors.transparent : Colors.grey,
//               ),
//             ),
//           );
//         }).toList(),
//       ),
//     );
//   }

//   Widget _buildMainMetrics() {
 
//     return Container(
//       margin: EdgeInsets.symmetric(horizontal: 16),
//       child: Row(
//         children: [
//           Expanded(
//             child: _buildMetricCard(
//               title: 'إجمالي الإيرادات',
//               value: totalRevenue,
//               isCurrency: true,
//               icon: Icons.attach_money,
//               color: Color(0xFF6A11CB),
//             ),
//           ),
//           SizedBox(width: 10),
//           Expanded(
//             child: _buildMetricCard(
//               title: 'معدل النمو',
//               value: growthRate,
//               isPercentage: true,
//               icon: Icons.trending_up,
//               color: Color(0xFF2ECC71),
//             ),
//           ),
//           SizedBox(width: 10),
//           Expanded(
//             child: _buildMetricCard(
//               title: 'عدد الطلبات',
//               value: totalOrders.toDouble(),
//               icon: Icons.shopping_cart,
//               color: Color(0xFFE74C3C),
//             ),
//           ),
//         ],
//       ),
//     );
//   }


// Widget _buildMetricCard({
//   required String title,
//   required double value,
//   bool isCurrency = false,
//   bool isPercentage = false,
//   required IconData icon,
//   required Color color,
// }) {
//   return Card(
//     elevation: 5,
//     shape: RoundedRectangleBorder(
//       borderRadius: BorderRadius.circular(15),
//     ),
//     child: Padding(
//       padding: EdgeInsets.all(16),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               Text(
//                 title,
//                 style: TextStyle(
//                   fontSize: 14,
//                   color: Colors.grey[600],
//                   fontFamily: 'Tajawal',
//                 ),
//               ),
//               Container(
//                 padding: EdgeInsets.all(6),
//                 decoration: BoxDecoration(
//                   color: color.withOpacity(0.2),
//                   shape: BoxShape.circle,
//                 ),
//                 child: Icon(icon, color: color, size: 18),
//               ),
//             ],
//           ),
//           SizedBox(height: 10),
//           Text(
//             isCurrency 
//               ? '${NumberFormat.currency(symbol: 'ج.م').format(value)}'
//               : isPercentage
//                 ? '${value.toStringAsFixed(1)}%'
//                 : value.toStringAsFixed(0),
//             style: TextStyle(
//               fontSize: 22,
//               fontWeight: FontWeight.bold,
//               fontFamily: 'Tajawal',
//             ),
//           ),
//           SizedBox(height: 5),
//           if (title == 'إجمالي الإيرادات')
//             Text(
//               'من ${totalOrders} رحلة',
//               style: TextStyle(
//                 fontSize: 10,
//                 color: Colors.grey,
//                 fontFamily: 'Tajawal',
//               ),
//             ),
//           if (title == 'معدل النمو')
//             Row(
//               children: [
//                 Icon(
//                   value >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
//                   color: value >= 0 ? Colors.green : Colors.red,
//                   size: 16,
//                 ),
//                 SizedBox(width: 4),
//                 Text(
//                   value >= 0 ? 'زيادة عن الشهر السابق' : 'انخفاض عن الشهر السابق',
//                   style: TextStyle(
//                     fontSize: 10,
//                     color: Colors.grey,
//                     fontFamily: 'Tajawal',
//                   ),
//                 ),
//               ],
//             ),
//         ],
//       ),
//     ),
//   );
// }
  
//   Widget _buildInteractiveCharts() {
//     return Container(
//       margin: EdgeInsets.all(16),
//       child: Card(
//         elevation: 5,
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(15),
//         ),
//         child: Padding(
//           padding: EdgeInsets.all(16),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 'الإيرادات حسب الأيام',
//                 style: TextStyle(
//                   fontSize: 18,
//                   fontWeight: FontWeight.bold,
//                   fontFamily: 'Tajawal',
//                 ),
//               ),
//               SizedBox(height: 20),
//               Container(
//                 height: 300,
//                 child: _isLoading
//                   ? Center(child: CircularProgressIndicator())
//                   : weeklyRevenue.isEmpty
//                     ? Center(child: Text('لا توجد بيانات متاحة'))
//                     : SfCartesianChart(
//                         primaryXAxis: CategoryAxis(
//                           labelStyle: TextStyle(fontFamily: 'Tajawal'),
//                         ),
//                         primaryYAxis: NumericAxis(
//                           numberFormat: NumberFormat.currency(symbol: 'ج.م'),
//                         ),
//                         tooltipBehavior: TooltipBehavior(enable: true),
//                         series: <CartesianSeries>[
//                           LineSeries<RevenueData, String>(
//                             dataSource: weeklyRevenue,
//                             xValueMapper: (RevenueData data, _) => data.day,
//                             yValueMapper: (RevenueData data, _) => data.amount,
//                             name: 'الإيرادات',
//                             markerSettings: MarkerSettings(isVisible: true),
//                             dataLabelSettings: DataLabelSettings(isVisible: true),
//                             color: Color(0xFF6A11CB),
//                           ),
//                         ],
//                       ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildPerformanceBySection() {
//     return Container(
//       margin: EdgeInsets.all(16),
//       child: Column(
//         children: [
//           Card(
//             elevation: 5,
//             shape: RoundedRectangleBorder(
//               borderRadius: BorderRadius.circular(15),
//             ),
//             child: Padding(
//               padding: EdgeInsets.all(16),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     'أداء السائقين',
//                     style: TextStyle(
//                       fontSize: 18,
//                       fontWeight: FontWeight.bold,
//                       fontFamily: 'Tajawal',
//                     ),
//                   ),
//                   SizedBox(height: 10),
//                   Container(
//                     height: 250,
//                     child: _isLoading
//                       ? Center(child: CircularProgressIndicator())
//                       : drivers.isEmpty
//                         ? Center(child: Text('لا توجد بيانات للسائقين'))
//                         : ListView.builder(
//                             itemCount: drivers.length,
//                             itemBuilder: (context, index) {
//                               return _buildDriverPerformanceItem(drivers[index]);
//                             },
//                           ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
          
//           SizedBox(height: 20),
          
//           Card(
//             elevation: 5,
//             shape: RoundedRectangleBorder(
//               borderRadius: BorderRadius.circular(15),
//             ),
//             child: Padding(
//               padding: EdgeInsets.all(16),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     'الإيرادات حسب المنطقة',
//                     style: TextStyle(
//                       fontSize: 18,
//                       fontWeight: FontWeight.bold,
//                       fontFamily: 'Tajawal',
//                     ),
//                   ),
//                   SizedBox(height: 10),
//                   Container(
//                     height: 300,
//                     child: _isLoading
//                       ? Center(child: CircularProgressIndicator())
//                       : regions.isEmpty
//                         ? Center(child: Text('لا توجد بيانات للمناطق'))
//                         : SfCircularChart(
//                             legend: Legend(
//                               isVisible: true,
//                               position: LegendPosition.bottom,
//                               textStyle: TextStyle(fontFamily: 'Tajawal'),
//                             ),
//                             series: <CircularSeries>[
//                               PieSeries<RegionPerformance, String>(
//                                 dataSource: regions,
//                                 xValueMapper: (RegionPerformance data, _) => data.region,
//                                 yValueMapper: (RegionPerformance data, _) => data.revenue,
//                                 dataLabelSettings: DataLabelSettings(
//                                   isVisible: true,
//                                   labelPosition: ChartDataLabelPosition.outside,
//                                   textStyle: TextStyle(fontFamily: 'Tajawal'),
//                                 ),
//                                 enableTooltip: true,
//                               ),
//                             ],
//                           ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// // نماذج البيانات تبقى كما هي
// class RevenueData {
//   final String day;
//   final double amount;

//   RevenueData(this.day, this.amount);
// }

// class DriverPerformance {
//   final String name;
//   final int deliveries;
//   final double rating;

//   DriverPerformance(this.name, this.deliveries, this.rating);
// }

// class RegionPerformance {
//   final String region;
//   final double revenue;
//   final int drivers;

//   RegionPerformance(this.region, this.revenue, this.drivers);
// }

//   Widget _buildDriverPerformanceItem(DriverPerformance driver) {
//     return Container(
//       margin: EdgeInsets.symmetric(vertical: 8),
//       padding: EdgeInsets.all(12),
//       decoration: BoxDecoration(
//         color: Colors.grey[100],
//         borderRadius: BorderRadius.circular(10),
//       ),
//       child: Row(
//         children: [
//           CircleAvatar(
//             child: Text(driver.name.substring(0,1), style: TextStyle(color: Colors.white)),
//             backgroundColor: Color(0xFF6A11CB),
//           ),
//           SizedBox(width: 15),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   driver.name,
//                   style: TextStyle(
//                     fontWeight: FontWeight.bold,
//                     fontFamily: 'Tajawal',
//                   ),
//                 ),
//                 SizedBox(height: 5),
//                 Row(
//                   children: [
//                     Icon(Icons.delivery_dining, size: 16, color: Colors.grey),
//                     SizedBox(width: 5),
//                     Text(
//                       '${driver.deliveries} توصيلة',
//                       style: TextStyle(fontSize: 12, color: Colors.grey),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//           Chip(
//             label: Text(driver.rating.toString()),
//             backgroundColor: Color(0xFF2ECC71).withOpacity(0.2),
//             labelStyle: TextStyle(color: Color(0xFF2ECC71)),
//           ),
//         ],
//       ),
//     );
//   }

 