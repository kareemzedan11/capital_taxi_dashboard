import 'package:cached_network_image/cached_network_image.dart';
import 'package:capitaltaxi/history_pages/EarningsHistoryPage.dart';
import 'package:capitaltaxi/history_pages/TripsHistoryPage.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class DriversPage extends StatefulWidget {
  @override
  _DriversPageState createState() => _DriversPageState();
}

class _DriversPageState extends State<DriversPage> {
  double totalDistance = 0;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final supabase = Supabase.instance.client;
  List<DocumentSnapshot> _drivers = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedFilter = 'all';
  final Map<String, String> _statusIcons = {
    'active': '🟢',
    'inactive': '🔴',
    'suspended': '🟡',
    'on_trip': '🚕'
  };
  bool _showAdvancedFilters = false;
  String? _selectedCarType;
  double _minRating = 0;
  double _maxFare = 10.0;
String  driverid ="";
  @override
  void initState() {
    super.initState();
    _fetchDrivers();
       fetchDriverDistance();

  }

Future<void> fetchDriverDistance() async {
  final distance = await calculateDriverDistance(driverid);
  setState(() {
    totalDistance = distance;
  });
}

Future<void> _deleteDriver(String driverId) async {
  try {
    // Show confirmation dialog
    bool confirmDelete = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('حذف السائق', style: TextStyle(color: Colors.red)),
        content: Text('هل أنت متأكد أنك تريد حذف هذا السائق؟ لا يمكن التراجع عن هذا الإجراء.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('إلغاء', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('حذف', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          ),
        ],
      ),
    );

    if (confirmDelete == true) {
      // Delete from Firestore
      await _firestore.collection('drivers').doc(driverId).delete();
      
      // Optionally delete from Supabase storage (documents and profile photo)
      try {
        await supabase.storage.from('driver-documents').remove([driverId]);
      } catch (e) {
        print('Error deleting driver documents: $e');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم حذف السائق بنجاح'), backgroundColor: Colors.green));
    }
  } catch (e) {
    print('Error deleting driver: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('فشل حذف السائق: ${e.toString()}'), backgroundColor: Colors.red));
  }
}


  void _fetchDrivers() {
    _firestore.collection('drivers').snapshots().listen((snapshot) {
      setState(() {
        _drivers = snapshot.docs;
        _isLoading = false;
        
      });
    });
  }

  void _updateDriverStatus(String driverId, String newStatus) {
    _firestore.collection('drivers').doc(driverId).update({
      'status': newStatus,
      'lastUpdated': FieldValue.serverTimestamp()
     
    });
       driverid = driverId ;
  }

  void _updateFareSettings(String driverId, double newFare) {
    _firestore.collection('drivers').doc(driverId).update({
      'fareRate': newFare,
      'fareLastUpdated': FieldValue.serverTimestamp()
    });
  }

  void _showFareManagementDialog(DocumentSnapshot driver) {
    final data = driver.data() as Map<String, dynamic>;
    final currentFare = data['fareRate']?.toDouble() ?? 0.0;
    TextEditingController _fareController = TextEditingController(
      text: currentFare.toStringAsFixed(2)
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('إدارة الأسعار', style: TextStyle(color: Colors.blue[800])),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('سعر الرحلة الحالي: \$${currentFare.toStringAsFixed(2)}/كم',
              style: TextStyle(fontSize: 16)),
            SizedBox(height: 20),
            TextField(
              controller: _fareController,
              decoration: InputDecoration(
                labelText: 'سعر الرحلة الجديد',
                prefixText: '\$',
                suffixText: 'لكل كم',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
            ),
            SizedBox(height: 10),
            Text('أسعار مقترحة:',
              style: TextStyle(color: Colors.grey[600])),
            Wrap(
              spacing: 8,
              children: [0.5, 0.8, 1.0, 1.2, 1.5].map((rate) => 
                ActionChip(
                  label: Text('\$$rate'),
                  onPressed: () {
                    _fareController.text = rate.toStringAsFixed(2);
                  },
                )
              ).toList(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              final newFare = double.tryParse(_fareController.text) ?? currentFare;
              _updateFareSettings(driver.id, newFare);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('تم تحديث سعر الرحلة بنجاح')));
            },
            child: Text('تحديث السعر'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[800]),
          ),
        ],
      ),
    );
  }

  List<DocumentSnapshot> get _filteredDrivers {
    return _drivers.where((driver) {
      final data = driver.data() as Map<String, dynamic>;
      final name = data['name']?.toString().toLowerCase() ?? '';
      final carNumber = data['carNumber']?.toString().toLowerCase() ?? '';
      final status = data['status']?.toString().toLowerCase() ?? '';
      final carType = data['carType']?.toString().toLowerCase() ?? '';
      
      final ratingData = data['rating'];
      double rating;
      if (ratingData is Map) {
        final total = ratingData['total'] ?? 0;
        final count = ratingData['count'] ?? 1;
        rating = count != 0 ? total / count : 0.0;
      } else if (ratingData is num) {
        rating = ratingData.toDouble();
      } else {
        rating = 0.0;
      }

      final fareRate = data['fareRate']?.toDouble() ?? 0.0;
      final query = _searchQuery.toLowerCase();
      
      final matchesSearch = name.contains(query) || carNumber.contains(query);
      final matchesFilter = _selectedFilter == 'all' || status == _selectedFilter;
      final matchesCarType = _selectedCarType == null || carType == _selectedCarType!.toLowerCase();
      final matchesRating = rating >= _minRating;
      final matchesFare = fareRate <= _maxFare;
      
      return matchesSearch && matchesFilter && matchesCarType && matchesRating && matchesFare;
    }).toList();
  }
