import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TripsPage extends StatefulWidget {
  @override
  _TripsPageState createState() => _TripsPageState();
}

class _TripsPageState extends State<TripsPage> {
final DatabaseReference _usersRef = FirebaseDatabase.instance.ref("users");
  List<Map<dynamic, dynamic>> _users = [];

  @override
  void initState() {
    super.initState();
 fetchDriverDocuments();
  
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xff1E1E2E),
 
    );
  }

}Future<void> fetchDriverDocuments() async {
  final driverId = '67fe33fbc85b95a1338fc9ae';
  
  try {
    final documents = await Supabase.instance.client.storage
        .from('driver-documents')
        .list(path: driverId);
    
    print('الملفات الموجودة لهذا السائق:');
    documents.forEach((file) => print(file.name));
    
  } catch (e) {
    print('حدث خطأ في جلب الملفات: $e');
  }
}Future<String> getDocumentUrl(String fileName) async {
  final driverId = '67fe33fbc85b95a1338fc9ae';
  
  try {
    final response = await Supabase.instance.client.storage
        .from('driver-documents')
        .createSignedUrl('$driverId/$fileName', 3600);
    
    return response;
  } catch (e) {
    throw Exception('فشل في جلب الملف: $fileName. الخطأ: ${e.toString()}');
  }
}