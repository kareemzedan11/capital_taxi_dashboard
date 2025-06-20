import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

void main() {
  runApp(const MaterialApp(
    title: 'نظام إدارة الشكاوى',
    home: ProfessionalComplaintsDashboard(),
  ));
}

class ProfessionalComplaintsDashboard extends StatefulWidget {
  const ProfessionalComplaintsDashboard({super.key});

  @override
  _ProfessionalComplaintsDashboardState createState() =>
      _ProfessionalComplaintsDashboardState();
}

class _ProfessionalComplaintsDashboardState
    extends State<ProfessionalComplaintsDashboard> {
  int _currentIndex = 0;
  int _selectedCategoryIndex = 0;
  List<Complaint> complaints = [];
  bool isLoading = true;
  final List<ComplaintCategory> categories = [
    ComplaintCategory(id: 'all', name: 'الكل', icon: Icons.all_inbox),
  //  ComplaintCategory(id: 'harassment', name: 'تحرش', icon: Icons.warning),
    ComplaintCategory(id: 'abuse', name: 'إساءة لفظية', icon: Icons.block),
    ComplaintCategory(id: 'payment', name: 'مشاكل دفع', icon: Icons.payment),
    ComplaintCategory(id: 'behavior', name: 'سلوكيات', icon: Icons.people),
    ComplaintCategory(id: 'route', name: 'مشاكل مسار', icon: Icons.route),
    ComplaintCategory(id: 'vehicle', name: 'حالة المركبة', icon: Icons.directions_car),
  ];

  @override
  void initState() {
    super.initState();
    _fetchComplaints();
  }

  Future<void> _fetchComplaints() async {
    try {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('problemReports')
          .orderBy('timestamp', descending: true)
          .get();

      setState(() {
        complaints = querySnapshot.docs
            .map((doc) => Complaint.fromFirestore(doc))
            .toList();
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ في جلب البيانات: ${e.toString()}')),
      );
    }
  }

  // ألوان التصميم المحدثة
  final Color primaryColor = const Color(0xFF4A6FA5);
  final Color secondaryColor = const Color(0xFF166088);
  final Color backgroundColor = const Color(0xFFF8F9FA);
  final Color cardColor = Colors.white;
  final Color textColor = const Color(0xFF2B2D42);
  final Color lightTextColor = const Color(0xFF8D99AE);

  List<Complaint> get filteredComplaints {
    if (_selectedCategoryIndex == 0) return complaints;
    final selectedCategory = categories[_selectedCategoryIndex].id;
    return complaints.where((c) => c.category == selectedCategory).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        onRefresh: _fetchComplaints,
        child: Column(
          children: [
            if (_currentIndex == 0) _buildCategoriesBar(),
            Expanded(
              child: isLoading 
                  ? Center(child: CircularProgressIndicator(color: primaryColor))
                  : _buildCurrentTab(),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
 
    );
  }

 AppBar _buildAppBar() {
  return AppBar(
    title: Text('إدارة الشكاوى',
        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
    centerTitle: true,
    backgroundColor: primaryColor,
    elevation: 4,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        bottom: Radius.circular(15),
      ),
    ),
    actions: [
      IconButton(
        icon: const Icon(Icons.search, color: Colors.white),
        onPressed: () {
          showSearch(
            context: context,
            delegate: ComplaintSearch(
              complaints: complaints,
              primaryColor: primaryColor,
              cardColor: cardColor,
              textColor: textColor,
              lightTextColor: lightTextColor,
              onStatusUpdate: _handleStatusUpdate,
            ),
          );
        },
      ),
      IconButton(
        icon: const Icon(Icons.filter_alt, color: Colors.white),
        onPressed: _showAdvancedFilterDialog,
      ),
    ],
  );
}

  Widget _buildCategoriesBar() {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = index == _selectedCategoryIndex;
          return GestureDetector(
            onTap: () => setState(() => _selectedCategoryIndex = index),
            child: AnimatedContainer(
              duration: Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? primaryColor : cardColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
                border: isSelected ? null : Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(category.icon,
                      color: isSelected ? Colors.white : primaryColor,
                      size: 18),
                  const SizedBox(width: 6),
                  Text(
                    category.name,
                    style: TextStyle(
                      color: isSelected ? Colors.white : textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCurrentTab() {
    switch (_currentIndex) {
      case 0:
        return ComplaintsList(
          complaints: filteredComplaints,
          primaryColor: primaryColor,
          cardColor: cardColor,
          textColor: textColor,
          lightTextColor: lightTextColor,
          onStatusUpdate: _handleStatusUpdate,
        );
      case 1:
        return AnalyticsTab(
          complaints: complaints,
          categories: categories,
          primaryColor: primaryColor,
          secondaryColor: secondaryColor,
          cardColor: cardColor,
          textColor: textColor,
          lightTextColor: lightTextColor,
        );
      default:
        return Container();
    }
  }

  Future<void> _handleStatusUpdate(String tripId, ComplaintStatus newStatus, {String? adminNotes}) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('problemReports')
          .where('tripId', isEqualTo: tripId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        throw Exception('لم يتم العثور على شكوى بهذا المعرف');
      }

      final doc = querySnapshot.docs.first;
      
      await doc.reference.update({
        'status': newStatus.toString().split('.').last,
        'resolved': newStatus == ComplaintStatus.resolved,
  'resolvedAt': FieldValue.serverTimestamp(),
        if (adminNotes != null && adminNotes.isNotEmpty) 'adminNotes': adminNotes,
      });

      // تحديث الواجهة بعد التعديل
      await _fetchComplaints();
      Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم تحديث حالة الشكوى بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء تحديث الشكوى: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  BottomNavigationBar _buildBottomNavigationBar() {
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: (index) => setState(() => _currentIndex = index),
      backgroundColor: cardColor,
      selectedItemColor: primaryColor,
      unselectedItemColor: lightTextColor,
      selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
      elevation: 8,
      type: BottomNavigationBarType.fixed,
      items: [
        BottomNavigationBarItem(
          icon: Icon(Icons.list_alt),
          label: 'الشكاوى',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.analytics),
          label: 'الإحصائيات',
        ),
      ],
    );
  }

 

  void _showAdvancedFilterDialog() {
  showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
  ), // <<<< هنا القوس الناقص
  builder: (context) {
    return Container(
      padding: const EdgeInsets.all(20),
      height: MediaQuery.of(context).size.height * 0.7,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('تصفية الشكاوى',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: primaryColor)),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFilterSection(
                    title: 'نوع الشكوى',
                    children: categories
                        .where((c) => c.id != 'all')
                        .map((category) => FilterChip(
                              label: Text(category.name),
                              selected: _selectedCategoryIndex ==
                                  categories.indexOf(category),
                              onSelected: (selected) => setState(() {
                                    _selectedCategoryIndex =
                                        selected ? categories.indexOf(category) : 0;
                                  }),
                              selectedColor: primaryColor.withOpacity(0.2),
                              checkmarkColor: primaryColor,
                            ))
                        .toList(),
                  ),
                  _buildFilterSection(
                    title: 'حالة الشكوى',
                    children: ComplaintStatus.values.map((status) {
                      return FilterChip(
                        label: Text(_getStatusText(status)),
                        selected: true,
                        selectedColor: _getStatusColor(status),
                        onSelected: (selected) {},
                        checkmarkColor: Colors.white,
                      );
                    }).toList(),
                  ),
                  _buildFilterSection(
                    title: 'أولوية الشكوى',
                    children: Priority.values.map((priority) {
                      return FilterChip(
                        label: Text(_getPriorityText(priority)),
                        selected: true,
                        selectedColor: _getPriorityColor(priority),
                        onSelected: (selected) {},
                        checkmarkColor: Colors.white,
                      );
                    }).toList(),
                  ),
                  _buildDateRangeFilter(),
                ],
              ),
            ),
          ),
          _buildFilterActions(),
        ],
      ),
    );
  },
);

  }

  Widget _buildFilterSection({required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: TextStyle(
                fontWeight: FontWeight.bold, 
                color: textColor,
                fontSize: 16)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: children,
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildDateRangeFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('الفترة الزمنية',
            style: TextStyle(
                fontWeight: FontWeight.bold, 
                color: textColor,
                fontSize: 16)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                decoration: InputDecoration(
                  labelText: 'من تاريخ',
                  suffixIcon: Icon(Icons.calendar_today,
                      size: 18, color: lightTextColor),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                decoration: InputDecoration(
                  labelText: 'إلى تاريخ',
                  suffixIcon: Icon(Icons.calendar_today,
                      size: 18, color: lightTextColor),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFilterActions() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 15),
              side: BorderSide(color: primaryColor),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text('إعادة تعيين', style: TextStyle(color: primaryColor)),
            onPressed: () {},
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('تطبيق الفلتر',
                style: TextStyle(color: Colors.white)),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ],
    );
  }

   

  String _getStatusText(ComplaintStatus status) {
    switch (status) {
      case ComplaintStatus.pending:
        return 'قيد الانتظار';
      case ComplaintStatus.inProgress:
        return 'قيد المعالجة';
      case ComplaintStatus.resolved:
        return 'تم الحل';
      case ComplaintStatus.rejected:
        return 'مرفوض';
    }
  }

  Color _getStatusColor(ComplaintStatus status) {
    switch (status) {
      case ComplaintStatus.pending:
        return Colors.orange;
      case ComplaintStatus.inProgress:
        return Colors.blue;
      case ComplaintStatus.resolved:
        return Colors.green;
      case ComplaintStatus.rejected:
        return Colors.red;
    }
  }

  String _getPriorityText(Priority priority) {
    switch (priority) {
      case Priority.low:
        return 'منخفضة';
      case Priority.medium:
        return 'متوسطة';
      case Priority.high:
        return 'عالية';
      case Priority.critical:
        return 'حرجة';
    }
  }

  Color _getPriorityColor(Priority priority) {
    switch (priority) {
      case Priority.low:
        return Colors.green;
      case Priority.medium:
        return Colors.blue;
      case Priority.high:
        return Colors.orange;
      case Priority.critical:
        return Colors.red;
    }
  }
}