Future<double> calculateDriverDistance(String driverId) async {
  final firestore = FirebaseFirestore.instance;

  final tripsSnapshot = await firestore
      .collection('trips')
      .where('driver.id', isEqualTo: driverId) // أو 'driverId' لو ده اسم الحقل
      .get();

  double totalMeters = 0;

  for (var doc in tripsSnapshot.docs) {
    final distance = doc['distance'];
    if (distance is int) {
      totalMeters += distance.toDouble();
    } else if (distance is double) {
      totalMeters += distance;
    } else if (distance is String) {
      totalMeters += double.tryParse(distance) ?? 0;
    }
  }

  return totalMeters / 1000; // تحويل من متر إلى كيلومتر
}


  Widget _buildStatusFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip('الكل', 'all'),
          _buildFilterChip('نشط 🟢', 'active'),
          _buildFilterChip('غير نشط 🔴', 'inactive'),
          _buildFilterChip('موقوف 🟡', 'suspended'),
          _buildFilterChip('في رحلة 🚕', 'on_trip'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: FilterChip(
        label: Text(label),
        selected: _selectedFilter == value,
        onSelected: (selected) {
          setState(() => _selectedFilter = selected ? value : 'all');
        },
        selectedColor: Colors.blue[100],
        checkmarkColor: Colors.blue[800],
        labelStyle: TextStyle(color: Colors.black),
      ),
    );
  }

  int getStarRating(dynamic ratingData) {
    if (ratingData is Map) {
      final total = ratingData['total'] ?? 0;
      final count = ratingData['count'] ?? 1;
      if (count == 0) return 0;
      return (total / count).round();
    } else if (ratingData is num) {
      return ratingData.round();
    } else {
      return 0;
    }
  }

  String formatRating(dynamic ratingData) {
    if (ratingData is Map) {
      final total = ratingData['total'] ?? 0;
      final count = ratingData['count'] ?? 1;
      if (count == 0) return '0.0';
      return (total / count).toStringAsFixed(1);
    } else if (ratingData is num) {
      return ratingData.toStringAsFixed(1);
    } else {
      return '0.0';
    }
  }

  void _showDriverDetails(DocumentSnapshot driver) {
    final data = driver.data() as Map<String, dynamic>;
    final createdAt = data['createdAt']?.toDate();
    final lastUpdated = data['lastUpdated']?.toDate();
    final fareUpdated = data['fareLastUpdated']?.toDate();
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');
    final starRating = getStarRating(data['rating']);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (context) => SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Header Section
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      child: FutureBuilder<String?>(
                        future: _getDriverProfilePhoto(driver.id),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return CircularProgressIndicator();
                          }
                          if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
                            return Icon(Icons.person, color: Colors.blue);
                          }
                          final photoUrl = snapshot.data!;
                          return ClipOval(
                            child: CachedNetworkImage(
                              imageUrl: photoUrl,
                              fit: BoxFit.cover,
                              width: 80,
                              height: 80,
                              errorWidget: (context, url, error) => Icon(Icons.person, color: Colors.blue),
                            ),
                          );
                        },
                      ),
                    ),
                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) => 
                        Icon(
                          index < starRating ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 20,
                        )
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
              Center(
                child: Text(data['name'] ?? 'لا يوجد اسم',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black)),
              ),
              SizedBox(height: 8),
              Center(
                child: Chip(
                  label: Text(data['status']?.toString().toUpperCase() ?? 'غير معروف',
                    style: TextStyle(color: Colors.white)),
                  backgroundColor: _getStatusColor(data['status']),
                ),
              ),
              Divider(color: Colors.grey[300], height: 32),
              
        // Documents Section
