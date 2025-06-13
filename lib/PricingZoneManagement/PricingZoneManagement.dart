import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:syncfusion_flutter_sliders/sliders.dart';
import 'package:intl/intl.dart'; // لإضافة DateFormat
class PricingZoneManagement extends StatefulWidget {
  @override
  _PricingZoneManagementState createState() => _PricingZoneManagementState();
}

class _PricingZoneManagementState extends State<PricingZoneManagement> {
  int _selectedTab = 0;
  List<Zone> _zones = [];
  List<PricingRule> _pricingRules = [];
  List<SpecialOffer> _specialOffers = [];
  double _basePrice = 15.0;
  double _peakHourMultiplier = 1.5;
  TimeOfDay _peakStartTime = TimeOfDay(hour: 17, minute: 0);
  TimeOfDay _peakEndTime = TimeOfDay(hour: 21, minute: 0);

  @override
  void initState() {
    super.initState();
    // بيانات أولية للعرض التوضيحي
    _zones = [
      Zone(
        name: 'المنطقة المركزية',
        priceMultiplier: 1.2,
        polygon: [
          LatLng(24.7136, 46.6753),
          LatLng(24.7136, 46.6953),
          LatLng(24.7236, 46.6953),
          LatLng(24.7236, 46.6753),
        ],
        color: Colors.blue.withOpacity(0.3),
      ),
      Zone(
        name: 'المنطقة الشمالية',
        priceMultiplier: 1.0,
        polygon: [
          LatLng(24.7336, 46.6753),
          LatLng(24.7336, 46.6953),
          LatLng(24.7536, 46.6953),
          LatLng(24.7536, 46.6753),
        ],
        color: Colors.green.withOpacity(0.3),
      ),
    ];

    _pricingRules = [
      PricingRule(
        name: 'وقت الذروة',
        multiplier: 1.5,
        startTime: TimeOfDay(hour: 17, minute: 0),
        endTime: TimeOfDay(hour: 21, minute: 0),
      ),
      PricingRule(
        name: 'عطلة نهاية الأسبوع',
        multiplier: 1.3,
        appliesToWeekend: true,
      ),
    ];

    _specialOffers = [
      SpecialOffer(
        name: 'خصم أول طلب',
        discountPercentage: 20,
        code: 'FIRST20',
        validUntil: DateTime.now().add(Duration(days: 30)),
      ),
      SpecialOffer(
        name: 'خصم المواسم',
        discountPercentage: 15,
        code: 'SEASON15',
        validUntil: DateTime.now().add(Duration(days: 60)),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('إدارة المناطق والتسعير', style: TextStyle(fontFamily: 'Tajawal')),
        centerTitle: true,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildTabBar(),
          Expanded(
            child: _buildSelectedTab(),
          ),
        ],
      ),
      floatingActionButton: _buildFAB(),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildTabItem(0, 'المناطق الجغرافية', Icons.map),
          _buildTabItem(1, 'قواعد التسعير', Icons.attach_money),
          _buildTabItem(2, 'العروض الخاصة', Icons.local_offer),
        ],
      ),
    );
  }

  Widget _buildTabItem(int index, String title, IconData icon) {
    return Expanded(
      child: InkWell(
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
                color: _selectedTab == index ? Color(0xFF6A11CB) : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: _selectedTab == index ? Color(0xFF6A11CB) : Colors.grey),
              SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  color: _selectedTab == index ? Color(0xFF6A11CB) : Colors.grey,
                  fontFamily: 'Tajawal',
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedTab() {
    switch (_selectedTab) {
      case 0:
        return _buildZonesTab();
      case 1:
        return _buildPricingTab();
      case 2:
        return _buildOffersTab();
      default:
        return Container();
    }
  }

  Widget _buildZonesTab() {
    return Column(
      children: [
        Expanded(
          child: FlutterMap(
            options: MapOptions(
              initialCenter: LatLng(24.7136, 46.6753),
              initialZoom: 13.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: ['a', 'b', 'c'],
              ),
              PolygonLayer(
                polygons: _zones.map((zone) {
                  return Polygon(
                    points: zone.polygon,
                    color: zone.color,
                    borderStrokeWidth: 2,
                    borderColor: Colors.blue,

        
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        _buildZoneList(),
      ],
    );
  }

  Widget _buildZoneList() {
    return Container(
      height: 150,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 5,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: ListView.builder(
        itemCount: _zones.length,
        itemBuilder: (context, index) {
          return _buildZoneListItem(_zones[index]);
        },
      ),
    );
  }

  Widget _buildZoneListItem(Zone zone) {
    return ListTile(
      leading: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: zone.color,
          shape: BoxShape.circle,
        ),
      ),
      title: Text(zone.name, style: TextStyle(fontFamily: 'Tajawal')),
      subtitle: Text(
        'سعر مضاعف: ${zone.priceMultiplier}x',
        style: TextStyle(fontFamily: 'Tajawal'),
      ),
      trailing: IconButton(
        icon: Icon(Icons.edit, color: Colors.blue),
        onPressed: () => _editZone(zone),
      ),
    );
  }

  Widget _buildPricingTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'السعر الأساسي',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Tajawal',
                    ),
                  ),
                  SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        'ر.س',
                        style: TextStyle(
                          fontSize: 16,
                          fontFamily: 'Tajawal',
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Slider(
                          value: _basePrice,
                          min: 5,
                          max: 50,
                          divisions: 9,
                          label: _basePrice.toStringAsFixed(0),
                          onChanged: (value) {
                            setState(() {
                              _basePrice = value;
                            });
                          },
                        ),
                      ),
                      Text(
                        _basePrice.toStringAsFixed(0),
                        style: TextStyle(
                          fontSize: 16,
                          fontFamily: 'Tajawal',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 20),
          Text(
            'قواعد التسعير حسب الوقت',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'Tajawal',
            ),
          ),
          SizedBox(height: 10),
          ..._pricingRules.map((rule) => _buildPricingRuleCard(rule)).toList(),
          SizedBox(height: 20),
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'وقت الذروة',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Tajawal',
                    ),
                  ),
                  SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        'من:',
                        style: TextStyle(fontFamily: 'Tajawal'),
                      ),
                      SizedBox(width: 10),
                      InkWell(
                        onTap: () async {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: _peakStartTime,
                          );
                          if (time != null) {
                            setState(() {
                              _peakStartTime = time;
                            });
                          }
                        },
                        child: Text(
                          _peakStartTime.format(context),
                          style: TextStyle(fontFamily: 'Tajawal'),
                        ),
                      ),
                      Spacer(),
                      Text(
                        'إلى:',
                        style: TextStyle(fontFamily: 'Tajawal'),
                      ),
                      SizedBox(width: 10),
                      InkWell(
                        onTap: () async {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: _peakEndTime,
                          );
                          if (time != null) {
                            setState(() {
                              _peakEndTime = time;
                            });
                          }
                        },
                        child: Text(
                          _peakEndTime.format(context),
                          style: TextStyle(fontFamily: 'Tajawal'),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        'مضاعف السعر:',
                        style: TextStyle(fontFamily: 'Tajawal'),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: SfSlider(
                          value: _peakHourMultiplier,
                          min: 1.0,
                          max: 3.0,
                          interval: 0.5,
                          showTicks: true,
                          showLabels: true,
                          enableTooltip: true,
                          onChanged: (value) {
                            setState(() {
                              _peakHourMultiplier = value;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPricingRuleCard(PricingRule rule) {
    return Card(
      margin: EdgeInsets.only(bottom: 10),
      elevation: 3,
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
                  rule.name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Tajawal',
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.edit, size: 20),
                  onPressed: () => _editPricingRule(rule),
                ),
              ],
            ),
            SizedBox(height: 5),
            if (rule.startTime != null && rule.endTime != null)
              Text(
                'من ${rule.startTime!.format(context)} إلى ${rule.endTime!.format(context)}',
                style: TextStyle(fontFamily: 'Tajawal'),
              ),
            if (rule.appliesToWeekend ?? false)
              Text(
                'يطبق على عطلة نهاية الأسبوع',
                style: TextStyle(fontFamily: 'Tajawal'),
              ),
            SizedBox(height: 5),
            Text(
              'مضاعف السعر: ${rule.multiplier}x',
              style: TextStyle(
                fontFamily: 'Tajawal',
                color: Colors.blue,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOffersTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          ..._specialOffers.map((offer) => _buildOfferCard(offer)).toList(),
        ],
      ),
    );
  }

  Widget _buildOfferCard(SpecialOffer offer) {
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: 3,
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
                  offer.name,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Tajawal',
                  ),
                ),
                Row(
                  children: [
                    Chip(
                      label: Text(
                        offer.code,
                        style: TextStyle(color: Colors.white),
                      ),
                      backgroundColor: Color(0xFF6A11CB),
                    ),
                    SizedBox(width: 10),
                    IconButton(
                      icon: Icon(Icons.edit, size: 20),
                      onPressed: () => _editSpecialOffer(offer),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.discount, color: Colors.green),
                SizedBox(width: 10),
                Text(
                  'خصم ${offer.discountPercentage}%',
                  style: TextStyle(
                    fontSize: 16,
                    fontFamily: 'Tajawal',
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.calendar_today, color: Colors.blue),
                SizedBox(width: 10),
                Text(
                  'صالح حتى ${DateFormat('yyyy/MM/dd').format(offer.validUntil)}',
                  style: TextStyle(
                    fontSize: 14,
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

  Widget _buildFAB() {
    switch (_selectedTab) {
      case 0:
        return FloatingActionButton(
          child: Icon(Icons.add),
          onPressed: _addNewZone,
          backgroundColor: Color(0xFF6A11CB),
        );
      case 1:
        return FloatingActionButton(
          child: Icon(Icons.add),
          onPressed: _addNewPricingRule,
          backgroundColor: Color(0xFF6A11CB),
        );
      case 2:
        return FloatingActionButton(
          child: Icon(Icons.add),
          onPressed: _addNewSpecialOffer,
          backgroundColor: Color(0xFF6A11CB),
        );
      default:
        return Container();
    }
  }

  void _addNewZone() {
    // Implement add new zone logic
  }

  void _editZone(Zone zone) {
    // Implement edit zone logic
  }

  void _addNewPricingRule() {
    // Implement add new pricing rule logic
  }

  void _editPricingRule(PricingRule rule) {
    // Implement edit pricing rule logic
  }

  void _addNewSpecialOffer() {
    // Implement add new special offer logic
  }

  void _editSpecialOffer(SpecialOffer offer) {
    // Implement edit special offer logic
  }
}

class Zone {
  final String name;
  final double priceMultiplier;
  final List<LatLng> polygon;
  final Color color;

  Zone({
    required this.name,
    required this.priceMultiplier,
    required this.polygon,
    required this.color,
  });
}

class PricingRule {
  final String name;
  final double multiplier;
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;
  final bool? appliesToWeekend;

  PricingRule({
    required this.name,
    required this.multiplier,
    this.startTime,
    this.endTime,
    this.appliesToWeekend,
  });
}

class SpecialOffer {
  final String name;
  final double discountPercentage;
  final String code;
  final DateTime validUntil;

  SpecialOffer({
    required this.name,
    required this.discountPercentage,
    required this.code,
    required this.validUntil,
  });
}