class ComplaintsList extends StatelessWidget {
  final List<Complaint> complaints;
  final Color primaryColor;
  final Color cardColor;
  final Color textColor;
  final Color lightTextColor;
  final Function(String, ComplaintStatus, {String? adminNotes}) onStatusUpdate;

  const ComplaintsList({
    super.key,
    required this.complaints,
    required this.primaryColor,
    required this.cardColor,
    required this.textColor,
    required this.lightTextColor,
    required this.onStatusUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Text('${complaints.length} شكوى',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textColor)),
              const Spacer(),
              Text('عرض الكل',
                  style: TextStyle(
                      fontSize: 14,
                      color: primaryColor,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        Expanded(
          child: complaints.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox, size: 60, color: lightTextColor),
                      const SizedBox(height: 16),
                      Text('لا توجد شكاوى',
                          style: TextStyle(
                              fontSize: 18,
                              color: lightTextColor,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: complaints.length,
                  itemBuilder: (context, index) {
                    final complaint = complaints[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ComplaintCard(
                        complaint: complaint,
                        primaryColor: primaryColor,
                        cardColor: cardColor,
                        textColor: textColor,
                        lightTextColor: lightTextColor,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ComplaintDetails(
                                complaint: complaint,
                                primaryColor: primaryColor,
                                cardColor: cardColor,
                                textColor: textColor,
                                lightTextColor: lightTextColor,
                                onStatusUpdate: onStatusUpdate,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class ComplaintCard extends StatelessWidget {
  final Complaint complaint;
  final Color primaryColor;
  final Color cardColor;
  final Color textColor;
  final Color lightTextColor;
  final VoidCallback onTap;

  const ComplaintCard({
    super.key,
    required this.complaint,
    required this.primaryColor,
    required this.cardColor,
    required this.textColor,
    required this.lightTextColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildComplaintTypeBadge(complaint.category),
                  const Spacer(),
                  if (complaint.tripId.isNotEmpty)
                    Text(
                      'الرحلة: ${complaint.tripId}',
                      style: TextStyle(
                        color: lightTextColor,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      complaint.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(complaint.status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _getStatusColor(complaint.status),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      _getStatusText(complaint.status),
                      style: TextStyle(
                        color: _getStatusColor(complaint.status),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                complaint.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: lightTextColor,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.person_outline, size: 16, color: lightTextColor),
                  const SizedBox(width: 4),
                  Text(
                    complaint.customerName,
                    style: TextStyle(color: lightTextColor, fontSize: 13),
                  ),
                  const Spacer(),
                  Text(
                    DateFormat('dd/MM/yyyy').format(complaint.date),
                    style: TextStyle(color: lightTextColor, fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComplaintTypeBadge(String category) {
    final categoryInfo = _getCategoryInfo(category);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: categoryInfo.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        categoryInfo.name,
        style: TextStyle(
          color: categoryInfo.color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  ({String name, Color color}) _getCategoryInfo(String categoryId) {
    switch (categoryId) {
      case 'harassment':
        return (name: 'تحرش', color: Colors.red);
      case 'abuse':
        return (name: 'إساءة', color: Colors.orange);
      case 'payment':
        return (name: 'دفع', color: Colors.blue);
      case 'behavior':
        return (name: 'سلوك', color: Colors.purple);
      case 'route':
        return (name: 'مسار', color: Colors.teal);
      case 'vehicle':
        return (name: 'مركبة', color: Colors.green);
      default:
        return (name: 'أخرى', color: Colors.grey);
    }
  }

  String _getStatusText(ComplaintStatus status) {
    switch (status) {
      case ComplaintStatus.pending:
        return 'قيد الانتظار';
      case ComplaintStatus.inProgress:
        return 'قيد المعالجة';
      case ComplaintStatus.resolved:
        return 'تم الحل';
      case ComplaintStatus.rejected:
        return 'مرفوض';
    }
  }

  Color _getStatusColor(ComplaintStatus status) {
    switch (status) {
      case ComplaintStatus.pending:
        return Colors.orange;
      case ComplaintStatus.inProgress:
        return Colors.blue;
      case ComplaintStatus.resolved:
        return Colors.green;
      case ComplaintStatus.rejected:
        return Colors.red;
    }
  }
}

class ComplaintDetails extends StatelessWidget {
  final Complaint complaint;
  final Color primaryColor;
  final Color cardColor;
  final Color textColor;
  final Color lightTextColor;
  final Function(String, ComplaintStatus, {String? adminNotes}) onStatusUpdate;

  const ComplaintDetails({
    super.key,
    required this.complaint,
    required this.primaryColor,
    required this.cardColor,
    required this.textColor,
    required this.lightTextColor,
    required this.onStatusUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('تفاصيل الشكوى', style: TextStyle(color: textColor)),
        backgroundColor: cardColor,
        elevation: 0,
        iconTheme: IconThemeData(color: primaryColor),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderSection(),
            const SizedBox(height: 20),
            _buildDetailsSection(),
            const SizedBox(height: 20),
            _buildTimelineSection(),
            const SizedBox(height: 20),
            _buildActionButtons(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildComplaintTypeBadge(complaint.category),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(complaint.status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _getStatusColor(complaint.status),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    _getStatusText(complaint.status),
                    style: TextStyle(
                      color: _getStatusColor(complaint.status),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              complaint.title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              complaint.description,
              style: TextStyle(color: lightTextColor, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComplaintTypeBadge(String category) {
    final categoryInfo = _getCategoryInfo(category);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: categoryInfo.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        categoryInfo.name,
        style: TextStyle(
          color: categoryInfo.color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildDetailsSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'تفاصيل الشكوى',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 12),
            _buildDetailItem('رقم العميل', complaint.customerName),
            _buildDetailItem('رقم الرحلة', complaint.tripId),
            _buildDetailItem('التاريخ',
                DateFormat('dd/MM/yyyy - hh:mm a').format(complaint.date)),
            _buildDetailItem('الفئة', _getCategoryText(complaint.category)),
            _buildDetailItem('الأولوية', _getPriorityText(complaint.priority)),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                color: lightTextColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(color: textColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'سير العمل',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 12),
            _buildTimelineItem(
              'تم الإرسال',
              complaint.date,
              isActive: true,
              isFirst: true,
            ),
            _buildTimelineItem(
              'قيد المراجعة',
              complaint.status != ComplaintStatus.pending
                  ? complaint.date.add(const Duration(hours: 2))
                  : null,
              isActive: complaint.status != ComplaintStatus.pending,
            ),
            _buildTimelineItem(
              complaint.status == ComplaintStatus.resolved
                  ? 'تم الحل'
                  : complaint.status == ComplaintStatus.rejected
                      ? 'مرفوض'
                      : 'قيد المعالجة',
              complaint.status != ComplaintStatus.pending
                  ? complaint.resolvedAt 
                  : null,
              isActive: complaint.status != ComplaintStatus.pending,
              isLast: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineItem(String title, DateTime? date,
      {bool isActive = false, bool isFirst = false, bool isLast = false}) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive ? primaryColor : Colors.grey[300],
                  border: Border.all(
                    color: isActive ? primaryColor : Colors.grey,
                    width: 2,
                  ),
                ),
                child: isActive
                    ? Icon(Icons.check, size: 12, color: Colors.white)
                    : null,
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 40,
                  color: isActive ? primaryColor : Colors.grey[300],
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isActive ? textColor : lightTextColor,
                  ),
                ),
                if (date != null)
                  Text(
                    DateFormat('dd/MM/yyyy - hh:mm a').format(date),
                    style: TextStyle(
                      color: isActive
                          ? lightTextColor
                          : lightTextColor.withOpacity(0.6),
                      fontSize: 12,
                    ),
                  ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        if (complaint.status != ComplaintStatus.rejected)
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
                side: BorderSide(color: Colors.red),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text('رفض', style: TextStyle(color: Colors.red)),
              onPressed: () => _showRejectDialog(context),
            ),
          ),
        if (complaint.status != ComplaintStatus.rejected) const SizedBox(width: 10),
        if (complaint.status != ComplaintStatus.resolved)
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('حل الشكوى', style: TextStyle(color: Colors.white)),
              onPressed: () {
  if (complaint.id == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("لا يمكن حل الشكوى لأن البيانات غير مكتملة")),
    );
    return;
  }
  _showResolveDialog(context ); // تمرير complaint للدالة
},

            ),
          ),
        if (complaint.status == ComplaintStatus.resolved)
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('تم الحل', style: TextStyle(color: Colors.white)),
              onPressed: () {},
            ),
          ),
      ],
    );
  }

void _showResolveDialog(BuildContext context) {
  final notesController = TextEditingController();
  
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('حل الشكوى'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('هل أنت متأكد من رغبتك في حل هذه الشكوى؟'),
          SizedBox(height: 16),
          TextField(
            controller: notesController,
            decoration: InputDecoration(
              labelText: 'ملاحظات إدارية (اختياري)',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
        ],
      ),
      actions: [
        TextButton(
          child: Text('إلغاء'),
          onPressed: () => Navigator.pop(context),
        ),
        TextButton(
          child: Text('تأكيد', style: TextStyle(color: primaryColor)),
          onPressed: () {
            Navigator.pop(context);
            onStatusUpdate(
              complaint.tripId,
              ComplaintStatus.resolved,
              adminNotes: notesController.text,
            );
          },
        ),
      ],
    ),
  );
}

  void _showRejectDialog(BuildContext context) {
    final notesController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('رفض الشكوى'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('هل أنت متأكد من رغبتك في رفض هذه الشكوى؟'),
            SizedBox(height: 16),
            TextField(
              controller: notesController,
              decoration: InputDecoration(
                labelText: 'سبب الرفض (اختياري)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            child: Text('إلغاء'),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: Text('تأكيد', style: TextStyle(color: Colors.red)),
            onPressed: () {
              Navigator.pop(context);
              onStatusUpdate(
                complaint.tripId,
                ComplaintStatus.rejected,
                adminNotes: notesController.text,
              );
            },
          ),
        ],
      ),
    );
  }}

  ({String name, Color color}) _getCategoryInfo(String categoryId) {
    switch (categoryId) {
      case 'harassment':
        return (name: 'تحرش', color: Colors.red);
      case 'abuse':
        return (name: 'إساءة', color: Colors.orange);
      case 'payment':
        return (name: 'دفع', color: Colors.blue);
      case 'behavior':
        return (name: 'سلوك', color: Colors.purple);
      case 'route':
        return (name: 'مسار', color: Colors.teal);
      case 'vehicle':
        return (name: 'مركبة', color: Colors.green);
      default:
        return (name: 'أخرى', color: Colors.grey);
    }
  }

  String _getStatusText(ComplaintStatus status) {
    switch (status) {
      case ComplaintStatus.pending:
        return 'قيد الانتظار';
      case ComplaintStatus.inProgress:
        return 'قيد المعالجة';
      case ComplaintStatus.resolved:
        return 'تم الحل';
      case ComplaintStatus.rejected:
        return 'مرفوض';
    }
  }

  Color _getStatusColor(ComplaintStatus status) {
    switch (status) {
      case ComplaintStatus.pending:
        return Colors.orange;
      case ComplaintStatus.inProgress:
        return Colors.blue;
      case ComplaintStatus.resolved:
        return Colors.green;
      case ComplaintStatus.rejected:
        return Colors.red;
    }
  }

  String _getPriorityText(Priority priority) {
    switch (priority) {
      case Priority.low:
        return 'منخفضة';
      case Priority.medium:
        return 'متوسطة';
      case Priority.high:
        return 'عالية';
      case Priority.critical:
        return 'حرجة';
    }
  }

  String _getCategoryText(String categoryId) {
    switch (categoryId) {
      // case 'harassment':
      //   return 'تحرش';
      case 'abuse':
        return 'إساءة لفظية';
      case 'payment':
        return 'مشكلة في الدفع';
      case 'behavior':
        return 'سلوك غير لائق';
      case 'route':
        return 'مشكلة في الطريق';
      case 'vehicle':
        return 'حالة المركبة';
      default:
        return 'أخرى';
    }
  }


class AnalyticsTab extends StatelessWidget {
  final List<Complaint> complaints;
  final List<ComplaintCategory> categories;
  final Color primaryColor;
  final Color secondaryColor;
  final Color cardColor;
  final Color textColor;
  final Color lightTextColor;

  const AnalyticsTab({
    super.key,
    required this.complaints,
    required this.categories,
    required this.primaryColor,
    required this.secondaryColor,
    required this.cardColor,
    required this.textColor,
    required this.lightTextColor,
  });

  @override
  Widget build(BuildContext context) {
    final statusData = _getStatusData();
    final categoryData = _getCategoryData();
    final priorityData = _getPriorityData();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildSummaryCards(),
          const SizedBox(height: 20),
          _buildPieChart(statusData, 'حالة الشكاوى'),
          const SizedBox(height: 20),
          _buildBarChart(categoryData, 'الشكاوى حسب الفئة'),
          const SizedBox(height: 20),
          _buildPriorityChart(priorityData),
          const SizedBox(height: 20),
          _buildRecentComplaints(),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    final totalComplaints = complaints.length;
    final pending = complaints.where((c) => c.status == ComplaintStatus.pending).length;
    final inProgress = complaints.where((c) => c.status == ComplaintStatus.inProgress).length;
    final resolved = complaints.where((c) => c.status == ComplaintStatus.resolved).length;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildSummaryCard(
            'إجمالي الشكاوى',
            totalComplaints.toString(),
            Icons.receipt,
            primaryColor,
          ),
          const SizedBox(width: 10),
          _buildSummaryCard(
            'قيد الانتظار',
            pending.toString(),
            Icons.access_time,
            Colors.orange,
          ),
          const SizedBox(width: 10),
          _buildSummaryCard(
            'قيد المعالجة',
            inProgress.toString(),
            Icons.sync,
            Colors.blue,
          ),
          const SizedBox(width: 10),
          _buildSummaryCard(
            'تم الحل',
            resolved.toString(),
            Icons.check_circle,
            Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      width: 150,
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 20, color: color),
                  ),
                  const Spacer(),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  color: lightTextColor,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Map<String, double> _getStatusData() {
    return {
      'قيد الانتظار': complaints.where((c) => c.status == ComplaintStatus.pending).length.toDouble(),
      'قيد المعالجة': complaints.where((c) => c.status == ComplaintStatus.inProgress).length.toDouble(),
      'تم الحل': complaints.where((c) => c.status == ComplaintStatus.resolved).length.toDouble(),
      'مرفوض': complaints.where((c) => c.status == ComplaintStatus.rejected).length.toDouble(),
    };
  }

  Map<String, double> _getCategoryData() {
    Map<String, double> data = {};
    for (var category in categories) {
      if (category.id != 'all') {
        data[category.name] = complaints.where((c) => c.category == category.id).length.toDouble();
      }
    }
    return data;
  }

  Map<String, double> _getPriorityData() {
    return {
      'منخفضة': complaints.where((c) => c.priority == Priority.low).length.toDouble(),
      'متوسطة': complaints.where((c) => c.priority == Priority.medium).length.toDouble(),
      'عالية': complaints.where((c) => c.priority == Priority.high).length.toDouble(),
      'حرجة': complaints.where((c) => c.priority == Priority.critical).length.toDouble(),
    };
  }

  Widget _buildPieChart(Map<String, double> data, String title) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: _generatePieChartSections(data),
                  centerSpaceRadius: 40,
                  sectionsSpace: 2,
                ),
              ),
            ),
            const SizedBox(height: 10),
            _buildLegend(data),
          ],
        ),
      ),
    );
  }

List<PieChartSectionData> _generatePieChartSections(Map<String, double> data) {
  // خريطة تربط بين حالة الشكوى واللون المناسب
  final Map<String, Color> statusColors = {
    'قيد الانتظار': Colors.orange,
    'قيد المعالجة': Colors.blue,
    'تم الحل': Colors.green,
    'مرفوض': Colors.red,
  };

  return data.entries.map((entry) {
    // الحصول على اللون من الخريطة، أو استخدام لون افتراضي إذا لم يوجد
    final color = statusColors[entry.key] ?? primaryColor;
    
    return PieChartSectionData(
      value: entry.value,
      color: color,
      title: '${entry.value.toInt()}',
      radius: 20,
      titleStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
      // إضافة تأثيرات بصرية إضافية
      borderSide: BorderSide(
        color: color.withOpacity(0.5),
        width: 2,
      ),
      badgeWidget: _buildBadge(entry.key, color),
    );
  }).toList();
}

// دالة مساعدة لعرض أيقونة أو نص في مركز القطاع
Widget _buildBadge(String status, Color color) {
  IconData? icon;
  switch (status) {
    case 'قيد الانتظار':
      icon = Icons.access_time;
      break;
    case 'قيد المعالجة':
      icon = Icons.sync;
      break;
    case 'تم الحل':
      icon = Icons.check_circle;
      break;
    case 'مرفوض':
      icon = Icons.block;
      break;
  }

  return icon != null
      ? Icon(icon, size: 16, color: Colors.white)
      : Text(status.substring(0, 1), 
          style: TextStyle(color: Colors.white));
}

  Widget _buildBarChart(Map<String, double> data, String title) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  barGroups: _generateBarChartGroups(data),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: true),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < data.keys.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                data.keys.toList()[index],
                                style: TextStyle(
                                  fontSize: 10,
                                  color: lightTextColor,
                                ),
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                  ),
                  gridData: FlGridData(show: false),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<BarChartGroupData> _generateBarChartGroups(Map<String, double> data) {
    return data.entries.map((entry) {
      final index = data.keys.toList().indexOf(entry.key);
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: entry.value,
            color: primaryColor,
            width: 16,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      );
    }).toList();
  }

  Widget _buildPriorityChart(Map<String, double> data) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'الشكاوى حسب الأولوية',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  barGroups: _generatePriorityBarGroups(data),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: true),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < data.keys.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                data.keys.toList()[index],
                                style: TextStyle(
                                  fontSize: 10,
                                  color: lightTextColor,
                                ),
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                  ),
                  gridData: FlGridData(show: false),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<BarChartGroupData> _generatePriorityBarGroups(Map<String, double> data) {
    final priorityColors = {
      'منخفضة': Colors.green,
      'متوسطة': Colors.blue,
      'عالية': Colors.orange,
      'حرجة': Colors.red,
    };

    return data.entries.map((entry) {
      final index = data.keys.toList().indexOf(entry.key);
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: entry.value,
            color: priorityColors[entry.key],
            width: 16,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      );
    }).toList();
  }

  Widget _buildLegend(Map<String, double> data) {
    final List<Color> colors = [
      primaryColor,
      secondaryColor,
      Colors.orange,
      Colors.green,
      Colors.red,
      Colors.purple,
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: data.entries.map((entry) {
        final index = data.keys.toList().indexOf(entry.key);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors[index % colors.length],
              ),
            ),
            const SizedBox(width: 4),
            Text(
              entry.key,
              style: TextStyle(
                fontSize: 12,
                color: lightTextColor,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildRecentComplaints() {
    final recentComplaints = complaints.take(5).toList();

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'آخر الشكاوى',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const Spacer(),
                Text(
                  'عرض الكل',
                  style: TextStyle(
                    fontSize: 12,
                    color: primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...recentComplaints.map((complaint) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _getStatusColor(complaint.status),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        complaint.title,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      DateFormat('dd/MM').format(complaint.date),
                      style: TextStyle(
                        color: lightTextColor,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(ComplaintStatus status) {
    switch (status) {
      case ComplaintStatus.pending:
        return Colors.orange;
      case ComplaintStatus.inProgress:
        return Colors.blue;
      case ComplaintStatus.resolved:
        return Colors.green;
      case ComplaintStatus.rejected:
        return Colors.red;
    }
  }
}
class ComplaintSearch extends SearchDelegate<Complaint?> {
  final List<Complaint> complaints;
  final Color primaryColor;
  final Color cardColor;
  final Color textColor;
  final Color lightTextColor;
  final Function(String, ComplaintStatus, {String? adminNotes}) onStatusUpdate;

  ComplaintSearch({
    required this.complaints,
    required this.primaryColor,
    required this.cardColor,
    required this.textColor,
    required this.lightTextColor,
    required this.onStatusUpdate,
  });

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults(context);
  }

  Widget _buildSearchResults(BuildContext context) {
    final results = complaints.where((complaint) {
      return complaint.title.toLowerCase().contains(query.toLowerCase()) ||
          complaint.description.toLowerCase().contains(query.toLowerCase()) ||
          complaint.customerName.toLowerCase().contains(query.toLowerCase()) ||
          complaint.tripId.toLowerCase().contains(query.toLowerCase());
    }).toList();

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final complaint = results[index];
        return ListTile(
          title: Text(complaint.title),
          subtitle: Text(complaint.description),
          trailing: Text(complaint.tripId),
          onTap: () {
            close(context, null); // إغلاق شاشة البحث أولاً
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ComplaintDetails(
                  complaint: complaint,
                  primaryColor: primaryColor,
                  cardColor: cardColor,
                  textColor: textColor,
                  lightTextColor: lightTextColor,
                  onStatusUpdate: onStatusUpdate,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class ComplaintCategory {
  final String id;
  final String name;
  final IconData icon;

  ComplaintCategory({
    required this.id,
    required this.name,
    required this.icon,
  });
}

class Complaint {
  final String id;
  final String title;
  final String description;
  final ComplaintStatus status;
  final DateTime date;
  final DateTime resolvedAt;
 
  final String customerName;
  final String tripId;
  final String category;
  final Priority priority;
  final String? driverId;
  final String? userId;

  Complaint({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.date,
    required this.resolvedAt,
    required this.customerName,
    required this.tripId,
    required this.category,
    required this.priority,
    this.driverId,
    this.userId,
  });

  factory Complaint.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    return Complaint(
      id: doc.id,
      title: data['problemDescription'] ?? 'بدون عنوان',
      description: data['problemDescription'] ?? 'بدون وصف',
      status: _parseStatus(data['status']),
      date: (data['timestamp'] as Timestamp).toDate(),
      resolvedAt: (data['resolvedAt'] as Timestamp).toDate(),

       
      customerName: data['userId'] ?? 'مستخدم غير معروف',
      tripId: data['tripId'] ?? '',
      category: _parseCategory(data['category']),
      priority: _parsePriority(data['priority']),
      driverId: data['driverId'],
      userId: data['userId'],
    );
  }

  static ComplaintStatus _parseStatus(String? status) {
    switch (status) {
      case 'inProgress':
        return ComplaintStatus.inProgress;
      case 'resolved':
        return ComplaintStatus.resolved;
      case 'rejected':
        return ComplaintStatus.rejected;
      default:
        return ComplaintStatus.pending;
    }
  }

  static Priority _parsePriority(dynamic priority) {
    if (priority == null) return Priority.medium;
    
    if (priority is String) {
      switch (priority.toLowerCase()) {
        case 'high': return Priority.high;
        case 'low': return Priority.low;
        default: return Priority.medium;
      }
    }
    
    return Priority.medium;
  }

  static String _parseCategory(dynamic category) {
    if (category == null) return 'other';
    
    final String categoryStr = category.toString().toLowerCase().trim();
    
    final Map<String, List<String>> categoryMap = {
     // 'harassment': ['تحرش', 'harassment', 'molestation'],
      'abuse': ['سب', 'إهانة', 'abuse', 'insult', 'شتم'],
      'payment': ['دفع', 'payment', 'transaction', 'مال'],
      'behavior': ['سلوك', 'behavior', 'conduct', 'أخلاق'],
      'route': ['طريق', 'route', 'direction', 'مسار'],
      'vehicle': ['مركبة', 'vehicle', 'car', 'سيارة'],
      'other': ['أخرى', 'other', 'unknown', 'غير ذلك']
    };

    for (final entry in categoryMap.entries) {
      if (entry.value.any((alias) => alias.toLowerCase() == categoryStr)) {
        return entry.key;
      }
    }
    
    return 'other';
  }
}

enum ComplaintStatus { pending, inProgress, resolved, rejected }
enum Priority { low, medium, high, critical }