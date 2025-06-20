import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegionSettingsScreen extends StatefulWidget {
  @override
  _RegionSettingsScreenState createState() => _RegionSettingsScreenState();
}

class _RegionSettingsScreenState extends State<RegionSettingsScreen> {
  bool restrictToNewCapital = false;
  double radiusKm = 20.0;
  final centerLatController = TextEditingController();
  final centerLngController = TextEditingController();

  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  // ألوان مخصصة للتصميم
  final Color primaryColor = Color(0xFF4361EE); // أزرق غامق
  final Color secondaryColor = Color(0xFF3F37C9); // أزرق داكن
  final Color accentColor = Color(0xFF4CC9F0); // أزرق فاتح
  final Color cardColor = Color(0xFFF8F9FA); // لون البطاقات
  final Color textColor = Color(0xFF212529); // لون النص الأساسي

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final doc = await firestore.collection('region').doc('admin').get();
    if (doc.exists) {
      final data = doc.data();
      final bool restrict = data?['restrict_to_new_capital'] ?? false;
      final double radius = (data?['radius_km'] ?? 20).toDouble();

      final GeoPoint? center = data?['center'];
      final double lat = center?.latitude ?? 30.005493;
      final double lng = center?.longitude ?? 31.755438;

      setState(() {
        restrictToNewCapital = restrict;
        radiusKm = radius;
        centerLatController.text = lat.toStringAsFixed(6);
        centerLngController.text = lng.toStringAsFixed(6);
      });
    }
  }

  Future<void> _saveSettings() async {
    final double? lat = double.tryParse(centerLatController.text);
    final double? lng = double.tryParse(centerLngController.text);
    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('إحداثيات غير صالحة'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red[400],
        ),
      );
      return;
    }

    await firestore.collection('region').doc('admin').set({
      'restrict_to_new_capital': restrictToNewCapital,
      'radius_km': radiusKm,
      'center': GeoPoint(lat, lng),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم حفظ الإعدادات بنجاح'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.green[400],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: ColorScheme.light(
          primary: primaryColor,
          secondary: secondaryColor,
        ),
      ),
      child: Scaffold(
        backgroundColor: Color(0xFFF1F4FA), // لون خلفية فاتح
        appBar: AppBar(
          title: Text(
            'إعدادات النطاق الجغرافي',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: Colors.white,
            ),
          ),
          centerTitle: true,
          elevation: 0,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryColor, secondaryColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              bottom: Radius.circular(16),
            ),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // بطاقة إعدادات التقييد الجغرافي
              _buildSettingsCard(
                title: 'إعدادات التقييد الجغرافي',
                icon: Icons.location_pin,
                children: [
                  SwitchListTile(
                    title: Text(
                      'تقييد الاستخدام داخل العاصمة الإدارية',
                      style: TextStyle(
                        fontSize: 16,
                        color: textColor,
                      ),
                    ),
                    contentPadding: EdgeInsets.zero,
                    value: restrictToNewCapital,
                    activeColor: accentColor,
                    onChanged: (val) {
                      setState(() => restrictToNewCapital = val);
                    },
                  ),
                ],
              ),
              
              SizedBox(height: 20),
              
              // بطاقة نصف القطر المسموح
              _buildSettingsCard(
                title: 'نصف القطر المسموح',
                icon: Icons.radar,
                children: [
                  Slider(
                    value: radiusKm,
                    min: 1,
                    max: 100,
                    divisions: 99,
                    label: '${radiusKm.round()} كم',
                    activeColor: primaryColor,
                    inactiveColor: Colors.grey[300],
                    onChanged: (value) {
                      setState(() {
                        radiusKm = value;
                      });
                    },
                  ),
                  SizedBox(height: 8),
                  TextField(
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'نصف القطر بالكيلومترات',
                      labelStyle: TextStyle(color: textColor.withOpacity(0.8)),
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey[400]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey[400]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: primaryColor),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      suffixText: 'كم',
                      suffixStyle: TextStyle(color: Colors.grey[600]),
                    ),
                    onChanged: (val) {
                      final value = double.tryParse(val);
                      if (value != null) setState(() => radiusKm = value);
                    },
                    controller: TextEditingController(text: radiusKm.toStringAsFixed(1)),
                  ),
                ],
              ),
              
              SizedBox(height: 20),
              
              // بطاقة مركز النطاق الجغرافي
              _buildSettingsCard(
                title: 'مركز النطاق الجغرافي',
                icon: Icons.center_focus_strong,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: centerLatController,
                          keyboardType: TextInputType.number,
                          readOnly: true,
                          decoration: InputDecoration(
                            labelText: 'خط العرض',
                            labelStyle: TextStyle(color: textColor.withOpacity(0.8)),
                            border: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.grey[400]!),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            prefixIcon: Icon(Icons.location_on, color: accentColor),
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: centerLngController,
                          keyboardType: TextInputType.number,
                          readOnly: true,
                          decoration: InputDecoration(
                            labelText: 'خط الطول',
                            labelStyle: TextStyle(color: textColor.withOpacity(0.8)),
                            border: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.grey[400]!),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            prefixIcon: Icon(Icons.location_on, color: accentColor),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    'هذه الإحداثيات ثابتة ولا يمكن تعديلها',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
              
              SizedBox(height: 32),
              
              // زر الحفظ
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withOpacity(0.2),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _saveSettings,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    backgroundColor: primaryColor,
                  ),
                  child: Text(
                    'حفظ الإعدادات',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // دالة مساعدة لإنشاء بطاقات الإعدادات
  Widget _buildSettingsCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: primaryColor, size: 24),
                SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}