_buildSectionHeader('الوثائق والمستندات'),
SizedBox(
  height: 400,
  child: FutureBuilder<List<_DriverImage>>(
    future: fetchDriverImages(driver.id),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error, color: Colors.red),
              Text('خطأ في تحميل المستندات'),
            ],
          ),
        );
      }
      final documents = snapshot.data ?? [];
      if (documents.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.folder_off, color: Colors.grey),
              Text('لا توجد مستندات'),
            ],
          ),
        );
      }
      return ListView.builder(
        itemCount: documents.length,
        itemBuilder: (context, index) {
          final img = documents[index];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  // Document Title
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Text(
                      img.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black
                      ),
                    ),
                  ),
                  // Document Content
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: 300, // الحد الأدنى للارتفاع
                      maxHeight: 500, // الحد الأقصى للارتفاع
                    ),
                    child: img.url.contains('.pdf')
                        ? Container(
                            color: Colors.red[100],
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.picture_as_pdf, size: 60, color: Colors.red),
                                  SizedBox(height: 16),
                                  Text('ملف PDF', style: TextStyle(color: Colors.red, fontSize: 20)),
                                  SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: () => _launchUrl(img.url),
                                    child: Text('فتح الملف'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red[800],
                                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : InteractiveViewer(
                            panEnabled: true,
                            minScale: 0.5,
                            maxScale: 3.0,
                            child: CachedNetworkImage(
                              imageUrl: img.url,
                              fit: BoxFit.contain,
                              placeholder: (context, url) => Center(child: CircularProgressIndicator()),
                              errorWidget: (context, url, error) => Icon(Icons.error),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  ),
),
              Divider(color: Colors.grey[300], height: 32),
              
              // Personal Info Section
              _buildSectionHeader('المعلومات الشخصية'),
              _buildDetailRow(Icons.email, 'البريد الإلكتروني', data['email'] ?? '-'),
              _buildDetailRow(Icons.phone, 'الهاتف', data['phone'] ?? '-'),
              _buildDetailRow(Icons.person, 'اسم المستخدم', data['username'] ?? '-'),
              _buildDetailRow(Icons.calendar_today, 'تاريخ الانضمام', 
                createdAt != null ? dateFormat.format(createdAt) : '-'),
              
              // Vehicle Info Section
              _buildSectionHeader('معلومات المركبة'),
              _buildDetailRow(Icons.directions_car, 'رقم المركبة', data['carNumber'] ?? '-'),
              _buildDetailRow(Icons.category, 'نوع المركبة', data['carType'] ?? '-'),
              _buildDetailRow(Icons.model_training, 'موديل المركبة', data['carModel'] ?? '-'),
              _buildDetailRow(Icons.color_lens, 'لون المركبة', data['carColor'] ?? '-'),
              
              // Fare & Earnings Section
              _buildSectionHeader('الأرباح والتعريفات'),
              _buildDetailRow(Icons.monetization_on, 'إجمالي الأرباح', 
                '\$${data['totalEarnings']?.toStringAsFixed(2) ?? '0.00'}'),
              _buildDetailRow(Icons.account_balance_wallet, 'رصيد المحفظة', 
                '\$${data['balance']?.toStringAsFixed(2) ?? '0.00'}'),
              
              // Stats Section
              _buildSectionHeader('الإحصائيات'),
              GridView.count(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                childAspectRatio: 1.5,
                children: [
                  _buildStatCard('الرحلات', Icons.directions_car, data['trips']?.toString() ?? '0'),
                  _buildStatCard('التقييم', Icons.star, formatRating(data['rating'])),
                  _buildStatCard('الساعات', Icons.timer, data['hours']?.toString() ?? '0'),
 
                  _buildStatCard('الإلغاءات', Icons.cancel, data['canceledTrips']?.toString() ?? '0'),
                  _buildStatCard('الشكاوى', Icons.report, data['complaints']?.toString() ?? '0'),
                ],
              ),
              
              SizedBox(height: 16),
              Divider(color: Colors.grey[300]),
              SizedBox(height: 16),
              
              // Actions Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    icon: Icon(Icons.history, size: 18),
                    label: Text('سجل الرحلات', style: TextStyle(color: Colors.white)),
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TripsHistoryPage(driverId: data["id"]),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[800],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20))),
                  ),
                  ElevatedButton.icon(
                    icon: Icon(Icons.money, size: 18),
                    label: Text('الأرباح', style: TextStyle(color: Colors.white)),
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EarningsHistoryPage(driverId: data["id"]),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[800],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20))),
                  ),
                ],
              ),
              SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.only(top: 16, bottom: 8),
      child: Text(title, 
        style: TextStyle(
          color: Colors.blue[800], 
          fontSize: 14,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0
        )),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue[800], size: 20),
          SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text('$label:', 
              style: TextStyle(color: Colors.grey[600])),
          ),
          Expanded(
            flex: 3,
            child: Text(value, 
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, IconData icon, String value) {
    return Card(
      margin: EdgeInsets.all(4),
      color: Colors.grey[100],
      child: Padding(
        padding: EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.blue[800], size: 20),
            SizedBox(height: 4),
            Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 10)),
            SizedBox(height: 4),
            Text(value, style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedFilters() {
    final carTypes = _getUniqueCarTypes();
    
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.filter_alt, color: Colors.blue[800], size: 20),
              SizedBox(width: 8),
              Text('تصفية متقدمة', style: TextStyle(color: Colors.black, fontSize: 16)),
              Spacer(),
              IconButton(
                icon: Icon(_showAdvancedFilters ? Icons.expand_less : Icons.expand_more, color: Colors.blue[800]),
                onPressed: () => setState(() => _showAdvancedFilters = !_showAdvancedFilters),
              ),
            ],
          ),
          if (_showAdvancedFilters) ...[
            SizedBox(height: 16),
            _buildFilterDropdown(
              label: 'نوع المركبة',
              value: _selectedCarType,
              items: ['الكل', ...carTypes],
              onChanged: (value) => setState(() => _selectedCarType = value == 'الكل' ? null : value),
            ),
            SizedBox(height: 16),
            _buildRangeSlider(
              label: 'أقل تقييم: ${_minRating.toStringAsFixed(1)}',
              value: _minRating,
              max: 5.0,
              divisions: 10,
              onChanged: (value) => setState(() => _minRating = value),
            ),
            SizedBox(height: 16),
            _buildRangeSlider(
              label: 'أعلى سعر: \$${_maxFare.toStringAsFixed(2)}/كم',
              value: _maxFare,
              max: 20.0,
              divisions: 40,
              onChanged: (value) => setState(() => _maxFare = value),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[600])),
        SizedBox(height: 8),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: DropdownButton<String>(
            value: value ?? 'الكل',
            items: items.map((type) => 
              DropdownMenuItem(
                value: type,
                child: Text(type, style: TextStyle(color: Colors.black)),
              )
            ).toList(),
            onChanged: onChanged,
            isExpanded: true,
            dropdownColor: Colors.white,
            underline: SizedBox(),
            icon: Icon(Icons.arrow_drop_down, color: Colors.blue[800]),
            style: TextStyle(color: Colors.black),
          ),
        ),
      ],
    );
  }

  Widget _buildRangeSlider({
    required String label,
    required double value,
    required double max,
    required int divisions,
    required Function(double) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[600])),
        Slider(
          value: value,
          min: 0,
          max: max,
          divisions: divisions,
          activeColor: Colors.blue[800],
          inactiveColor: Colors.grey[300],
          label: value.toStringAsFixed(value == max ? 0 : 1),
          onChanged: onChanged,
        ),
      ],
    );
  }

  List<String> _getUniqueCarTypes() {
    final types = <String>{};
    for (var driver in _drivers) {
      final data = driver.data() as Map<String, dynamic>;
      if (data['carType'] != null) {
        types.add(data['carType']);
      }
    }
    return types.toList()..sort();
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'active': return Colors.green;
      case 'inactive': return Colors.red;
      case 'suspended': return Colors.amber;
      case 'on_trip': return Colors.blue;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: Row(
          children: [
            Icon(Icons.drive_eta, color: Colors.blue[800]),
            SizedBox(width: 12),
            Text("إدارة السائقين", 
              style: TextStyle(
                color: Colors.black,
                fontSize: 20,
                fontWeight: FontWeight.bold
              )),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.blue[800]),
            onPressed: _fetchDrivers,
            tooltip: 'تحديث',
          ),
          IconButton(
            icon: Icon(Icons.bar_chart, color: Colors.blue[800]),
            onPressed: () => _showAnalytics(),
            tooltip: 'التحليلات',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'ابحث بالسائقين بالاسم أو رقم المركبة...',
                    hintStyle: TextStyle(color: Colors.grey[500]),
                    prefixIcon: Icon(Icons.search, color: Colors.blue[800]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                    contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  ),
                  style: TextStyle(color: Colors.black),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
                SizedBox(height: 12),
                _buildStatusFilterChips(),
                SizedBox(height: 12),
                _buildAdvancedFilters(),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: Colors.blue[800]))
                : _filteredDrivers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off, size: 60, color: Colors.grey),
                            SizedBox(height: 16),
                            Text('لا يوجد سائقين', 
                              style: TextStyle(color: Colors.black, fontSize: 18)),
                            SizedBox(height: 8),
                            Text('حاول تعديل عوامل التصفية', 
                              style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                                    dataRowHeight: 70, // زيادة ارتفاع الصفوف
                    headingRowHeight: 60, // زيادة ارتفاع رأس الجدول
                          columnSpacing: 20,
                          columns: [
                            DataColumn(
                              label: _buildTableHeader('السائق'),
                            ),
                            DataColumn(
                              label: _buildTableHeader('المركبة'),
                            ),
                            DataColumn(
                              label: _buildTableHeader('الحالة'),
                            ),
                            DataColumn(
                              label: _buildTableHeader('التقييم'),
                            ),
                         
                            DataColumn(
                              label: _buildTableHeader('الأرباح'),
                              numeric: true,
                            ),
                            DataColumn(
                              label: _buildTableHeader('إجراءات'),
                            ),
                          ],
                          rows: _filteredDrivers.map((driver) {
                            final data = driver.data() as Map<String, dynamic>;
                            final status = data['status'] ?? 'unknown';
                            final ratingData = data['rating'];
                            double rating;

                            if (ratingData is Map) {
                              final total = ratingData['total'] ?? 0;
                              final count = ratingData['count'] ?? 1;
                              rating = count != 0 ? total / count : 0.0;
                            } else if (ratingData is num) {
                              rating = ratingData.toDouble();
                            } else {
                              rating = 0.0;
                            }

                            return DataRow(
                              onSelectChanged: (_) => _showDriverDetails(driver),
                              cells: [
                                DataCell(
                                  Container(
                                    width: 150,
                                    child: FutureBuilder<String?>(
                                      future: _getDriverProfilePhoto(driver.id),
                                      builder: (context, snapshot) {
                                        final photoUrl = snapshot.data;
                                        return Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 18,
                                              backgroundImage: photoUrl != null 
                                                  ? NetworkImage(photoUrl) 
                                                  : AssetImage('assets/driver_placeholder.png') as ImageProvider,
                                              onBackgroundImageError: (e, stack) {
                                                print('Error loading profile image: $e');
                                              },
                                            ),
                                            SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(data['name'] ?? 'لا يوجد اسم', 
                                                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.w500)),
                                                  SizedBox(height: 2),
                                                  Text(data['phone'] ?? '-', 
                                                    style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                                                ],
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Container(
                                    width: 150,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text('${data['carType'] ?? '-'}', 
                                          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w500)),
                                        SizedBox(height: 2),
                                        Text('${data['carModel'] ?? ''} • ${data['carNumber'] ?? '-'}', 
                                          style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(status).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: _getStatusColor(status)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(_statusIcons[status] ?? '❓'),
                                        SizedBox(width: 6),
                                        Text(status.toUpperCase(), 
                                          style: TextStyle(
                                            color: _getStatusColor(status),
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold
                                          )),
                                      ],
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Row(
                                    children: [
                                      Icon(Icons.star, color: Colors.amber, size: 16),
                                      SizedBox(width: 4),
                                      Text(rating.toStringAsFixed(1), 
                                        style: TextStyle(color: Colors.black)),
                                    ],
                                  ),
                                ),
                             
                                DataCell(
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('\$${data['totalEarnings']?.toStringAsFixed(2) ?? '0.00'}', 
                                        style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                                      SizedBox(height: 2),
                                      Text('${data['trips'] ?? '0'} رحلات', 
                                        style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                                    ],
                                  ),
                                ),
                            DataCell(
  Row(
    children: [
      _buildActionButton(
        icon: Icons.info,
        color: Colors.blue,
        tooltip: 'التفاصيل',
        onPressed: () => _showDriverDetails(driver),
      ),
      SizedBox(width: 8),
      _buildActionButton(
        icon: data['status'] == 'active' ? Icons.block : Icons.check_circle,
        color: data['status'] == 'active' ? Colors.amber : Colors.green,
        tooltip: data['status'] == 'active' ? 'تعليق' : 'تفعيل',
        onPressed: () => _updateDriverStatus(
          driver.id, 
          data['status'] == 'active' ? 'suspended' : 'active'
        ),
      ),
      SizedBox(width: 8),
      _buildActionButton(
        icon: Icons.delete,
        color: Colors.red,
        tooltip: 'حذف السائق',
        isDelete: true,
        onPressed: () => _deleteDriver(driver.id),
      ),
    ],
  ),
),
                              ],
                            );
                          }).toList(),
                          headingRowColor: MaterialStateProperty.resolveWith<Color>(
                            (states) => Colors.blue[50]!,
                          ),
                          dataRowColor: MaterialStateProperty.resolveWith<Color>(
                            (states) => Colors.white,
                          ),
                          dividerThickness: 0.5,
                          showBottomBorder: true,
                          horizontalMargin: 12,
                        ),
                      ),
          ),
        ],
      ),
   
    );
  }

  Widget _buildTableHeader(String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Text(text, 
        style: TextStyle(
          color: Colors.blue[800],
          fontWeight: FontWeight.bold,
          fontSize: 14
        )),
    );
  }
