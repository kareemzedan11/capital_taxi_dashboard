import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class EarningsHistoryPage extends StatelessWidget {
  final String driverId;

  const EarningsHistoryPage({Key? key, required this.driverId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF1E1E2E),
      appBar: AppBar(
        title: Text('Earnings History', style: TextStyle(color: Colors.white)),
        backgroundColor: Color(0xFF252537),
        iconTheme: IconThemeData(color: Colors.orange),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('trips')
            .where('driver', isEqualTo: driverId)
            .where('status', whereIn: ['Completed', 'accepted'])
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
            print('❌ Error: ${snapshot.error}');
          if (snapshot.hasError) {
            return Center(
              child: Text('Error loading earnings', 
                style: TextStyle(color: Colors.white)),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: Colors.orange),
            );
          }

          final trips = snapshot.data?.docs ?? [];

          if (trips.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.money_off, size: 60, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No earnings history found', 
                    style: TextStyle(color: Colors.white70)),
                ],
              ),
            );
          }

          // حساب إجمالي الأرباح
          double totalEarnings = trips.fold(0, (sum, trip) {
            final data = trip.data() as Map<String, dynamic>;
            return sum + (data['fare']?.toDouble() ?? 0.0);
          });

          return Column(
            children: [
              // عرض إجمالي الأرباح
              Padding(
                padding: EdgeInsets.all(16),
                child: Card(
                  color: Colors.orange.withOpacity(0.1),
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total Earnings:',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                          )),
                        Text('\$${totalEarnings.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: Colors.orange,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          )),
                      ],
                    ),
                  ),
                ),
              ),
              
              // قائمة الرحلات/الأرباح
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  itemCount: trips.length,
                  itemBuilder: (context, index) {
                    final trip = trips[index];
                    final data = trip.data() as Map<String, dynamic>;
                    final date = DateTime.parse(data['createdAt']);
                    final amount = data['fare']?.toDouble() ?? 0.0;
                    final isCash = data['paymentMethod'] == 'cash';
                    final distance = data['distanceInKm'] ?? (data['distance'] ?? 0) / 1000;
                    final status = data['status'] ?? 'completed';

                    return Card(
                      margin: EdgeInsets.only(bottom: 12),
                      color: Color(0xFF2A2A3A),
                      child: ListTile(
                        contentPadding: EdgeInsets.all(16),
                        leading: Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isCash ? Icons.money : Icons.credit_card,
                            color: Colors.orange,
                          ),
                        ),
                        title: Text('\$${amount.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          )),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: 4),
                            Text('Trip #${trip.id.substring(0, 6)} • ${distance.toStringAsFixed(1)} km',
                              style: TextStyle(color: Colors.white70)),
                            SizedBox(height: 4),
                            Text(DateFormat('MMM dd, yyyy - HH:mm').format(date),
                              style: TextStyle(color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                        trailing: Chip(
                          label: Text(status.toUpperCase(),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            )),
                          backgroundColor: _getStatusColor(status),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'accepted':
        return Colors.green.withOpacity(0.3);
      case 'canceled':
      case 'rejected':
        return Colors.red.withOpacity(0.3);
      default:
        return Colors.grey.withOpacity(0.3);
    }
  }
}