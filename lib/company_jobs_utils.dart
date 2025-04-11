import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Utility methods for CompanyJobsPage
class CompanyJobsUtils {
  static String formatDate(dynamic timestamp) {
    if (timestamp is Timestamp) {
      return timestamp.toDate().toString().split(' ')[0];
    } else if (timestamp is String) {
      return timestamp.split(' ')[0];
    }
    return 'Unknown date';
  }

  static Color getStatusColor(String status) {
    switch (status) {
      case 'New':
        return Colors.blue;
      case 'Review':
        return Colors.orange;
      case 'Interview':
        return Colors.purple;
      case 'Rejected':
        return Colors.red;
      case 'Hired':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  static Widget buildStatItem(String value, String label, IconData icon, MaterialColor color) {
    return Column(
      children: [
        Icon(icon, color: color[700], size: 24),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color[800],
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  static Widget buildVerticalDivider() {
    return Container(
      height: 40,
      width: 1,
      color: Colors.grey[300],
    );
  }

  static Widget detailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ', style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}