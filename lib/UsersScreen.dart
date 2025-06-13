import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class UsersPage extends StatefulWidget {
  @override
  _UsersPageState createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  final DatabaseReference _usersRef = FirebaseDatabase.instance.ref("users");
  List<Map<dynamic, dynamic>> _users = [];

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  void _fetchUsers() {
    _usersRef.onValue.listen((DatabaseEvent event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null) {
        setState(() {
          _users = data.entries.map((e) => {"id": e.key, ...e.value}).toList();
        });
      }
    });
  }

  void _deleteUser(String userId) {
    _usersRef.child(userId).remove();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xff1E1E2E),
      appBar: AppBar(
        backgroundColor: Color(0xff1E1E2E),
        title: Row(
          children: [
            Icon(Icons.people, color: Colors.white), // أيقونة المستخدمين
            SizedBox(width: 8),
            Text("Users", style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Table(
          border: TableBorder.all(color: Colors.orange),
          columnWidths: {
            0: FlexColumnWidth(2),
            1: FlexColumnWidth(3),
            2: FlexColumnWidth(3),
            3: FlexColumnWidth(2),
          },
          children: [
            // الصف الأول: العناوين
            TableRow(
              decoration: BoxDecoration(color: Colors.orange),
              children: [
                _tableHeader("Name"),
                _tableHeader("Email"),
                _tableHeader("Phone"),
                _tableHeader("Actions"),
              ],
            ),
            // الصف الثاني: بيانات افتراضية + زرارين مع أيقونات
            TableRow(
              decoration: BoxDecoration(color: Colors.grey[700]),
              children: [
                _tableCell("John Doe"), // مثال للاسم
                _tableCell("john@example.com"), // مثال للبريد
                _tableCell("+1234567890"), // مثال للهاتف
                Padding(
                  padding: EdgeInsets.all(8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: null, // زر غير مفعّل لأنه مثال فقط
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green ,
                        ),
                        icon: Icon(Icons.edit, size: 16),
                        label: Text("Edit"),
                      ),
                      SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: null, // زر غير مفعّل لأنه مثال فقط
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red ,
                        ),
                        
                        
                        icon: Icon(Icons.delete, size: 16),
                        label: Text("Delete"),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // البيانات الفعلية من قاعدة البيانات
            ..._users.map((user) => TableRow(
                  decoration: BoxDecoration(color: Colors.black54),
                  children: [
                    _tableCell(user["name"] ?? "-"),
                    _tableCell(user["email"] ?? "-"),
                    _tableCell(user["phone"] ?? "-"),
                    Padding(
                      padding: EdgeInsets.all(8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () {}, // وظيفة التعديل هنا
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                            ),
                            icon: Icon(Icons.edit, size: 16),
                            label: Text("Edit"),
                          ),
                          SizedBox(width: 10),
                          ElevatedButton.icon(
                            onPressed: () => _deleteUser(user["id"]),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                            icon: Icon(Icons.delete, size: 16),
                            label: Text("Delete"),
                          ),
                        ],
                      ),
                    ),
                  ],
                )),
          ],
        ),
      ),
    );
  }

  Widget _tableHeader(String title) {
    return Padding(
      padding: EdgeInsets.all(8),
      child: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _tableCell(String text) {
    return Padding(
      padding: EdgeInsets.all(8),
      child: Text(
        text,
        style: TextStyle(color: Colors.white),
        textAlign: TextAlign.center,
      ),
    );
  }
}
