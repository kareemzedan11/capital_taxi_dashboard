import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class EmailContact extends StatefulWidget {
  const EmailContact({super.key});

  @override
  State<EmailContact> createState() => _EmailContactState();
}

class _EmailContactState extends State<EmailContact> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  String _selectedUserType = 'Driver';
  bool _isSending = false;

  final List<Map<String, dynamic>> _sentEmails = [];

  Future<void> _sendEmail() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSending = true);

    try {
      final emailService = Provider.of<EmailService>(context, listen: false);
      final result = await emailService.sendEmail(
        _emailController.text.trim(),
        _subjectController.text.trim(),
        _messageController.text.trim(),
        _selectedUserType,
      );

      if (result['status'] == 'success') {
        setState(() {
          _sentEmails.insert(0, {
            'email': _emailController.text,
            'subject': _subjectController.text,
            'message': _messageController.text,
            'type': _selectedUserType,
            'time': DateTime.now(),
          });
        });

        _emailController.clear();
        _subjectController.clear();
        _messageController.clear();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${result['message']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send email: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ride Messaging Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {},
          ),
          const CircleAvatar(
            backgroundImage: NetworkImage('https://randomuser.me/api/portraits/men/41.jpg'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: _buildDashboard(),
    );
  }

  Widget _buildDashboard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dashboard Overview',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            _buildStatsRow(),
            const SizedBox(height: 32),
            _buildMessageCard(),
            const SizedBox(height: 32),
            _buildRecentMessages(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        _buildStatCard('Total Messages Sent', '1,245', Icons.email, Colors.blueAccent),
        const SizedBox(width: 16),
        _buildStatCard('Drivers', '356', Icons.directions_car, Colors.greenAccent),
        const SizedBox(width: 16),
        _buildStatCard('Riders', '892', Icons.person, Colors.orangeAccent),
        const SizedBox(width: 16),
        _buildStatCard('Open Rate', '78%', Icons.trending_up, Colors.purpleAccent),
      ],
    );
  }

  Widget _buildMessageCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Message',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
  controller: _emailController,
  decoration: const InputDecoration(
    labelText: 'Email',
    border: OutlineInputBorder(),
    prefixIcon: Icon(Icons.email),
    hintText: 'example@domain.com',
  ),
  validator: (value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
      return 'Enter a valid email address';
    }
    return null;
  },
  keyboardType: TextInputType.emailAddress,
),
                ),
                const SizedBox(width: 16),
                DropdownButton<String>(
                  value: _selectedUserType,
                  items: ['Driver', 'Rider']
                      .map((type) => DropdownMenuItem(
                            value: type,
                            child: Text(type),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedUserType = value!;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _subjectController,
              decoration: const InputDecoration(
                labelText: 'Subject',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.subject),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Subject is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _messageController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Message',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Message is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: _isSending ? null : _sendEmail,
                icon: _isSending 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Icon(Icons.send),
                label: Text(_isSending ? 'Sending...' : 'Send Message'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentMessages() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Messages',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (_sentEmails.isEmpty)
              const Center(child: Text('No messages sent yet'))
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _sentEmails.length,
                itemBuilder: (context, index) {
                  final email = _sentEmails[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: email['type'] == 'Driver'
                          ? Colors.blue[100]
                          : Colors.green[100],
                      child: Icon(
                        email['type'] == 'Driver'
                            ? Icons.directions_car
                            : Icons.person,
                        color: email['type'] == 'Driver'
                            ? Colors.blue
                            : Colors.green,
                      ),
                    ),
                    title: Text(email['subject']),
                    subtitle: Text(
                        'To: ${email['email']}\n${email['message'].toString().substring(0, email['message'].toString().length > 30 ? 30 : email['message'].toString().length)}...'),
                    trailing: Text(
                      DateFormat('MMM d, h:mm a').format(email['time']),
                    ),
                    onTap: () {
                      // Show details
                    },
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: GoogleFonts.poppins(
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
}class EmailService with ChangeNotifier {
  static const String _serviceId = 'Capital Taxi';
  static const String _templateId = 'template_2brn8uy'; // تأكد من أن هذا هو ID الصحيح
  static const String _userId = 'aSu9wQM4Aap0ML7Sd';
  static const String _emailJsUrl = 'https://api.emailjs.com/api/v1.0/email/send';

  Future<Map<String, dynamic>> sendEmail(
      String toEmail, String subject, String message, String userType) async {
    try {
      // تحقق إضافي من صحة الإيميل
      if (toEmail.isEmpty || !toEmail.contains('@')) {
        return {'status': 'error', 'message': 'Invalid recipient email'};
      }

      final response = await http.post(
        Uri.parse(_emailJsUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'service_id': _serviceId,
          'template_id': _templateId,
          'user_id': _userId,
          'template_params': {
            'to_email': toEmail,
            'subject': subject,
            'message': message,
            'user_type': userType,
            'name': 'User', // إضافة حقل name المطلوب في القالب
            'email': toEmail, // إضافة حقل email المطلوب في القالب
          }
        }),
      );

      if (response.statusCode == 200) {
        return {'status': 'success', 'message': 'Email sent successfully'};
      } else {
        return {
          'status': 'error',
          'message': 'Failed to send email (${response.statusCode}): ${response.body}'
        };
      }
    } catch (e) {
      return {'status': 'error', 'message': 'Exception: ${e.toString()}'};
    }
  }
}