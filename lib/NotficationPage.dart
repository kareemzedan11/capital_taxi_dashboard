import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationsPage extends StatefulWidget {
  @override
  _NotificationsPageState createState() => _NotificationsPageState();
}
class _NotificationsPageState extends State<NotificationsPage> {
  List<NotificationModel> _notifications = [];
  bool _isLoading = true;
  String _selectedFilter = 'all';
  int _unreadCount = 0;
  final TextEditingController _searchController = TextEditingController();
  bool _showSearch = false;
  final _scrollController = ScrollController();
  bool _showScrollToTop = false;

  // Professional color palette
  final Color _primaryColor = Color(0xFF4361EE); // Royal blue
  final Color _secondaryColor = Color(0xFF3F37C9); // Darker blue
  final Color _accentColor = Color(0xFF4CC9F0); // Light blue
  final Color _urgentColor = Color(0xFFF72585); // Pink for urgent items
  final Color _successColor = Color(0xFF4AD66D); // Green for success
  final Color _warningColor = Color(0xFFF8961E); // Orange for warnings
  final Color _cardColor = Colors.white;
  final Color _backgroundColor = Color(0xFF2A2A3A); // Very light grey
  final Color _textColor = Color(0xFF212529); // Dark grey for text
  final Color _subtextColor = Color(0xFF6C757D); // Lighter grey for subtext

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }


  void _scrollListener() {
    if (_scrollController.offset > 400 && !_showScrollToTop) {
      setState(() => _showScrollToTop = true);
    } else if (_scrollController.offset <= 400 && _showScrollToTop) {
      setState(() => _showScrollToTop = false);
    }
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    
    try {
      final response = await Supabase.instance.client
          .from('notifications')
          .select('*')
          .order('created_at', ascending: false);
      
      final notifications = response.map((json) => NotificationModel.fromJson(json)).toList();
      
      setState(() {
        _notifications = notifications;
        _unreadCount = notifications.where((n) => !n.isRead).length;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load notifications'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _markAsRead(NotificationModel notification) async {
    try {
      await Supabase.instance.client
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notification.id);
      
      setState(() {
        notification.isRead = true;
        _unreadCount = _notifications.where((n) => !n.isRead).length;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to mark as read')),
      );
    }
  }

  Future<bool> _confirmDeleteNotification(NotificationModel notification) async {
    return await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Notification'),
        content: Text('Are you sure you want to delete this notification?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<void> _deleteNotification(NotificationModel notification) async {
    try {
      await Supabase.instance.client
          .from('notifications')
          .delete()
          .eq('id', notification.id);
      
      setState(() {
        _notifications.remove(notification);
        if (!notification.isRead) {
          _unreadCount = _notifications.where((n) => !n.isRead).length;
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete notification')),
      );
    }
  }

  void _showNotificationDetails(NotificationModel notification) {
    if (!notification.isRead) {
      _markAsRead(notification);
    }
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => NotificationDetailsSheet(notification: notification),
    );
  }

  void _handleAction(NotificationModel notification, NotificationAction action) {
    switch (action.type) {
      case 'open_url':
        _launchUrl(action.payload);
        break;
      case 'navigate':
        // Handle navigation
        break;
      case 'call':
        _makePhoneCall(action.payload);
        break;
    }
  }

  Future<void> _launchUrl(String url) async {
    // Implementation for launching URL
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    // Implementation for making phone call
  }

    @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          Column(
            children: [
              _buildStatsHeader(),
              _buildFiltersRow(),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadNotifications,
                  child: _isLoading
                      ? _buildLoadingIndicator()
                      : _notifications.isEmpty
                          ? _buildEmptyState()
                          : _buildNotificationsList(),
                ),
              ),
            ],
          ),
          if (_showScrollToTop)
            Positioned(
              bottom: 20,
              right: 20,
              child: FloatingActionButton(
                mini: true,
                backgroundColor: _primaryColor,
                onPressed: () {
                  _scrollController.animateTo(
                    0,
                    duration: Duration(milliseconds: 500),
                    curve: Curves.easeInOut,
                  );
                },
                child: Icon(Icons.arrow_upward, color: Colors.white),
                elevation: 4,
              ),
            ),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      
      title: _showSearch 
          ? TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search notifications...',
                hintStyle: TextStyle(color: Colors.white70),
                border: InputBorder.none,
                suffixIcon: IconButton(
                  icon: Icon(Icons.close),
                  onPressed: () {
                    setState(() {
                      _showSearch = false;
                      _searchController.clear();
                    });
                  },
                ),
              ),
              style: TextStyle(color: Colors.white),
              autofocus: true,
              onChanged: (value) => setState(() {}),
            )
          : Text('Notifications', style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.white
            )),
      centerTitle: true,
      backgroundColor: _primaryColor,
      elevation: 0,
    
      actions: [
        IconButton(
          icon: Icon(_showSearch ? Icons.search_off : Icons.search),
          onPressed: () => setState(() => _showSearch = !_showSearch),
        ),
        _buildNotificationBadge(),
      ],
    );
  }

  Widget _buildNotificationBadge() {
    return Stack(
      children: [
        IconButton(
          icon: Icon(Icons.notifications_none, color: Colors.white),
          onPressed: () {},
        ),
        if (_unreadCount > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: _urgentColor,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: BoxConstraints(
                minWidth: 18,
                minHeight: 18,
              ),
              child: Text(
                '$_unreadCount',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStatsHeader() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatItem(Icons.notifications_active, 'Total', _notifications.length.toString(), _primaryColor),
          _buildStatItem(Icons.mark_email_unread, 'Unread', _unreadCount.toString(), _urgentColor),
          _buildStatItem(
            Icons.today,
            'Today',
            _notifications
                .where((n) => n.createdAt.isAfter(DateTime.now().subtract(Duration(days: 1))))
                .length
                .toString(),
            _accentColor,
          ),
          _buildStatItem(
            Icons.priority_high,
            'Urgent',
            _notifications.where((n) => n.isUrgent).length.toString(),
            _warningColor,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value, Color color) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        SizedBox(height: 8),
        Text(label, style: TextStyle(
          fontSize: 12, 
          color: _subtextColor,
          fontWeight: FontWeight.w500
        )),
        SizedBox(height: 4),
        Text(value, style: TextStyle(
          fontWeight: FontWeight.bold, 
          fontSize: 16,
          color: _textColor
        )),
      ],
    );
  }

  Widget _buildFiltersRow() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: _cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip('All', 'all'),
            _buildFilterChip('Unread', 'unread'),
            _buildFilterChip('System', 'system'),
            _buildFilterChip('Payments', 'payments'),
            _buildFilterChip('Trips', 'trips'),
            _buildFilterChip('Urgent', 'urgent'),
            _buildFilterChip('Promotions', 'promotions'),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) => setState(() => _selectedFilter = selected ? value : 'all'),
        selectedColor: _primaryColor.withOpacity(0.2),
        backgroundColor: Colors.transparent,
        labelStyle: TextStyle(
          color: isSelected ? _primaryColor : _subtextColor,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
        ),
        shape: StadiumBorder(
          side: BorderSide(
            color: isSelected ? _primaryColor : Colors.grey[300]!,
          ),
        ),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        showCheckmark: false,
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: _primaryColor),
          SizedBox(height: 16),
          Text('Loading notifications...', style: TextStyle(
            color: _subtextColor,
            fontSize: 16
          )),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off, size: 60, color: _subtextColor.withOpacity(0.5)),
          SizedBox(height: 16),
          Text('No notifications yet', style: TextStyle(
            fontSize: 18, 
            color: _textColor,
            fontWeight: FontWeight.w600
          )),
          SizedBox(height: 8),
          Text('When you get notifications, they\'ll appear here',
              style: TextStyle(
                color: _subtextColor,
                fontSize: 14
              )),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadNotifications,
            child: Text('Refresh', style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500
            )),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              elevation: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsList() {
    final filteredNotifications = _notifications.where((notification) {
      if (_searchController.text.isNotEmpty) {
        final searchTerm = _searchController.text.toLowerCase();
        if (!notification.title.toLowerCase().contains(searchTerm) &&
            !notification.body.toLowerCase().contains(searchTerm)) {
          return false;
        }
      }
      
      switch (_selectedFilter) {
        case 'unread': return !notification.isRead;
        case 'system': return notification.type == 'system';
        case 'payments': return notification.type == 'payment';
        case 'trips': return notification.type == 'trip';
        case 'urgent': return notification.isUrgent;
        case 'promotions': return notification.type == 'promotion';
        default: return true;
      }
    }).toList();

    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.only(top: 8, bottom: 80),
      itemCount: filteredNotifications.length,
      itemBuilder: (context, index) {
        final notification = filteredNotifications[index];
        return _buildNotificationItem(notification);
      },
    );
  }

  Widget _buildNotificationItem(NotificationModel notification) {
    return Dismissible(
      key: Key(notification.id),
      background: _buildDismissibleBackground(),
      secondaryBackground: _buildDismissibleBackground(isDelete: true),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) {
          return await _confirmDeleteNotification(notification);
        }
        return false;
      },
      onDismissed: (direction) {
        if (direction == DismissDirection.startToEnd) {
          _markAsRead(notification);
        } else if (direction == DismissDirection.endToStart) {
          _deleteNotification(notification);
        }
      },
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Material(
          borderRadius: BorderRadius.circular(12),
          color: _cardColor,
          elevation: 1,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _showNotificationDetails(notification),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _getNotificationColor(notification.type).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getNotificationIcon(notification.type),
                      color: _getNotificationColor(notification.type),
                      size: 20,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                notification.title,
                                style: TextStyle(
                                  fontWeight: notification.isRead 
                                      ? FontWeight.w500 
                                      : FontWeight.w600,
                                  fontSize: 16,
                                  color: notification.isRead 
                                      ? _subtextColor 
                                      : _textColor,
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              _formatTime(notification.createdAt),
                              style: TextStyle(
                                color: _subtextColor,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 6),
                        Text(
                          notification.body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _subtextColor,
                            fontSize: 14,
                          ),
                        ),
                        if (notification.actions.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: notification.actions
                                  .map((action) => ActionChip(
                                        label: Text(action.label),
                                        onPressed: () => _handleAction(notification, action),
                                        backgroundColor: _primaryColor.withOpacity(0.1),
                                        labelStyle: TextStyle(
                                          color: _primaryColor,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500
                                        ),
                                        shape: StadiumBorder(
                                          side: BorderSide(
                                            color: _primaryColor.withOpacity(0.2),
                                          ),
                                        ),
                                      ))
                                  .toList(),
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
      ),
    );
  }

  Widget _buildDismissibleBackground({bool isDelete = false}) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: isDelete ? _urgentColor.withOpacity(0.1) : _successColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Align(
        alignment: isDelete ? Alignment.centerRight : Alignment.centerLeft,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Icon(
            isDelete ? Icons.delete : Icons.mark_email_read,
            color: isDelete ? _urgentColor : _successColor,
          ),
        ),
      ),
    );
  }
