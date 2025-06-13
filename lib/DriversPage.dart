 import 'package:cached_network_image/cached_network_image.dart';
import 'package:capitaltaxi/test.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io'; // أضف هذا الاستيراد
import 'package:flutter/foundation.dart'; // لاستخدام kIsWeb
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
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
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

  @override
  void initState() {
    super.initState();
    _fetchDrivers();
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
        title: Text('Fare Management', style: TextStyle(color: Colors.orange)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Current Fare Rate: \$${currentFare.toStringAsFixed(2)}/km',
              style: TextStyle(fontSize: 16)),
            SizedBox(height: 20),
            TextField(
              controller: _fareController,
              decoration: InputDecoration(
                labelText: 'New Fare Rate',
                prefixText: '\$',
                suffixText: 'per km',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
            ),
            SizedBox(height: 10),
            Text('Suggested Rates:',
              style: TextStyle(color: Colors.grey)),
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
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newFare = double.tryParse(_fareController.text) ?? currentFare;
              _updateFareSettings(driver.id, newFare);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Fare rate updated successfully')));
            },
            child: Text('Update Fare'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
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
      final rating = data['rating']?.toDouble() ?? 0.0;
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

  Widget _buildStatusFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip('All', 'all'),
          _buildFilterChip('Active 🟢', 'active'),
          _buildFilterChip('Inactive 🔴', 'inactive'),
          _buildFilterChip('Suspended 🟡', 'suspended'),
          _buildFilterChip('On Trip 🚕', 'on_trip'),
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
        selectedColor: Colors.orange.withOpacity(0.3),
        checkmarkColor: Colors.orange,
      ),
    );
  }

  void _showDriverDetails(DocumentSnapshot driver) {
  final data = driver.data() as Map<String, dynamic>;
  final createdAt = data['createdAt']?.toDate();
  final lastUpdated = data['lastUpdated']?.toDate();
  final fareUpdated = data['fareLastUpdated']?.toDate();
  final documents = data['documents'] as Map<String, dynamic>?;
  final dateFormat = DateFormat('yyyy-MM-dd HH:mm');
 
  
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Color(0xFF2A2A3A),
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
        return CircularProgressIndicator(); // عرض مؤشر تحميل أثناء الانتظار
      }
      
      if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
        return Icon(Icons.person); // عرض أيقونة افتراضية في حالة الخطأ أو عدم وجود صورة
      }
      
      final photoUrl = snapshot.data!;
      return ClipOval(
        child: Image.network(
          photoUrl,
          fit: BoxFit.cover,
          width: 80,
          height: 80,
          errorBuilder: (context, error, stackTrace) => Icon(Icons.person),
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
                        index < (data['rating']?.toInt() ?? 0) 
                          ? Icons.star 
                          : Icons.star_border,
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
              child: Text(data['name'] ?? 'No Name',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
            SizedBox(height: 8),
            Center(
              child: Chip(
                label: Text(data['status']?.toString().toUpperCase() ?? 'UNKNOWN',
                  style: TextStyle(color: Colors.white)),
                backgroundColor: _getStatusColor(data['status']),
              ),
            ),
            Divider(color: Colors.grey, height: 32),
     _buildSectionHeader('DOCUMENTS VERIFICATION'),
      SizedBox(
  height: 400, // ارتفاع ثابت لسطح التمرير
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
              Text('Error loading documents'),
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
              Text('No documents found'),
            ],
          ),
        );
      }
      
      return ListView.builder(
        scrollDirection: Axis.vertical,
        physics: AlwaysScrollableScrollPhysics(), // يضمن التمرير حتى مع قلة العناصر
        itemCount: documents.length,
        itemBuilder: (context, index) {
          final img = documents[index];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            child: Container(
              height: 200, // ارتفاع كل عنصر مستند
              decoration: BoxDecoration(
                color: Color(0xFF3A3A4A),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 6,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: ClipRRect(
                      borderRadius: BorderRadius.horizontal(left: Radius.circular(16)),
                      child: img.url.contains('.pdf')
                          ? Container(
                              color: Colors.red[900],
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.picture_as_pdf, size: 50, color: Colors.white),
                                    SizedBox(height: 10),
                                    Text('PDF Document', style: TextStyle(color: Colors.white)),
                                  ],
                                ),
                              ),
                            )
                          : CachedNetworkImage(
  imageUrl: img.url,
  fit: BoxFit.cover,
  placeholder: (context, url) => Center(child: CircularProgressIndicator()),
  errorWidget: (context, url, error) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.error, color: Colors.red),
        Text('Failed to load image'),
      ],
    ),
  ),
)
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            img.name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.white
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 8),
                          if (img.url.contains('.pdf'))
                            ElevatedButton(
                              onPressed: () => _launchUrl(img.url),
                              child: Text('Open PDF'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red[800],
                                padding: EdgeInsets.symmetric(horizontal: 12),
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
        },
      );
    },
  ),
),
Divider(color: Colors.grey, height: 32),
            // Personal Info Section
            _buildSectionHeader('PERSONAL INFORMATION'),
            _buildDetailRow(Icons.email, 'Email', data['email'] ?? '-'),
            _buildDetailRow(Icons.phone, 'Phone', data['phone'] ?? '-'),
            _buildDetailRow(Icons.person, 'Username', data['username'] ?? '-'),
            _buildDetailRow(Icons.calendar_today, 'Member Since', 
              createdAt != null ? dateFormat.format(createdAt) : '-'),
            
            // Vehicle Info Section
            _buildSectionHeader('VEHICLE INFORMATION'),
            _buildDetailRow(Icons.directions_car, 'Car Number', data['carNumber'] ?? '-'),
            _buildDetailRow(Icons.category, 'Car Type', data['carType'] ?? '-'),
            _buildDetailRow(Icons.model_training, 'Car Model', data['carModel'] ?? '-'),
            _buildDetailRow(Icons.color_lens, 'Car Color', data['carColor'] ?? '-'),
            
            // Fare & Earnings Section
            _buildSectionHeader('FARE & EARNINGS'),
            _buildDetailRow(Icons.attach_money, 'Fare Rate', 
              '\$${data['fareRate']?.toStringAsFixed(2) ?? '0.00'}/km'),
            _buildDetailRow(Icons.update, 'Last Fare Update', 
              fareUpdated != null ? dateFormat.format(fareUpdated) : '-'),
            _buildDetailRow(Icons.monetization_on, 'Total Earnings', 
              '\$${data['totalEarnings']?.toStringAsFixed(2) ?? '0.00'}'),
            _buildDetailRow(Icons.account_balance_wallet, 'Wallet Balance', 
              '\$${data['walletBalance']?.toStringAsFixed(2) ?? '0.00'}'),
            
            // Stats Section
            _buildSectionHeader('STATISTICS'),
            GridView.count(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              childAspectRatio: 1.5,
              children: [
                _buildStatCard('Trips', Icons.directions_car, data['totalTrips']?.toString() ?? '0'),
                _buildStatCard('Rating', Icons.star, data['rating']?.toStringAsFixed(1) ?? '0.0'),
                _buildStatCard('Hours', Icons.timer, data['totalHours']?.toString() ?? '0'),
                _buildStatCard('KM', Icons.speed, data['totalKm']?.toString() ?? '0'),
                _buildStatCard('Cancels', Icons.cancel, data['canceledTrips']?.toString() ?? '0'),
                _buildStatCard('Complaints', Icons.report, data['complaints']?.toString() ?? '0'),
              ],
            ),
            
            SizedBox(height: 16),
            Divider(color: Colors.grey),
            SizedBox(height: 16),
            
            // Actions Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  icon: Icon(Icons.attach_money, size: 18),
                  label: Text('Adjust Fare'),
                  onPressed: () => _showFareManagementDialog(driver),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[800],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20))),
                ),
                ElevatedButton.icon(
                  icon: Icon(
                    data['status'] == 'active' ? Icons.block : Icons.check_circle,
                    size: 18
                  ),
                  label: Text(data['status'] == 'active' ? 'Suspend' : 'Activate'),
                  onPressed: () => _updateDriverStatus(
                    driver.id, 
                    data['status'] == 'active' ? 'suspended' : 'active'
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: data['status'] == 'active' 
                        ? Colors.amber[800] 
                        : Colors.green[800],
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
          color: Colors.orange, 
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2
        )),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.orange, size: 20),
          SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text('$label:', 
              style: TextStyle(color: Colors.white70)),
          ),
          Expanded(
            flex: 3,
            child: Text(value, 
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, IconData icon, String value) {
    return Card(
      margin: EdgeInsets.all(4),
      color: Colors.grey[850],
      child: Padding(
        padding: EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.orange, size: 20),
            SizedBox(height: 4),
            Text(title, style: TextStyle(color: Colors.white70, fontSize: 10)),
            SizedBox(height: 4),
            Text(value, style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
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
        color: Color(0xFF2A2A3A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.filter_alt, color: Colors.orange, size: 20),
              SizedBox(width: 8),
              Text('Advanced Filters', style: TextStyle(color: Colors.white, fontSize: 16)),
              Spacer(),
              IconButton(
                icon: Icon(_showAdvancedFilters ? Icons.expand_less : Icons.expand_more),
                onPressed: () => setState(() => _showAdvancedFilters = !_showAdvancedFilters),
              ),
            ],
          ),
          if (_showAdvancedFilters) ...[
            SizedBox(height: 16),
            _buildFilterDropdown(
              label: 'Car Type',
              value: _selectedCarType,
              items: ['All', ...carTypes],
              onChanged: (value) => setState(() => _selectedCarType = value == 'All' ? null : value),
            ),
            SizedBox(height: 16),
            _buildRangeSlider(
              label: 'Minimum Rating: ${_minRating.toStringAsFixed(1)}',
              value: _minRating,
              max: 5.0,
              divisions: 10,
              onChanged: (value) => setState(() => _minRating = value),
            ),
            SizedBox(height: 16),
            _buildRangeSlider(
              label: 'Max Fare Rate: \$${_maxFare.toStringAsFixed(2)}/km',
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
        Text(label, style: TextStyle(color: Colors.white70)),
        SizedBox(height: 8),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.grey[800],
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButton<String>(
            value: value ?? 'All',
            items: items.map((type) => 
              DropdownMenuItem(
                value: type,
                child: Text(type, style: TextStyle(color: Colors.white)),
              )
            ).toList(),
            onChanged: onChanged,
            isExpanded: true,
            dropdownColor: Colors.grey[850],
            underline: SizedBox(),
            icon: Icon(Icons.arrow_drop_down, color: Colors.orange),
            style: TextStyle(color: Colors.white),
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
        Text(label, style: TextStyle(color: Colors.white70)),
        Slider(
          value: value,
          min: 0,
          max: max,
          divisions: divisions,
          activeColor: Colors.orange,
          inactiveColor: Colors.grey[700],
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
      case 'active': return Colors.green.withOpacity(0.5);
      case 'inactive': return Colors.red.withOpacity(0.5);
      case 'suspended': return Colors.amber.withOpacity(0.5);
      case 'on_trip': return Colors.blue.withOpacity(0.5);
      default: return Colors.grey.withOpacity(0.5);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF1E1E2E),
      appBar: AppBar(
        backgroundColor: Color(0xFF252537),
        elevation: 4,
        title: Row(
          children: [
            Icon(Icons.drive_eta, color: Colors.orange),
            SizedBox(width: 12),
            Text("Drivers Management", 
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold
              )),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.orange),
            onPressed: _fetchDrivers,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: Icon(Icons.bar_chart, color: Colors.orange),
            onPressed: () => _showAnalytics(),
            tooltip: 'Analytics',
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
                    hintText: 'Search drivers by name or car number...',
                    hintStyle: TextStyle(color: Colors.white70),
                    prefixIcon: Icon(Icons.search, color: Colors.orange),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Color(0xFF2A2A3A),
                    contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  ),
                  style: TextStyle(color: Colors.white),
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
                ? Center(child: CircularProgressIndicator(color: Colors.orange))
                : _filteredDrivers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off, size: 60, color: Colors.grey),
                            SizedBox(height: 16),
                            Text('No drivers found', 
                              style: TextStyle(color: Colors.white, fontSize: 18)),
                            SizedBox(height: 8),
                            Text('Try adjusting your filters', 
                              style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columnSpacing: 20,
                          columns: [
                            DataColumn(
                              label: _buildTableHeader('Driver'),
                            ),
                            DataColumn(
                              label: _buildTableHeader('Vehicle'),
                            ),
                            DataColumn(
                              label: _buildTableHeader('Status'),
                            ),
                            DataColumn(
                              label: _buildTableHeader('Rating'),
                            ),
                            DataColumn(
                              label: _buildTableHeader('Fare Rate'),
                              numeric: true,
                            ),
                            DataColumn(
                              label: _buildTableHeader('Earnings'),
                              numeric: true,
                            ),
                            DataColumn(
                              label: _buildTableHeader('Actions'),
                            ),
                          ],
                          rows: _filteredDrivers.map((driver) {
                            final data = driver.data() as Map<String, dynamic>;
                            final status = data['status'] ?? 'unknown';
                            final rating = data['rating']?.toDouble() ?? 0.0;
                            
                            return DataRow(
                              onSelectChanged: (_) => _showDriverDetails(driver),
                              cells: [
                                DataCell(
                                  Container(
                                    width: 150,
                                    child:FutureBuilder<String?>(
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
                                              Text(data['name'] ?? 'No Name', 
                                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                                              SizedBox(height: 2),
                                              Text(data['phone'] ?? '-', 
                                                style: TextStyle(color: Colors.white70, fontSize: 12)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    );
                          }),
                                     )     ),
                                DataCell(
                                  Container(
                                    width: 150,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text('${data['carType'] ?? '-'}', 
                                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                                        SizedBox(height: 2),
                                        Text('${data['carModel'] ?? ''} • ${data['carNumber'] ?? '-'}', 
                                          style: TextStyle(color: Colors.white70, fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(status),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(_statusIcons[status] ?? '❓'),
                                        SizedBox(width: 6),
                                        Text(status.toUpperCase(), 
                                          style: TextStyle(
                                            color: Colors.white,
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
                                        style: TextStyle(color: Colors.white)),
                                    ],
                                  ),
                                ),
                                DataCell(
                                  Text('\$${data['fareRate']?.toStringAsFixed(2) ?? '0.00'}', 
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold
                                    )),
                                ),
                                DataCell(
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('\$${data['totalEarnings']?.toStringAsFixed(2) ?? '0.00'}', 
                                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                      SizedBox(height: 2),
                                      Text('${data['totalTrips'] ?? '0'} trips', 
                                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                                    ],
                                  ),
                                ),
                                DataCell(
                                  Row(
                                    children: [
                                      _buildActionButton(
                                        icon: Icons.attach_money,
                                        color: Colors.green,
                                        tooltip: 'Manage Fare',
                                        onPressed: () => _showFareManagementDialog(driver),
                                      ),
                                      SizedBox(width: 8),
                                      _buildActionButton(
                                        icon: Icons.info,
                                        color: Colors.blue,
                                        tooltip: 'Details',
                                        onPressed: () => _showDriverDetails(driver),
                                      ),
                                      SizedBox(width: 8),
                                      _buildActionButton(
                                        icon: data['status'] == 'active' ? Icons.block : Icons.check_circle,
                                        color: data['status'] == 'active' ? Colors.amber : Colors.green,
                                        tooltip: data['status'] == 'active' ? 'Suspend' : 'Activate',
                                        onPressed: () => _updateDriverStatus(
                                          driver.id, 
                                          data['status'] == 'active' ? 'suspended' : 'active'
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                          headingRowColor: MaterialStateProperty.resolveWith<Color>(
                            (states) => Color(0xFF252537),
                          ),
                          dataRowColor: MaterialStateProperty.resolveWith<Color>(
                            (states) => Color(0xFF2A2A3A),
                          ),
                          dividerThickness: 0.5,
                          showBottomBorder: true,
                          horizontalMargin: 12,
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addNewDriver(),
        icon: Icon(Icons.person_add),
        label: Text('Add Driver'),
        backgroundColor: Colors.orange,
        elevation: 4,
      ),
    );
  }

  Widget _buildTableHeader(String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Text(text, 
        style: TextStyle(
          color: Colors.orange,
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
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, color: color, size: 18),
        onPressed: onPressed,
        tooltip: tooltip,
        padding: EdgeInsets.all(6),
        constraints: BoxConstraints(),
      ),
    );
  }

  void _addNewDriver() {
    // Implementation for adding a new driver
    // (Similar to previous implementation but with additional fare fields)
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
    totalRating += data['rating']?.toDouble() ?? 0;
    totalFare += data['fareRate']?.toDouble() ?? 0;
    totalEarnings += data['totalEarnings']?.toDouble() ?? 0;
  }
  
  final avgRating = totalDrivers > 0 ? totalRating / totalDrivers : 0;
  final avgFare = totalDrivers > 0 ? totalFare / totalDrivers : 0;
  
  // Get most common car type
  final carTypeCounts = <String, int>{};
  for (var driver in _drivers) {
    final type = (driver.data() as Map<String, dynamic>)['carType']?.toString() ?? 'Unknown';
    carTypeCounts[type] = (carTypeCounts[type] ?? 0) + 1;
  }
  final mostCommonCarType = carTypeCounts.isNotEmpty 
      ? carTypeCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key 
      : 'N/A';

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Color(0xFF2A2A3A),
    builder: (context) => SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text('Driver Analytics',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange
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
                _buildAnalyticsCard('Total Drivers', Icons.people, totalDrivers.toString()),
                _buildAnalyticsCard('Active Drivers', Icons.check_circle, '$activeDrivers (${(activeDrivers/totalDrivers*100).toStringAsFixed(1)}%)'),
                _buildAnalyticsCard('On Trip', Icons.directions_car, onTripDrivers.toString()),
                _buildAnalyticsCard('Suspended', Icons.block, suspendedDrivers.toString()),
              ],
            ),
            
            SizedBox(height: 16),
            Divider(color: Colors.grey),
            SizedBox(height: 16),
            
            // Stats Section
            _buildAnalyticsRow('Average Rating', avgRating.toStringAsFixed(1), Icons.star, Colors.amber),
            _buildAnalyticsRow('Average Fare Rate', '\$${avgFare.toStringAsFixed(2)}/km', Icons.attach_money, Colors.green),
            _buildAnalyticsRow('Total Earnings', '\$${totalEarnings.toStringAsFixed(2)}', Icons.monetization_on, Colors.lightBlue),
            _buildAnalyticsRow('Most Common Car Type', mostCommonCarType, Icons.directions_car, Colors.deepPurple),
            
            SizedBox(height: 16),
            Divider(color: Colors.grey),
            SizedBox(height: 16),
            
            // Status Distribution Chart
            Text('Status Distribution', 
              style: TextStyle(
                color: Colors.white,
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
            Divider(color: Colors.grey),
            SizedBox(height: 16),
            
            // Top Performers
            Text('Top Rated Drivers', 
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold
              )),
            SizedBox(height: 8),
Column(
  children: () {
    // First create a sorted list
    final sortedDrivers = _drivers.toList()
      ..sort((a, b) {
        final dataA = a.data() as Map<String, dynamic>;
        final dataB = b.data() as Map<String, dynamic>;
        final ratingA = (dataA['rating'] as num?)?.toDouble() ?? 0.0;
        final ratingB = (dataB['rating'] as num?)?.toDouble() ?? 0.0;
        return ratingB.compareTo(ratingA);
      });
    
    // Then take top 3 and build widgets
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

Widget _buildAnalyticsCard(String title, IconData icon, String value) {
  return Card(
    color: Colors.grey[850],
    child: Padding(
      padding: EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.orange, size: 20),
              SizedBox(width: 8),
              Text(title, 
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14
                )),
            ],
          ),
          SizedBox(height: 8),
          Text(value,
            style: TextStyle(
              color: Colors.white,
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
            color: iconColor.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Text(label,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14
            )),
        ),
        Text(value,
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold
          )),
      ],
    ),
  );
}

Widget _buildStatusChart({required int active, required int onTrip, required int suspended, required int inactive}) {
  final total = active + onTrip + suspended + inactive;
  if (total == 0) return Center(child: Text('No data available', style: TextStyle(color: Colors.white70)));
  
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
          Text('Total',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12
            )),
          Text(total.toString(),
            style: TextStyle(
              color: Colors.white,
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
  final rating = data['rating']?.toDouble() ?? 0;
  final trips = data['totalTrips'] ?? 0;
  
  return Container(
    margin: EdgeInsets.only(bottom: 8),
    decoration: BoxDecoration(
      color: Colors.grey[850],
      borderRadius: BorderRadius.circular(8),
    ),
    child: ListTile(
      leading: CircleAvatar(
        radius: 20,
        backgroundImage: data['photoUrl'] != null 
            ? NetworkImage(data['photoUrl']) 
            : AssetImage('assets/driver_placeholder.png') as ImageProvider,
      ),
      title: Text(data['name'] ?? 'No Name',
        style: TextStyle(color: Colors.white)),
      subtitle: Text('${trips} trips',
        style: TextStyle(color: Colors.white70, fontSize: 12)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star, color: Colors.amber, size: 18),
          SizedBox(width: 4),
          Text(rating.toStringAsFixed(1),
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold
            )),
        ],
      ),
    ),
  );
}
 
 Future<List<String>> _getDriverDocuments(String driverId) async {
  try {
    final files = await Supabase.instance.client.storage
        .from('driver-documents')
        .list(path: driverId);
    
    final urls = <String>[];
    
    for (var file in files) {
      final url = await Supabase.instance.client.storage
          .from('driver-documents')
          .createSignedUrl('$driverId/${file.name}', 3600);
      urls.add(url);
    }
    
    return urls;
  } catch (e) {
    print('Error getting documents: $e');
    throw Exception('Failed to load documents');
  }
}

void _showFullDocument(String url) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: Colors.transparent,
      contentPadding: EdgeInsets.zero,
      content: InteractiveViewer(
        child: url.contains('.pdf')
          ? Container(
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height * 0.7,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.picture_as_pdf, size: 60, color: Colors.red),
                    Text('PDF Document',
                      style: TextStyle(color: Colors.white, fontSize: 20)),
                    SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () => _launchUrl(url),
                      child: Text('Open PDF'),
                    ),
                  ],
                ),
              ),
            )
          : Image.network(url),
      ),
    ),
  );
}

