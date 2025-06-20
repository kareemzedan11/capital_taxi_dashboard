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
  int _currentTabIndex = 0;
  String _searchQuery = '';

  final List<Map<String, dynamic>> _sentEmails = [];

  @override
  void initState() {
    super.initState();
    // Load some dummy data for demonstration
    _loadSampleData();
  }

  void _loadSampleData() {
    setState(() {
      _sentEmails.addAll([
        {
          'email': 'driver1@example.com',
          'subject': 'New Ride Assignment',
          'message': 'You have been assigned a new ride from downtown to airport.',
          'type': 'Driver',
          'time': DateTime.now().subtract(const Duration(minutes: 30)),
        },
        {
          'email': 'rider1@example.com',
          'subject': 'Ride Confirmation',
          'message': 'Your ride has been confirmed. Driver will arrive in 5 minutes.',
          'type': 'Rider',
          'time': DateTime.now().subtract(const Duration(hours: 2)),
        },
        {
          'email': 'driver2@example.com',
          'subject': 'Weekly Performance',
          'message': 'Your weekly performance report is ready.',
          'type': 'Driver',
          'time': DateTime.now().subtract(const Duration(days: 1)),
        },
      ]);
    });
  }

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
            icon: const Icon(Icons.search),
            onPressed: () => _showSearchDialog(),
          ),
          const SizedBox(width: 8),
          const CircleAvatar(
            backgroundImage: NetworkImage('https://randomuser.me/api/portraits/men/41.jpg'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: _buildDashboard(),
    );
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search Messages'),
        content: TextField(
          onChanged: (value) => setState(() => _searchQuery = value),
          decoration: const InputDecoration(
            hintText: 'Search by email, subject or message',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() => _searchQuery = '');
              Navigator.pop(context);
            },
            child: const Text('Clear'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    final filteredEmails = _sentEmails.where((email) {
      final query = _searchQuery.toLowerCase();
      return email['email'].toLowerCase().contains(query) ||
          email['subject'].toLowerCase().contains(query) ||
          email['message'].toLowerCase().contains(query);
    }).toList();

    final driverEmails = filteredEmails.where((e) => e['type'] == 'Driver').toList();
    final riderEmails = filteredEmails.where((e) => e['type'] == 'Rider').toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildUserTypeTabs(),
          const SizedBox(height: 16),
          _buildStatsCards(driverEmails.length, riderEmails.length),
          const SizedBox(height: 16),
          _buildMessageComposer(),
          const SizedBox(height: 24),
          _currentTabIndex == 0
              ? _buildMessageList(driverEmails, 'Driver Messages')
              : _buildMessageList(riderEmails, 'Rider Messages'),
        ],
      ),
    );
  }

  Widget _buildUserTypeTabs() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _currentTabIndex = 0),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _currentTabIndex == 0 
                        ? Colors.blue.withOpacity(0.2) 
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.directions_car, 
                          color: _currentTabIndex == 0 ? Colors.blue : Colors.grey),
                      const SizedBox(width: 8),
                      Text('Drivers', 
                          style: TextStyle(
                            fontWeight: _currentTabIndex == 0 
                                ? FontWeight.bold 
                                : FontWeight.normal,
                            color: _currentTabIndex == 0 ? Colors.blue : Colors.grey,
                          )),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _currentTabIndex = 1),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _currentTabIndex == 1 
                        ? Colors.green.withOpacity(0.2) 
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person, 
                          color: _currentTabIndex == 1 ? Colors.green : Colors.grey),
                      const SizedBox(width: 8),
                      Text('Riders', 
                          style: TextStyle(
                            fontWeight: _currentTabIndex == 1 
                                ? FontWeight.bold 
                                : FontWeight.normal,
                            color: _currentTabIndex == 1 ? Colors.green : Colors.grey,
                          )),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCards(int driverCount, int riderCount) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            title: 'Total Drivers',
            value: driverCount.toString(),
            icon: Icons.directions_car,
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            title: 'Total Riders',
            value: riderCount.toString(),
            icon: Icons.person,
            color: Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            title: 'Messages Sent',
            value: _sentEmails.length.toString(),
            icon: Icons.email,
            color: Colors.purple,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({required String title, required String value, required IconData icon, required Color color}) {
    return Card(
      elevation: 2,
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
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageComposer() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Compose New Message',
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
                      decoration: InputDecoration(
                        labelText: 'Recipient Email',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.email),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.contacts),
                          onPressed: () => _showContactPicker(),
                        ),
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
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: DropdownButton<String>(
                      value: _selectedUserType,
                      underline: const SizedBox(),
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
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send, size: 18),
                  label: Text(_isSending ? 'Sending...' : 'Send Message'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    backgroundColor: _selectedUserType == 'Driver' 
                        ? Colors.blue 
                        : Colors.green,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showContactPicker() {
    // In a real app, this would show a list of contacts from your database
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Contact'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: 5, // Sample contacts
            itemBuilder: (context, index) {
              final email = _currentTabIndex == 0 
                  ? 'driver${index+1}@example.com'
                  : 'rider${index+1}@example.com';
              return ListTile(
                leading: Icon(
                  _currentTabIndex == 0 ? Icons.directions_car : Icons.person,
                  color: _currentTabIndex == 0 ? Colors.blue : Colors.green,
                ),
                title: Text(email),
                onTap: () {
                  setState(() {
                    _emailController.text = email;
                  });
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildMessageList(List<Map<String, dynamic>> emails, String title) {
    return Card(
      elevation: 2,
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
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Total: ${emails.length}',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (emails.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'No messages found',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: emails.length,
                itemBuilder: (context, index) {
                  final email = emails[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    elevation: 1,
                    child: ListTile(
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
                      title: Text(
                        email['subject'],
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('To: ${email['email']}'),
                          const SizedBox(height: 4),
                          Text(
                            email['message'],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            DateFormat('MMM d').format(email['time']),
                            style: const TextStyle(fontSize: 12),
                          ),
                          Text(
                            DateFormat('h:mm a').format(email['time']),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                      onTap: () => _showMessageDetails(email),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showMessageDetails(Map<String, dynamic> email) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(email['subject']),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  email['type'] == 'Driver' 
                      ? Icons.directions_car 
                      : Icons.person,
                  color: email['type'] == 'Driver' ? Colors.blue : Colors.green,
                ),
                title: Text('Recipient: ${email['email']}'),
                subtitle: Text('Type: ${email['type']}'),
              ),
              const SizedBox(height: 16),
              const Text(
                'Message:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(email['message']),
              const SizedBox(height: 16),
              Text(
                'Sent on: ${DateFormat.yMMMd().add_jm().format(email['time'])}',
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class EmailService with ChangeNotifier {
  static const String _brevoApiKey = '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';
  static const String _brevoApiUrl = 'https://api.brevo.com/v3/smtp/email';

  Future<Map<String, dynamic>> sendEmail(
    String toEmail, 
    String subject, 
    String message, 
    String userType,
  ) async {
    try {
      final response = await http.post(
        Uri.parse(_brevoApiUrl),
        headers: {
          'Content-Type': 'application/json',
          'api-key': _brevoApiKey,
        },
        body: json.encode({
          'sender': {
            'name': 'Capital Taxi',
            'email': 'wwwahmedahmid88@gmail.com',
          },
          'to': [
            {'email': toEmail}
          ],
          'subject': subject,
          'htmlContent': '''
            <html>
              <body>
                <p><strong>User Type:</strong> $userType</p>
                <p>$message</p>
              </body>
            </html>
          ''',
        }),
      );

      if (response.statusCode == 201) {
        return {'status': 'success', 'message': 'Email sent successfully via Brevo'};
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