Future<void> _markAllAsRead() async {
  if (_notifications.isEmpty || _unreadCount == 0) return;

  try {
    // Show loading indicator
    setState(() => _isLoading = true);

    // Update all unread notifications in the database
    await Supabase.instance.client
        .from('notifications')
        .update({'is_read': true})
        .neq('is_read', true);

    // Update local state
    setState(() {
      for (var notification in _notifications) {
        notification.isRead = true;
      }
      _unreadCount = 0;
      _isLoading = false;
    });

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('All notifications marked as read'),
        backgroundColor: _successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  } catch (e) {
    setState(() => _isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Failed to mark all as read'),
        backgroundColor: _urgentColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
  Widget _buildFloatingActionButton() {
    return FloatingActionButton(
      onPressed: _markAllAsRead,
      child: Icon(Icons.done_all),
      backgroundColor: _primaryColor,
      tooltip: 'Mark all as read',
      elevation: 4,
    );
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'system': return _secondaryColor;
      case 'payment': return _successColor;
      case 'trip': return _accentColor;
      case 'promotion': return _warningColor;
      case 'urgent': return _urgentColor;
      default: return _primaryColor;
    }
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'system': return Icons.settings_outlined;
      case 'payment': return Icons.payment_outlined;
      case 'trip': return Icons.directions_car_outlined;
      case 'promotion': return Icons.local_offer_outlined;
      case 'urgent': return Icons.priority_high;
      default: return Icons.notifications_outlined;
    }
  }

  String _formatTime(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(Duration(days: 1));
    
    final dateOnly = DateTime(date.year, date.month, date.day);
    
    if (dateOnly == today) {
      return DateFormat('h:mm a').format(date);
    } else if (dateOnly == yesterday) {
      return 'Yesterday';
    } else if (date.isAfter(now.subtract(Duration(days: 7)))) {
      return DateFormat('EEE').format(date);
    } else {
      return DateFormat('MMM d').format(date);
    }
  }
}

