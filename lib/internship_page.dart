// internship_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
 import 'internship_details_page.dart';

class InternshipPage extends StatefulWidget {
  @override
  _InternshipPageState createState() => _InternshipPageState();
}

class _InternshipPageState extends State<InternshipPage> {
  // Firebase instances
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Statistics counters
  int totalApplications = 0;
  int interviewsScheduled = 0;
  int activeApplications = 0;

  // Helper method to get status color
  Color _getStatusColor(String status) {
    switch (status) {
      case 'Under Review':
      case 'Review':
        return Colors.amber;
      case 'Interview Scheduled':
      case 'Interview':
        return Colors.green;
      case 'Application Sent':
      case 'New':
        return Colors.blue;
      case 'Rejected':
        return Colors.red;
      case 'Hired':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  // Helper method to get status icon
  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'Under Review':
      case 'Review':
        return Icons.hourglass_empty;
      case 'Interview Scheduled':
      case 'Interview':
        return Icons.event_available;
      case 'Application Sent':
      case 'New':
        return Icons.send;
      case 'Rejected':
        return Icons.cancel_outlined;
      case 'Hired':
        return Icons.check_circle;
      default:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text('My Applications'),
        centerTitle: true,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.indigo[400]!, Colors.indigo[800]!],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.filter_list),
            onPressed: () {
              // Placeholder for filtering functionality
            },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats Card
          StreamBuilder<QuerySnapshot>(
            stream: _auth.currentUser != null 
                ? _firestore
                    .collection('applicants')
                    .where('userId', isEqualTo: _auth.currentUser!.uid)
                    .snapshots()
                : Stream.empty(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildLoadingStatsCard();
              }
              
              if (snapshot.hasError) {
                return _buildErrorStatsCard();
              }
              
              if (snapshot.hasData) {
                // Calculate statistics
                final applications = snapshot.data!.docs;
                totalApplications = applications.length;
                interviewsScheduled = applications.where((doc) => 
                  doc['status'] == 'Interview Scheduled').length;
                activeApplications = applications.where((doc) => 
                  doc['status'] == 'Under Review' || doc['status'] == 'Application Sent' || doc['status'] == 'New').length;
                
                return _buildStatsCard();
              }
              
              return _buildEmptyStatsCard();
            }
          ),
          
          // Section title
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Your Applications',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.indigo[800],
              ),
            ),
          ),
          
          // List of applications
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _auth.currentUser != null 
                  ? _firestore
                      .collection('applicants')
                      .where('userId', isEqualTo: _auth.currentUser!.uid)
                      .snapshots()
                  : Stream.empty(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}', 
                      style: TextStyle(color: Colors.red)),
                  );
                }
                
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.work_off, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('No applications yet',
                          style: TextStyle(fontSize: 18, color: Colors.grey[600])),
                        SizedBox(height: 8),
                        Text('Start applying to internships',
                          style: TextStyle(fontSize: 14, color: Colors.grey)),
                      ],
                    ),
                  );
                }
                
                final applications = snapshot.data!.docs;
                
                return ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  itemCount: applications.length,
                  itemBuilder: (context, index) {
                    final application = applications[index].data() as Map<String, dynamic>;
                    final applicationId = applications[index].id;
                    
                    // Fetch job details for this application
                    return FutureBuilder<DocumentSnapshot>(
                      future: _firestore.collection('postedJobs').doc(application['jobId']).get(),
                      builder: (context, jobSnapshot) {
                        if (jobSnapshot.connectionState == ConnectionState.waiting) {
                          return Card(
                            margin: EdgeInsets.only(bottom: 16),
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: CircularProgressIndicator()),
                            ),
                          );
                        }
                        
                        Map<String, dynamic> position = {};
                        
                        if (jobSnapshot.hasData && jobSnapshot.data!.exists) {
                          position = jobSnapshot.data!.data() as Map<String, dynamic>;
                          position['id'] = jobSnapshot.data!.id;
                          position['title'] = position['title'] ?? 'Unknown Position';
                          position['company'] = position['companyName'] ?? 'Unknown Company';
                          position['location'] = position['location'] ?? 'Unknown Location';
                          position['dateApplied'] = _formatDate(application['applicationDate']);
                          position['status'] = application['status'] ?? 'Application Sent';
                          
                          // Default color
                          position['color'] = Colors.blue;
                        } else {
                          // Fallback if job doesn't exist anymore
                          position = {
                            'title': application['name'] ?? 'Job Application',
                            'company': 'Company',
                            'location': application['university'] ?? 'Unknown',
                            'dateApplied': _formatDate(application['applicationDate']),
                            'status': application['status'] ?? 'Application Sent',
                            'color': Colors.grey,
                          };
                        }
                        
                        return Card(
                          margin: EdgeInsets.only(bottom: 16),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => InternshipDetailsPage(
                                    title: position['title'],
                                    company: position['company'],
                                    location: position['location'],
                                    status: application['status'],
                                    dateApplied: position['dateApplied'],
                                    jobId: position['id'],
                                    applicationId: applicationId,
                                  ),
                                ),
                              );
                            },
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      // Company logo placeholder
                                      Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          color: position['color'].withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                          Icons.business,
                                          color: position['color'],
                                          size: 30,
                                        ),
                                      ),
                                      SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              position['title'],
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            SizedBox(height: 4),
                                            Text(
                                              position['company'],
                                              style: TextStyle(
                                                fontSize: 16,
                                                color: Colors.grey[700],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.location_on_outlined,
                                        size: 16,
                                        color: Colors.grey[600],
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        position['location'],
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 14,
                                        ),
                                      ),
                                      SizedBox(width: 16),
                                      Icon(
                                        Icons.calendar_today_outlined,
                                        size: 16,
                                        color: Colors.grey[600],
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'Applied: ${position['dateApplied']}',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Container(
                                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: _getStatusColor(position['status']).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(
                                            color: _getStatusColor(position['status']),
                                            width: 1,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              _getStatusIcon(position['status']),
                                              size: 16,
                                              color: _getStatusColor(position['status']),
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              position['status'],
                                              style: TextStyle(
                                                color: _getStatusColor(position['status']),
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      
                                      // Show stipend if hired and stipend is available
                                      if (application['status'] == 'Hired' && application['stipend'] != null)
                                        Expanded(
                                          child: Container(
                                            margin: EdgeInsets.only(left: 8),
                                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: Colors.teal.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(20),
                                              border: Border.all(
                                                color: Colors.teal,
                                                width: 1,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.currency_rupee,
                                                  size: 16,
                                                  color: Colors.teal,
                                                ),
                                                SizedBox(width: 4),
                                                Text(
                                                  '${application['stipend']} per month',
                                                  style: TextStyle(
                                                    color: Colors.teal,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
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
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.indigo,
        onPressed: () {
          // Navigate to add application page
          // You can implement this later
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Add application manually')),
          );
        },
        child: Icon(Icons.add),
        tooltip: 'Add Application',
      ),
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      return '${date.day}/${date.month}/${date.year}';
    } else if (timestamp is String) {
      return timestamp.split(' ')[0];
    }
    return 'Recent';
  }

  Widget _buildStatsCard() {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo[300]!, Colors.indigo[500]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatColumn('$totalApplications', 'Total\nApplications'),
          _buildDivider(),
          _buildStatColumn('$interviewsScheduled', 'Interviews\nScheduled'),
          _buildDivider(),
          _buildStatColumn('$activeApplications', 'Active\nApplications'),
        ],
      ),
    );
  }

  Widget _buildLoadingStatsCard() {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo[300]!, Colors.indigo[500]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );
  }

  Widget _buildErrorStatsCard() {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red[100],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text('Error loading data',
          style: TextStyle(color: Colors.red[800])),
      ),
    );
  }

  Widget _buildEmptyStatsCard() {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo[300]!, Colors.indigo[500]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatColumn('0', 'Total\nApplications'),
          _buildDivider(),
          _buildStatColumn('0', 'Interviews\nScheduled'),
          _buildDivider(),
          _buildStatColumn('0', 'Active\nApplications'),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 40,
      width: 1,
      color: Colors.white.withOpacity(0.3),
    );
  }
}