import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart';

class AnalyticsDashboard extends StatefulWidget {
  @override
  _AnalyticsDashboardState createState() => _AnalyticsDashboardState();
}

class _AnalyticsDashboardState extends State<AnalyticsDashboard> {
  String _selectedTimeFrame = 'أسبوعي';
  String _selectedView = 'الإيرادات';
  String _selectedRegion = 'الكل';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8F9FA),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(),
            _buildTimeFrameSelector(),
            _buildMainMetrics(),
            _buildInteractiveCharts(),
            _buildPerformanceBySection(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'لوحة التحكم الإحصائية',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Tajawal',
                ),
              ),
              SizedBox(height: 5),
              Text(
                'نظرة شاملة على أداء الأعمال',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 14,
                  fontFamily: 'Tajawal',
                ),
              ),
            ],
          ),
          Icon(Icons.analytics_outlined, color: Colors.white, size: 40),
        ],
      ),
    );
  }

  Widget _buildTimeFrameSelector() {
    List<String> timeFrames = ['يومي', 'أسبوعي', 'شهري', 'سنوي'];
    
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        alignment: WrapAlignment.center,
        children: timeFrames.map((frame) {
          return ChoiceChip(
            label: Text(frame, style: TextStyle(fontFamily: 'Tajawal')),
            selected: _selectedTimeFrame == frame,
            selectedColor: Color(0xFF2575FC),
            labelStyle: TextStyle(
              color: _selectedTimeFrame == frame ? Colors.white : Colors.black,
            ),
            onSelected: (selected) {
              setState(() {
                _selectedTimeFrame = frame;
              });
            },
            shape: StadiumBorder(
              side: BorderSide(
                color: _selectedTimeFrame == frame ? Colors.transparent : Colors.grey,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMainMetrics() {
    double totalRevenue = 125430;
    double growthRate = 12.5;
    int totalOrders = 342;
    
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildMetricCard(
              title: 'إجمالي الإيرادات',
              value: totalRevenue,
              isCurrency: true,
              icon: Icons.attach_money,
              color: Color(0xFF6A11CB),
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: _buildMetricCard(
              title: 'معدل النمو',
              value: growthRate,
              isPercentage: true,
              icon: Icons.trending_up,
              color: Color(0xFF2ECC71),
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: _buildMetricCard(
              title: 'عدد الطلبات',
              value: totalOrders.toDouble(),
              icon: Icons.shopping_cart,
              color: Color(0xFFE74C3C),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required double value,
    bool isCurrency = false,
    bool isPercentage = false,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontFamily: 'Tajawal',
                  ),
                ),
                Container(
                  padding: EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
              ],
            ),
            SizedBox(height: 10),
            Text(
              isCurrency 
                ? '${NumberFormat.currency(symbol: 'ج.م').format(value)}'
                : isPercentage
                  ? '${value.toStringAsFixed(1)}%'
                  : value.toStringAsFixed(0),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                fontFamily: 'Tajawal',
              ),
            ),
            SizedBox(height: 5),
            Row(
              children: [
                Icon(
                  value >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                  color: value >= 0 ? Colors.green : Colors.red,
                  size: 16,
                ),
                SizedBox(width: 4),
                Text(
                  value >= 0 ? 'زيادة عن الفترة السابقة' : 'انخفاض عن الفترة السابقة',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey,
                    fontFamily: 'Tajawal',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInteractiveCharts() {
    List<RevenueData> weeklyRevenue = [
      RevenueData('السبت', 12000),
      RevenueData('الأحد', 18000),
      RevenueData('الإثنين', 15000),
      RevenueData('الثلاثاء', 22000),
      RevenueData('الأربعاء', 19000),
      RevenueData('الخميس', 25000),
      RevenueData('الجمعة', 14000),
    ];

    return Container(
      margin: EdgeInsets.all(16),
      child: Card(
        elevation: 5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'الإيرادات حسب الأيام',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Tajawal',
                ),
              ),
              SizedBox(height: 20),
             Container(
  height: 300,
  child: SfCartesianChart(
    primaryXAxis: CategoryAxis(
      labelStyle: TextStyle(fontFamily: 'Tajawal'),
    ),
    primaryYAxis: NumericAxis(
      numberFormat: NumberFormat.currency(symbol: 'ج.م'),
    ),
    tooltipBehavior: TooltipBehavior(enable: true),
    series: <CartesianSeries>[
      LineSeries<RevenueData, String>(
        dataSource: weeklyRevenue,
        xValueMapper: (RevenueData data, _) => data.day,
        yValueMapper: (RevenueData data, _) => data.amount,
        name: 'الإيرادات',
        markerSettings: MarkerSettings(isVisible: true),
        dataLabelSettings: DataLabelSettings(isVisible: true),
        color: Color(0xFF6A11CB),
      ),
    ],
  ),
)

            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPerformanceBySection() {
    List<DriverPerformance> drivers = [
      DriverPerformance('محمد أحمد', 45, 4.8),
      DriverPerformance('علي محمود', 38, 4.9),
      DriverPerformance('خالد عبدالله', 42, 4.7),
      DriverPerformance('سعيد حسن', 35, 4.5),
    ];

    List<RegionPerformance> regions = [
      RegionPerformance('المنطقة الشمالية', 65000, 12),
      RegionPerformance('المنطقة الجنوبية', 48000, 8),
      RegionPerformance('المنطقة الشرقية', 72000, 15),
      RegionPerformance('المنطقة الغربية', 55000, 10),
    ];

    return Container(
      margin: EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            elevation: 5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'أداء السائقين',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Tajawal',
                    ),
                  ),
                  SizedBox(height: 10),
                  Container(
                    height: 250,
                    child: ListView.builder(
                      itemCount: drivers.length,
                      itemBuilder: (context, index) {
                        return _buildDriverPerformanceItem(drivers[index]);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          SizedBox(height: 20),
          
          Card(
            elevation: 5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'الإيرادات حسب المنطقة',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Tajawal',
                    ),
                  ),
                  SizedBox(height: 10),
                  Container(
                    height: 300,
                    child: SfCircularChart(
                      legend: Legend(
                        isVisible: true,
                        position: LegendPosition.bottom,
                        textStyle: TextStyle(fontFamily: 'Tajawal'),
                      ),
                      series: <CircularSeries>[
                        PieSeries<RegionPerformance, String>(
                          dataSource: regions,
                          xValueMapper: (RegionPerformance data, _) => data.region,
                          yValueMapper: (RegionPerformance data, _) => data.revenue,
                          dataLabelSettings: DataLabelSettings(
                            isVisible: true,
                            labelPosition: ChartDataLabelPosition.outside,
                            textStyle: TextStyle(fontFamily: 'Tajawal'),
                          ),
                          enableTooltip: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverPerformanceItem(DriverPerformance driver) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          CircleAvatar(
            child: Text(driver.name.substring(0,1), style: TextStyle(color: Colors.white)),
            backgroundColor: Color(0xFF6A11CB),
          ),
          SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  driver.name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Tajawal',
                  ),
                ),
                SizedBox(height: 5),
                Row(
                  children: [
                    Icon(Icons.delivery_dining, size: 16, color: Colors.grey),
                    SizedBox(width: 5),
                    Text(
                      '${driver.deliveries} توصيلة',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Chip(
            label: Text(driver.rating.toString()),
            backgroundColor: Color(0xFF2ECC71).withOpacity(0.2),
            labelStyle: TextStyle(color: Color(0xFF2ECC71)),
          ),
        ],
      ),
    );
  }
}

class RevenueData {
  final String day;
  final double amount;

  RevenueData(this.day, this.amount);
}

class DriverPerformance {
  final String name;
  final int deliveries;
  final double rating;

  DriverPerformance(this.name, this.deliveries, this.rating);
}

class RegionPerformance {
  final String region;
  final double revenue;
  final int drivers;

  RegionPerformance(this.region, this.revenue, this.drivers);
}