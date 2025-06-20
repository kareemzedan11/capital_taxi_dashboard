import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

class PassengerEmergency extends StatefulWidget {
  const PassengerEmergency({super.key});

  @override
  State<PassengerEmergency> createState() => _PassengerEmergencyState();
}

class _PassengerEmergencyState extends State<PassengerEmergency> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
Future<String> _calculateAverageResponseTime() async {
  final messages = await _firestore.collection('emergency_messages').get();
  double totalResponseTime = 0;
  int responseCount = 0;

  for (var message in messages.docs) {
    final chatMessages = await message.reference.collection('chat')
        .orderBy('timestamp')
        .get();

    if (chatMessages.docs.length > 1) {
      final passengerMessage = chatMessages.docs.first;
      final operatorResponse = chatMessages.docs[1];

      final passengerTime = passengerMessage['timestamp'].toDate();
      final operatorTime = operatorResponse['timestamp'].toDate();
      final diff = operatorTime.difference(passengerTime).inSeconds;

      totalResponseTime += diff;
      responseCount++;
    }
  }

  if (responseCount == 0) return '0 دقائق';

  final averageSeconds = totalResponseTime / responseCount;
  final averageMinutes = (averageSeconds / 60).round();

  return averageMinutes <= 0 ? 'أقل من دقيقة' : '$averageMinutes دقائق';
}
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('طوارئ الركاب', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: Badge(
              child: const Icon(Iconsax.notification),
              isLabelVisible: true,
            ),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Stats Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 2,
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                 StreamBuilder<QuerySnapshot>(
  stream: _firestore.collection('emergency_messages').snapshots(),
  builder: (context, snapshot) {
    if (!snapshot.hasData) {
      return const Center(child: CircularProgressIndicator());
    }
    
    final messages = snapshot.data!.docs;
    final newMessages = messages.where((doc) => doc['isRead'] == false).length;
    final urgentMessages = messages.where((doc) => doc['status'] == 'urgent').length;
    final resolvedMessages = messages.where((doc) => doc['isResolved'] == true).length;

    return FutureBuilder<String>(
      future: _calculateAverageResponseTime(),
      builder: (context, avgSnapshot) {
        final avgResponse = avgSnapshot.data ?? 'جاري الحساب...';
        
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 2.5,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: [
            StatsCard(
              title: 'الرسائل الجديدة',
              value: '$newMessages',
              icon: Iconsax.message_text,
              color: Colors.blue,
            ),
            StatsCard(
              title: 'حالات طارئة',
              value: '$urgentMessages',
              icon: Iconsax.warning_2,
              color: Colors.red,
            ),
            StatsCard(
              title: 'تم الحل',
              value: '$resolvedMessages',
              icon: Iconsax.tick_circle,
              color: Colors.green,
            ),
            StatsCard(
              title: 'متوسط الرد',
              value: avgResponse,
              icon: Iconsax.clock,
              color: Colors.orange,
            ),
          ],
        );
      },
    );
  },
),
                ],
              ),
            ),
            
            // Messages List
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'الرسائل الأخيرة',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  StreamBuilder<QuerySnapshot>(
                    stream: _firestore
                        .collection('emergency_messages')
                        .orderBy('timestamp', descending: true)
                        .limit(10)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      
                      final messages = snapshot.data!.docs;
                      
                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final message = messages[index];
                         return EmergencyMessageCard(
  message: EmergencyMessage(
    id: message.id,
    passengerName: message['passengerName'],
    passengerId: message['passengerId'],
    driverName: message['driverName'],
    driverId: message['driverId'],
    tripNumber: message['tripNumber'],
    tripFrom: message['tripFrom'],
    tripTo: message['tripTo'],
    time: _formatTime(message['timestamp'].toDate()),
    message: message['message'],
    status: _parseStatus(message['status']),
    unread: !message['isRead'],
    passengerImage: message['passengerImage'] ?? '',
    isResolved: message['isResolved'] ?? false, // تأكد من وجود هذا السطر
  ),
  onTap: () {
    message.reference.update({'isRead': true});
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          message: EmergencyMessage(
            id: message.id,
            passengerName: message['passengerName'],
            passengerId: message['passengerId'],
            driverName: message['driverName'],
            driverId: message['driverId'],
            tripNumber: message['tripNumber'],
            tripFrom: message['tripFrom'],
            tripTo: message['tripTo'],
            time: _formatTime(message['timestamp'].toDate()),
            message: message['message'],
            status: _parseStatus(message['status']),
            unread: !message['isRead'],
            passengerImage: message['passengerImage'] ?? '',
            isResolved: message['isResolved'] ?? false, // وهنا أيضاً
          ),
        ),
      ),
    );
  },
);
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        color: Colors.white,
        child: Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Center(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
              ),
              onPressed: () {
                // إجراءات الطوارئ
              },
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Iconsax.warning_2, color: Colors.white),
                  SizedBox(width: 8),
                  Text('حالة طارئة', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
  }

  MessageStatus _parseStatus(String status) {
    switch (status) {
      case 'urgent':
        return MessageStatus.urgent;
      case 'medium':
        return MessageStatus.medium;
      case 'low':
        return MessageStatus.low;
      default:
        return MessageStatus.medium;
    }
  }
}

class StatsCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const StatsCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum MessageStatus { urgent, medium, low }

class EmergencyMessage {
  final String id;
  final String passengerName;
  final String passengerId;
  final String? passengerImage;
  final String driverName;
  final String driverId;
  final String tripNumber;
  final String tripFrom;
  final String tripTo;
  final String time;
  final String message;
  final MessageStatus status;
  final bool unread;
  final bool? isResolved; // أضف هذا الحقل

