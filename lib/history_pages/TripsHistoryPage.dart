import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class TripsHistoryPage extends StatelessWidget {
  final String driverId;

  const TripsHistoryPage({Key? key, required this.driverId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF1E1E2E),
      appBar: AppBar(
        title: Text('Trips History', style: TextStyle(color: Colors.white)),
        backgroundColor: Color(0xFF252537),
        iconTheme: IconThemeData(color: Colors.orange),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('trips')
            .where('driver', isEqualTo: driverId)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          print('driverId used: $driverId');

          if (snapshot.hasError) {
      print('❌ Error: ${snapshot.error}');
return Center(
  child: Text('Error loading trips',
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
                  Icon(Icons.history, size: 60, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No trips history found', 
                    style: TextStyle(color: Colors.white70)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: trips.length,
            itemBuilder: (context, index) {
              final trip = trips[index];
              final data = trip.data() as Map<String, dynamic>;
              final createdAt = DateTime.parse(data['createdAt']);
              final distance = data['distanceInKm'] ?? (data['distance'] ?? 0) / 1000;
              final fare = data['fare']?.toDouble() ?? 0.0;
              final status = data['status'] ?? 'unknown';
              final origin = _formatAddress(data['origin']);
              final destination = _formatAddress(data['destination']);

              return Card(
                margin: EdgeInsets.only(bottom: 12),
                color: Color(0xFF2A2A3A),
                child: ExpansionTile(
                  title: Text('Trip #${trip.id.substring(0, 6)}',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    )),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 4),
                      Text('\$${fare.toStringAsFixed(2)} • ${distance.toStringAsFixed(1)} km',
                        style: TextStyle(color: Colors.white70)),
                      SizedBox(height: 4),
                      Text(DateFormat('MMM dd, HH:mm').format(createdAt),
                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                  leading: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getStatusIcon(status), 
                      color: Colors.white, 
                      size: 20,
                    ),
                  ),
                  children: [
                    Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _buildTripDetail('From', origin),
                          _buildTripDetail('To', destination),
                          _buildTripDetail('Payment', 
                            data['paymentMethod']?.toString().toUpperCase() ?? 'CASH'),
                          _buildTripDetail('Status', status.toUpperCase()),
                          _buildTripDetail('Date', 
                            DateFormat('MMM dd, yyyy - HH:mm').format(createdAt)),
                          SizedBox(height: 8),
                          Divider(color: Colors.grey),
                          SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Distance', 
                                style: TextStyle(color: Colors.white70)),
                              Text('${distance.toStringAsFixed(1)} km', 
                                style: TextStyle(color: Colors.white)),
                            ],
                          ),
                          SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Duration', 
                                style: TextStyle(color: Colors.white70)),
                              Text(_formatDuration(data['time'] ?? 0),
                                style: TextStyle(color: Colors.white)),
                            ],
                          ),
                          SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Fare', 
                                style: TextStyle(color: Colors.white70)),
                              Text('\$${fare.toStringAsFixed(2)}', 
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                )),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildTripDetail(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text('$label:', 
              style: TextStyle(color: Colors.white70)),
          ),
          Expanded(
            flex: 3,
            child: Text(value, 
              style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _formatAddress(dynamic address) {
    if (address == null) return 'Unknown';
    if (address is String) return address;
    if (address is Map) {
      return address['address'] ?? address['name'] ?? 'Unknown';
    }
    return 'Unknown';
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'accepted':
        return Colors.green;
      case 'canceled':
      case 'rejected':
        return Colors.red;
      case 'in_progress':
      case 'pending':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'accepted':
        return Icons.check_circle;
      case 'canceled':
      case 'rejected':
        return Icons.cancel;
      case 'in_progress':
      case 'pending':
        return Icons.directions_car;
      default:
        return Icons.help;
    }
  }

  String _formatDuration(int seconds) {
    final duration = Duration(seconds: seconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m';
    } else {
      return 'Less than a minute';
    }
  }
}