Future<void> _launchUrl(String url) async {
  if (await canLaunchUrl(Uri.parse(url))) {
    await launchUrl(Uri.parse(url));
  } else {
    throw 'Could not launch $url';
  }
}

Future<void> _verifyDocuments(String driverId) async {
  try {
    await _firestore.collection('drivers').doc(driverId).update({
      'documentsVerified': true,
      'verificationDate': FieldValue.serverTimestamp(),
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Documents verified successfully')));
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error verifying documents: $e')));
  }
}

Future<void> _rejectDocuments(String driverId) async {
  try {
    await _firestore.collection('drivers').doc(driverId).update({
      'documentsVerified': false,
      'verificationDate': FieldValue.serverTimestamp(),
      'rejectionReason': 'Documents not clear',
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Documents rejected')));
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error rejecting documents: $e')));
  }
}
 

Widget _buildVerificationButton({
  required String label,
  required IconData icon,
  required Color color,
  required bool isActive,
  required Function() onPressed,
}) {
  return ElevatedButton.icon(
    icon: Icon(icon, size: 18),
    label: Text(label),
    onPressed: isActive ? onPressed : null,
    style: ElevatedButton.styleFrom(
      backgroundColor: isActive ? color.withOpacity(0.2) : color.withOpacity(0.05),
      foregroundColor: isActive ? color : color.withOpacity(0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    ),
  );
}

Widget _buildStatusActionButton({
  required String label,
  required Color color,
  required Function() onPressed,
  required bool active,
}) {
  return Expanded(
    child: Padding(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: ElevatedButton(
        onPressed: active ? onPressed : null,
        child: Text(label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white
          )),
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withOpacity(active ? 0.8 : 0.3),
          padding: EdgeInsets.symmetric(vertical: 8),
        ),
      ),
    ),
  );
}
Future<List<_DriverImage>> fetchDriverImages(String driverId) async {
  print('Fetching images for driver ID: $driverId'); // Debug
  try {
    final files = await supabase.storage
        .from('driver-documents')
        .list(path: driverId);

    print('Found ${files.length} files for driver $driverId'); // Debug
    
    final images = <_DriverImage>[];
    
    for (var file in files) {
      try {
        final url = supabase.storage
            .from('driver-documents')
            .getPublicUrl('$driverId/${file.name}');
        
        print('Image URL for ${file.name}: $url'); // Debug
        
        images.add(_DriverImage(
          name: _formatFileName(file.name),
          url: url,
        ));
      } catch (e) {
        print('Error processing file ${file.name}: $e'); // Debug
      }
    }

    return images;
  } catch (e) {
    print('Error in fetchDriverImages: $e'); // Debug
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to load documents')));
    return [];
  }
}
Future<String?> _getDriverProfilePhoto(String driverId) async {
  try {
    // المسار في Supabase Storage بناءً على الهيكل المذكور
    final path = '$driverId/profile.jpg'; // أو أي اسم ملف آخر مثل profile.png
    
    // الحصول على رابط عام للصورة
    final url = Supabase.instance.client.storage
        .from('driver-documents') // نفس ال bucket المستخدم للوثائق
        .getPublicUrl(path);
    
    // التحقق من وجود الملف (اختياري)
    final files = await Supabase.instance.client.storage
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

}
 class _DriverImage {
  final String name;
  final String url;

  _DriverImage({required this.name, required this.url});
}