  EmergencyMessage({
    required this.id,
    required this.passengerName,
    required this.passengerId,
    this.passengerImage,
    required this.driverName,
    required this.driverId,
    required this.tripNumber,
    required this.tripFrom,
    required this.tripTo,
    required this.time,
    required this.message,
    required this.status,
    required this.unread,
    this.isResolved, // أضف هذا
  });
}

class EmergencyMessageCard extends StatelessWidget {
  final EmergencyMessage message;
  final VoidCallback onTap;

  const EmergencyMessageCard({
    super.key,
    required this.message,
    required this.onTap,
  });

  Color getStatusColor() {
    switch (message.status) {
      case MessageStatus.urgent:
        return Colors.red;
      case MessageStatus.medium:
        return Colors.orange;
      case MessageStatus.low:
        return Colors.blue;
    }
  }

  String getStatusText() {
    switch (message.status) {
      case MessageStatus.urgent:
        return 'طارئ';
      case MessageStatus.medium:
        return 'متوسط';
      case MessageStatus.low:
        return 'منخفض';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Passenger Avatar with Status
              Stack(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundImage: message.passengerImage != null 
                        ? NetworkImage(message.passengerImage!) 
                        : const AssetImage('assets/default_avatar.png') as ImageProvider,
                  ),
                  if (message.unread)
                    Positioned(
                      right: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          border: Border.all(color: Colors.white, width: 2),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              // Message Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          message.passengerName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Row(
                          children: [
                            if (message.status == MessageStatus.urgent && message.unread)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'طارئ',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            const SizedBox(width: 4),
                            Text(
                              message.time,
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'الرحلة: ${message.tripNumber} | ${message.tripFrom} - ${message.tripTo}',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'السائق: ${message.driverName}',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message.message,
                      style: TextStyle(
                        color: Colors.grey[700],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: getStatusColor().withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            getStatusText(),
                            style: TextStyle(
                              color: getStatusColor(),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (message.isResolved ?? false)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.check_circle, color: Colors.green, size: 14),
                                SizedBox(width: 4),
                                Text(
                                  'تم الحل',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
class ChatScreen extends StatefulWidget {
  final EmergencyMessage message;

  const ChatScreen({super.key, required this.message});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late CollectionReference _chatCollection;

  @override
  void initState() {
    super.initState();
    _chatCollection = _firestore
        .collection('emergency_messages')
        .doc(widget.message.id)
        .collection('chat');
    
    // Add initial message if this is a new chat
    _chatCollection.get().then((snapshot) {
      if (snapshot.size == 0) {
        _chatCollection.add({
          'senderId': widget.message.passengerId,
          'senderName': widget.message.passengerName,
          'message': widget.message.message,
          'timestamp': DateTime.now(),
          'isRead': false,
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundImage: widget.message.passengerImage != null 
                  ? NetworkImage(widget.message.passengerImage!) 
                  : const AssetImage('assets/default_avatar.png') as ImageProvider,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.message.passengerName),
                Text(
                  'الرحلة: ${widget.message.tripNumber}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Iconsax.call),
            onPressed: () {
              // Handle call action
            },
          ),
          PopupMenuButton(
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'resolve',
                child: Text('تم حل المشكلة'),
              ),
              const PopupMenuItem(
                value: 'details',
                child: Text('تفاصيل الرحلة'),
              ),
            ],
            onSelected: (value) {
              if (value == 'resolve') {
                _firestore.collection('emergency_messages')
                  .doc(widget.message.id)
                  .update({'isResolved': true});
                Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Trip Info Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.blue[50],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'الرحلة: ${widget.message.tripNumber}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text('${widget.message.tripFrom} - ${widget.message.tripTo}'),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('السائق:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(widget.message.driverName),
                  ],
                ),
              ],
            ),
          ),
          
          // Chat Messages
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _chatCollection
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                final messages = snapshot.data!.docs;
                
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe = message['senderId'] != widget.message.passengerId;
                    
                    return ChatBubble(
                      message: message['message'],
                      isMe: isMe,
                      time: _formatTime(message['timestamp'].toDate()),
                      senderName: isMe ? 'أنت' : message['senderName'],
                    );
                  },
                );
              },
            ),
          ),
          
          // Message Input
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Iconsax.add, color: Colors.blue),
            onPressed: () {},
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'اكتب رسالة...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: Colors.blue,
            child: IconButton(
              icon: const Icon(Iconsax.send1, color: Colors.white),
              onPressed: () {
                if (_messageController.text.trim().isNotEmpty) {
                  _chatCollection.add({
                    'senderId': 'operator_id', // Replace with actual operator ID
                    'senderName': 'المشغل',
                    'message': _messageController.text,
                    'timestamp': DateTime.now(),
                    'isRead': false,
                  });
                  _messageController.clear();
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
  }
}

class ChatBubble extends StatelessWidget {
  final String message;
  final bool isMe;
  final String time;
  final String senderName;

  const ChatBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.time,
    required this.senderName,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              senderName,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: isMe ? Colors.blue : Colors.grey[200],
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: isMe
                      ? const Radius.circular(16)
                      : const Radius.circular(4),
                  bottomRight: isMe
                      ? const Radius.circular(4)
                      : const Radius.circular(16),
                ),
              ),
              child: Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    style: TextStyle(
                      color: isMe ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    time,
                    style: TextStyle(
                      color: isMe ? Colors.white70 : Colors.grey[600],
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}