Widget _buildActionButton({
  required IconData icon,
  required Color color,
  required String tooltip,
  required Function() onPressed,
  bool isDelete = false, // Add this parameter
}) {
  return Container(
    width: 44,
    height: 44,
    decoration: BoxDecoration(
      color: isDelete ? Colors.red[100] : color.withOpacity(0.1),
      shape: BoxShape.circle,
      border: Border.all(
        color: isDelete ? Colors.red[300]! : color.withOpacity(0.3),
      ),
    ),
    child: IconButton(
      icon: Icon(icon, 
        color: isDelete ? Colors.red : color, 
        size: 20),
      onPressed: onPressed,
      tooltip: tooltip,
      padding: EdgeInsets.zero,
      constraints: BoxConstraints.tightFor(width: 44, height: 44),
      splashRadius: 24,
    ),
  );
}

  void _addNewDriver() {
    // Implementation for adding a new driver
  }

  void _showAnalytics() {
    // Calculate analytics data
    final totalDrivers = _drivers.length;
    final activeDrivers = _drivers.where((d) => (d.data() as Map<String, dynamic>)['status'] == 'active').length;
    final onTripDrivers = _drivers.where((d) => (d.data() as Map<String, dynamic>)['status'] == 'on_trip').length;
    final suspendedDrivers = _drivers.where((d) => (d.data() as Map<String, dynamic>)['status'] == 'suspended').length;
    
    // Calculate average rating and fare
    double totalRating = 0;
    double totalFare = 0;
    double totalEarnings = 0;
    
    for (var driver in _drivers) {
      final data = driver.data() as Map<String, dynamic>;
      final ratingData = data['rating'];
      double rating;

      if (ratingData is Map) {
        final total = ratingData['total'] ?? 0;
        final count = ratingData['count'] ?? 1;
        rating = count != 0 ? total / count : 0.0;
      } else if (ratingData is num) {
        rating = ratingData.toDouble();
      } else {
        rating = 0.0;
      }

      totalRating += rating;
      totalFare += data['fareRate']?.toDouble() ?? 0;
      totalEarnings += data['totalEarnings']?.toDouble() ?? 0;
    }
    
    final avgRating = totalDrivers > 0 ? totalRating / totalDrivers : 0;
    final avgFare = totalDrivers > 0 ? totalFare / totalDrivers : 0;
    
    // Get most common car type
    final carTypeCounts = <String, int>{};
    for (var driver in _drivers) {
      final type = (driver.data() as Map<String, dynamic>)['carType']?.toString() ?? 'غير معروف';
      carTypeCounts[type] = (carTypeCounts[type] ?? 0) + 1;
    }
    final mostCommonCarType = carTypeCounts.isNotEmpty 
        ? carTypeCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key 
        : 'N/A';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (context) => SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Text('تحليلات السائقين',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[800]
                  )),
              ),
              SizedBox(height: 16),
              
              // Summary Cards
              GridView.count(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                childAspectRatio: 1.5,
                children: [
                  _buildAnalyticsCard('إجمالي السائقين', Icons.people, totalDrivers.toString()),
                  _buildAnalyticsCard('سائقين نشطين', Icons.check_circle, '$activeDrivers (${(activeDrivers/totalDrivers*100).toStringAsFixed(1)}%)'),
                  _buildAnalyticsCard('في رحلة', Icons.directions_car, onTripDrivers.toString()),
                  _buildAnalyticsCard('موقوفين', Icons.block, suspendedDrivers.toString()),
                ],
              ),
              
              SizedBox(height: 16),
              Divider(color: Colors.grey[300]),
              SizedBox(height: 16),
              
              // Stats Section
              _buildAnalyticsRow('متوسط التقييم', avgRating.toStringAsFixed(1), Icons.star, Colors.amber),
      
              _buildAnalyticsRow('إجمالي الأرباح', '\$${totalEarnings.toStringAsFixed(2)}', Icons.monetization_on, Colors.lightBlue),
              _buildAnalyticsRow('أكثر نوع مركبة', mostCommonCarType, Icons.directions_car, Colors.deepPurple),
              
              SizedBox(height: 16),
              Divider(color: Colors.grey[300]),
              SizedBox(height: 16),
              
              // Status Distribution Chart
              Text('توزيع الحالات', 
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.bold
                )),
              SizedBox(height: 8),
              Container(
                height: 150,
                child: _buildStatusChart(
                  active: activeDrivers,
                  onTrip: onTripDrivers,
                  suspended: suspendedDrivers,
                  inactive: totalDrivers - activeDrivers - onTripDrivers - suspendedDrivers,
                ),
              ),
              
              SizedBox(height: 16),
              Divider(color: Colors.grey[300]),
              SizedBox(height: 16),
              
              // Top Performers
              Text('أعلى السائقين تقييماً', 
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.bold
                )),
              SizedBox(height: 8),
              Column(
                children: () {
                  final sortedDrivers = _drivers.toList()
                    ..sort((a, b) {
                      final dataA = a.data() as Map<String, dynamic>;
                      final dataB = b.data() as Map<String, dynamic>;
                      final ratingA = extractRating(dataA['rating']);
                      final ratingB = extractRating(dataB['rating']);
                      return ratingB.compareTo(ratingA);
                    });

                  return sortedDrivers
                    .take(3)
                    .map(_buildDriverPerformanceTile)
                    .toList();
                }(),
              ),
              SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
            ],
          ),
        ),
      ),
    );
  }

  double extractRating(dynamic rating) {
    if (rating is Map) {
      final total = rating['total'] ?? 0;
      final count = rating['count'] ?? 1;
      if (count == 0) return 0.0;
      return total / count;
    } else if (rating is num) {
      return rating.toDouble();
    } else {
      return 0.0;
    }
  }

  Widget _buildAnalyticsCard(String title, IconData icon, String value) {
    return Card(
      color: Colors.white,
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.blue[800], size: 20),
                SizedBox(width: 8),
                Text(title, 
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14
                  )),
              ],
            ),
            SizedBox(height: 8),
            Text(value,
              style: TextStyle(
                color: Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.bold
              )),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsRow(String label, String value, IconData icon, Color iconColor) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14
              )),
          ),
          Text(value,
            style: TextStyle(
              color: Colors.black,
              fontSize: 16,
              fontWeight: FontWeight.bold
            )),
        ],
      ),
    );
  }

  Widget _buildStatusChart({required int active, required int onTrip, required int suspended, required int inactive}) {
    final total = active + onTrip + suspended + inactive;
    if (total == 0) return Center(child: Text('لا توجد بيانات متاحة', style: TextStyle(color: Colors.grey)));
    
    return Stack(
      alignment: Alignment.center,
      children: [
        PieChart(
          PieChartData(
            sections: [
              PieChartSectionData(
                value: active.toDouble(),
                color: Colors.green,
                title: '${(active/total*100).toStringAsFixed(1)}%',
                radius: 60,
                titleStyle: TextStyle(color: Colors.white, fontSize: 12),
              ),
              PieChartSectionData(
                value: onTrip.toDouble(),
                color: Colors.blue,
                title: '${(onTrip/total*100).toStringAsFixed(1)}%',
                radius: 60,
                titleStyle: TextStyle(color: Colors.white, fontSize: 12),
              ),
              PieChartSectionData(
                value: suspended.toDouble(),
                color: Colors.amber,
                title: '${(suspended/total*100).toStringAsFixed(1)}%',
                radius: 60,
                titleStyle: TextStyle(color: Colors.white, fontSize: 12),
              ),
              PieChartSectionData(
                value: inactive.toDouble(),
                color: Colors.red,
                title: '${(inactive/total*100).toStringAsFixed(1)}%',
                radius: 60,
                titleStyle: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
            sectionsSpace: 2,
            centerSpaceRadius: 40,
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('الإجمالي',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12
              )),
            Text(total.toString(),
              style: TextStyle(
                color: Colors.black,
                fontSize: 20,
                fontWeight: FontWeight.bold
              )),
          ],
        ),
      ],
    );
  }

  Widget _buildDriverPerformanceTile(DocumentSnapshot driver) {
    final data = driver.data() as Map<String, dynamic>;
    final ratingData = data['rating'];
    double rating;

    if (ratingData is Map) {
      final total = ratingData['total'] ?? 0;
      final count = ratingData['count'] ?? 1;
      rating = count != 0 ? total / count : 0.0;
    } else if (ratingData is num) {
      rating = ratingData.toDouble();
    } else {
      rating = 0.0;
    }

    final trips = data['trips'] ?? 0;
    
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: CircleAvatar(
          radius: 20,
          backgroundImage: data['photoUrl'] != null 
              ? NetworkImage(data['photoUrl']) 
              : AssetImage('assets/driver_placeholder.png') as ImageProvider,
        ),
        title: Text(data['name'] ?? 'لا يوجد اسم',
          style: TextStyle(color: Colors.black)),
        subtitle: Text('$trips رحلات',
          style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star, color: Colors.amber, size: 18),
            SizedBox(width: 4),
            Text(rating.toStringAsFixed(1),
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold
              )),
          ],
        ),
      ),
    );
  }

  Future<List<_DriverImage>> fetchDriverImages(String driverId) async {
    try {
      final files = await supabase.storage
          .from('driver-documents')
          .list(path: driverId);

      final images = <_DriverImage>[];
      
      for (var file in files) {
        try {
          final url = supabase.storage
              .from('driver-documents')
              .getPublicUrl('$driverId/${file.name}');
          
          images.add(_DriverImage(
            name: _formatFileName(file.name),
            url: url,
          ));
        } catch (e) {
          print('Error processing file ${file.name}: $e');
        }
      }

      return images;
    } catch (e) {
      print('Error in fetchDriverImages: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل تحميل المستندات')));
      return [];
    }
  }

  Future<String?> _getDriverProfilePhoto(String driverId) async {
    try {
      final path = '$driverId/profile.jpg';
      final url = supabase.storage
          .from('driver-documents')
          .getPublicUrl(path);
      
      final files = await supabase.storage
          .from('driver-documents')
          .list(path: driverId);
      
      final profileExists = files.any((file) => 
          file.name.toLowerCase().contains('profile'));
      
      return profileExists ? url : null;
    } catch (e) {
      print('Error getting profile photo: $e');
      return null;
    }
  }

  String _formatFileName(String filename) {
    return filename
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .split('.')
        .first
        .toUpperCase();
  }

  Future<void> _launchUrl(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      throw 'Could not launch $url';
    }
  }
}

class _DriverImage {
  final String name;
  final String url;

  _DriverImage({required this.name, required this.url});
}