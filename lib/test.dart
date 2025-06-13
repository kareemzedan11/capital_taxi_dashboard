import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

final supabase = Supabase.instance.client;

class UploadImageScreen extends StatefulWidget {
  const UploadImageScreen({super.key});

  @override
  State<UploadImageScreen> createState() => _UploadImageScreenState();
}
class _UploadImageScreenState extends State<UploadImageScreen> {
  List<_DriverImage> driverImages = [];

  @override
  void initState() {
    super.initState();
    fetchDriverImages('67fe33fbc85b95a1338fc9ae').then((images) {
      setState(() {
        driverImages = images;
      });
    });
  }

  Future<List<_DriverImage>> fetchDriverImages(String driverId) async {
    try {
      final files = await supabase.storage
          .from('driver-documents')
          .list(path: driverId);

      if (files.isEmpty) {
        print('No images found.');
        return [];
      }

      final images = files.map((file) {
        final filePath = '$driverId/${file.name}';
        final url = supabase.storage
            .from('driver-documents')
            .getPublicUrl(filePath);
        return _DriverImage(name: file.name, url: url);
      }).toList();

      return images;
    } catch (e) {
      print('Error fetching driver images: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Driver Docs')),
      body: driverImages.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: driverImages.length,
              itemBuilder: (context, index) {
                final img = driverImages[index];
                return Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 6,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                          child: Image.network(
                            img.url,
                            height: 200,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Text(
                            img.name,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            textAlign: TextAlign.center,
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
}

class _DriverImage {
  final String name;
  final String url;

  _DriverImage({required this.name, required this.url});
}