class NotificationDetailsSheet extends StatelessWidget {
  final NotificationModel notification;
  final Color _primaryColor = Color(0xFF4361EE);
  final Color _textColor = Color(0xFF212529);
  final Color _subtextColor = Color(0xFF6C757D);

    NotificationDetailsSheet({required this.notification});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              SizedBox(height: 24),
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _getNotificationColor(notification.type).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getNotificationIcon(notification.type),
                      color: _getNotificationColor(notification.type),
                      size: 24,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          notification.title,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: _textColor,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          _formatDetailedTime(notification.createdAt),
                          style: TextStyle(
                            color: _subtextColor,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification.body,
                        style: TextStyle(
                          fontSize: 16,
                          color: _textColor,
                          height: 1.5,
                        ),
                      ),
                      if (notification.actions.isNotEmpty) ...[
                        SizedBox(height: 32),
                        Text(
                          'Available Actions',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: _textColor,
                          ),
                        ),
                        SizedBox(height: 16),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: notification.actions
                              .map((action) => ElevatedButton(
                                    onPressed: () {
                                      // Handle action
                                      Navigator.pop(context);
                                    },
                                    child: Text(action.label),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _getNotificationColor(notification.type),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 12,
                                      ),
                                    ),
                                  ))
                              .toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Close'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _primaryColor,
                    side: BorderSide(color: _primaryColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'system': return Color(0xFF3F37C9);
      case 'payment': return Color(0xFF4AD66D);
      case 'trip': return Color(0xFF4CC9F0);
      case 'promotion': return Color(0xFFF8961E);
      case 'urgent': return Color(0xFFF72585);
      default: return Color(0xFF4361EE);
    }
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'system': return Icons.settings_outlined;
      case 'payment': return Icons.payment_outlined;
      case 'trip': return Icons.directions_car_outlined;
      case 'promotion': return Icons.local_offer_outlined;
      case 'urgent': return Icons.priority_high;
      default: return Icons.notifications_outlined;
    }
  }

  String _formatDetailedTime(DateTime date) {
    return DateFormat('MMMM d, y • h:mm a').format(date);
  }

}

class NotificationModel {
  final String id;
  final String title;
  final String body;
  final String type;
  final DateTime createdAt;
  bool isRead;
  final bool isUrgent;
  final List<NotificationAction> actions;

  NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    this.isRead = false,
    this.isUrgent = false,
    this.actions = const [],
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'],
      title: json['title'],
      body: json['body'],
      type: json['type'] ?? 'general',
      createdAt: DateTime.parse(json['created_at']),
      isRead: json['is_read'] ?? false,
      isUrgent: json['is_urgent'] ?? false,
      actions: (json['actions'] as List? ?? [])
          .map((action) => NotificationAction.fromJson(action))
          .toList(),
    );
  }
}

class NotificationAction {
  final String type;
  final String label;
  final String payload;

  NotificationAction({
    required this.type,
    required this.label,
    required this.payload,
  });

  factory NotificationAction.fromJson(Map<String, dynamic> json) {
    return NotificationAction(
      type: json['type'],
      label: json['label'],
      payload: json['payload'],
    );
  }
}