// internship_details_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class InternshipDetailsPage extends StatefulWidget {
  final String title;
  final String company;
  final String location;
  final String? status;
  final String? dateApplied;
  final String? jobId;
  final String? applicationId;

  InternshipDetailsPage({
    required this.title,
    required this.company,
    required this.location,
    this.status,
    this.dateApplied,
    this.jobId,
    this.applicationId,
  });

  @override
  _InternshipDetailsPageState createState() => _InternshipDetailsPageState();
}

class _InternshipDetailsPageState extends State<InternshipDetailsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  String _status = 'Under Review';
  String _dateApplied = 'Recent';
  bool _isLoading = true;
  Map<String, dynamic> _applicationDetails = {};
  String _companyName = '';

  @override
  void initState() {
    super.initState();
    _status = widget.status ?? 'Under Review';
    _dateApplied = widget.dateApplied ?? 'Recent';
    _companyName = widget.company;
    
    if (widget.applicationId != null) {
      _fetchApplicationDetails();
    } else if (widget.jobId != null && _auth.currentUser != null) {
      _findApplicationByJobId();
    } else {
      _isLoading = false;
    }
    
    // Fetch verified company name
    if (_applicationDetails.containsKey('companyId')) {
      _fetchCompanyName(_applicationDetails['companyId']);
    }
  }

  // Add method to fetch company name
  Future<void> _fetchCompanyName(String companyId) async {
    try {
      final companyDoc = await _firestore
          .collection('companies')
          .doc(companyId)
          .get();
      
      if (companyDoc.exists) {
        final companyData = companyDoc.data() as Map<String, dynamic>;
        if (companyData.containsKey('name')) {
          setState(() {
            _companyName = companyData['name'];
          });
        }
      }
    } catch (e) {
      print('Error fetching company name: $e');
    }
  }

  Future<void> _fetchApplicationDetails() async {
    try {
      final docSnapshot = await _firestore
          .collection('applicants')
          .doc(widget.applicationId)
          .get();
      
      if (docSnapshot.exists) {
        setState(() {
          _applicationDetails = docSnapshot.data() as Map<String, dynamic>;
          _status = _applicationDetails['status'] ?? _status;
          if (_applicationDetails['applicationDate'] != null) {
            _dateApplied = _formatDate(_applicationDetails['applicationDate']);
          }
          _isLoading = false;
        });
        
        // Fetch company name if companyId is available
        if (_applicationDetails.containsKey('companyId')) {
          _fetchCompanyName(_applicationDetails['companyId']);
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error fetching application details: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _findApplicationByJobId() async {
    try {
      final querySnapshot = await _firestore
          .collection('applicants')
          .where('jobId', isEqualTo: widget.jobId)
          .where('userId', isEqualTo: _auth.currentUser!.uid)
          .get();
      
      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        setState(() {
          _applicationDetails = doc.data();
          _status = _applicationDetails['status'] ?? _status;
          if (_applicationDetails['applicationDate'] != null) {
            _dateApplied = _formatDate(_applicationDetails['applicationDate']);
          }
          _isLoading = false;
        });
        
        // Fetch company name if companyId is available
        if (_applicationDetails.containsKey('companyId')) {
          _fetchCompanyName(_applicationDetails['companyId']);
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error finding application: $e');
      setState(() => _isLoading = false);
    }
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
      body: _isLoading 
          ? Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 200,
                  pinned: true,
                  flexibleSpace: FlexibleSpaceBar(
                    title: Text(
                      widget.company,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.5),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    background: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Colors.indigo[400]!, Colors.indigo[800]!],
                        ),
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            right: 30,
                            bottom: 60,
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 10,
                                    offset: Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.business,
                                  size: 50,
                                  color: Colors.indigo[800],
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 30,
                            bottom: 60,
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 8,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    size: 16,
                                    color: Colors.indigo[800],
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    widget.location,
                                    style: TextStyle(
                                      color: Colors.indigo[800],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Position Title Card
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.title,
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.indigo[800],
                                  ),
                                ),
                                SizedBox(height: 16),
                                Row(
                                  children: [
                                    _buildInfoItem(Icons.location_on, widget.location),
                                    SizedBox(width: 24),
                                    _buildInfoItem(Icons.calendar_today, 'Applied: $_dateApplied'),
                                  ],
                                ),
                                SizedBox(height: 16),
                                // Use StreamBuilder for real-time status updates
                                StreamBuilder<DocumentSnapshot>(
                                  stream: widget.applicationId != null
                                      ? _firestore.collection('applicants').doc(widget.applicationId).snapshots()
                                      : null,
                                  builder: (context, snapshot) {
                                    String currentStatus = _status;
                                    int? stipendAmount;
                                    
                                    if (snapshot.hasData && snapshot.data!.exists) {
                                      final data = snapshot.data!.data() as Map<String, dynamic>;
                                      currentStatus = data['status'] ?? _status;
                                      stipendAmount = data['stipend'];
                                    }
                                    
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _buildStatusBadge(currentStatus),
                                        
                                        // Show stipend if hired and stipend is provided
                                        if (currentStatus == 'Hired' && stipendAmount != null)
                                          Padding(
                                            padding: EdgeInsets.only(top: 16),
                                            child: Container(
                                              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                              decoration: BoxDecoration(
                                                color: Colors.teal.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(12),
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
                                                    size: 20,
                                                    color: Colors.teal,
                                                  ),
                                                  SizedBox(width: 8),
                                                  Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        'Monthly Stipend',
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          color: Colors.teal[700],
                                                        ),
                                                      ),
                                                      Text(
                                                        '₹${stipendAmount.toString()}',
                                                        style: TextStyle(
                                                          fontSize: 18,
                                                          fontWeight: FontWeight.bold,
                                                          color: Colors.teal,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        SizedBox(height: 24),
                        
                        // Application Timeline Card
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Application Timeline',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.indigo[800],
                                  ),
                                ),
                                SizedBox(height: 16),
                                _buildTimelineItem(
                                  'Application Submitted',
                                  _dateApplied,
                                  Icons.send,
                                  Colors.green,
                                  true,
                                ),
                                _buildTimelineItem(
                                  'Application Reviewed',
                                  'Feb 28, 2025',
                                  Icons.visibility,
                                  Colors.blue,
                                  true,
                                ),
                                _buildTimelineItem(
                                  'Interview Scheduled',
                                  'Mar 5, 2025',
                                  Icons.event,
                                  Colors.amber,
                                  false,
                                ),
                                _buildTimelineItem(
                                  'Decision',
                                  'Pending',
                                  Icons.check_circle,
                                  Colors.grey,
                                  false,
                                  isLast: true,
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        SizedBox(height: 24),
                        
                        // Job Description Card
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Position Description',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.indigo[800],
                                  ),
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'We are seeking a talented and motivated ${widget.title.toLowerCase()} to join our team. This position offers an excellent opportunity to gain hands-on experience in a fast-paced, innovative environment. The ideal candidate will collaborate with experienced professionals and contribute to meaningful projects.',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[800],
                                    height: 1.5,
                                  ),
                                ),
                                SizedBox(height: 24),
                                Text(
                                  'Responsibilities',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.indigo[700],
                                  ),
                                ),
                                SizedBox(height: 8),
                                _buildBulletItem('Assist in the development of innovative solutions'),
                                _buildBulletItem('Collaborate with cross-functional teams'),
                                _buildBulletItem('Conduct research and analyze data'),
                                _buildBulletItem('Participate in team meetings and brainstorming sessions'),
                                SizedBox(height: 24),
                                Text(
                                  'Requirements',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.indigo[700],
                                  ),
                                ),
                                SizedBox(height: 8),
                                _buildBulletItem('Currently enrolled in a relevant degree program'),
                                _buildBulletItem('Strong analytical and problem-solving skills'),
                                _buildBulletItem('Excellent communication skills'),
                                _buildBulletItem('Proficiency in relevant software or programming languages'),
                              ],
                            ),
                          ),
                        ),
                        
                        SizedBox(height: 24),
                        
                        // Company Info Card
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'About ${widget.company}',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.indigo[800],
                                  ),
                                ),
                                SizedBox(height: 16),
                                Text(
                                  '${widget.company} is a leading organization in its field, known for innovation and excellence. With a strong focus on professional development, we provide interns with meaningful experiences that contribute to their growth and career advancement.',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[800],
                                    height: 1.5,
                                  ),
                                ),
                                SizedBox(height: 16),
                                Row(
                                  children: [
                                    _buildInfoItem(Icons.public, 'company-website.com'),
                                    SizedBox(width: 24),
                                    _buildInfoItem(Icons.people, '501-1000 employees'),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        SizedBox(height: 80), // Space for the FAB
                      ],
                    ),
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Contact recruiter action')),
          );
        },
        backgroundColor: Colors.indigo,
        icon: Icon(Icons.message),
        label: Text('Contact Recruiter'),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: Colors.grey[600],
        ),
        SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    final Color statusColor = _getStatusColor(status);
    final IconData statusIcon = _getStatusIcon(status);
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: statusColor,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            statusIcon,
            size: 16,
            color: statusColor,
          ),
          SizedBox(width: 8),
          Text(
            status,
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // Update the timeline to include stipend information if hired
  Widget _buildTimelineItem(
    String title,
    String date,
    IconData icon,
    Color color,
    bool completed, {
    bool isLast = false,
  }) {
    // Check if this is the decision step and the user has been hired with stipend
    bool isHiredWithStipend = title == 'Decision' && 
                             _status == 'Hired' && 
                             _applicationDetails.containsKey('stipend');
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: isHiredWithStipend ? Colors.teal : (completed ? color : Colors.grey[300]),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isHiredWithStipend ? Icons.check_circle : icon,
                color: Colors.white,
                size: 16,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 40,
                color: completed ? color.withOpacity(0.5) : Colors.grey[300],
              ),
          ],
        ),
        SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isHiredWithStipend ? 'Hired' : title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isHiredWithStipend ? Colors.teal : (completed ? Colors.grey[800] : Colors.grey[600]),
                ),
              ),
              SizedBox(height: 4),
              Text(
                isHiredWithStipend 
                    ? 'Congratulations! Stipend: ₹${_applicationDetails['stipend']} per month' 
                    : date,
                style: TextStyle(
                  fontSize: 14,
                  color: isHiredWithStipend ? Colors.teal[700] : (completed ? Colors.grey[700] : Colors.grey[500]),
                ),
              ),
              SizedBox(height: isLast ? 0 : 24),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBulletItem(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: EdgeInsets.only(top: 8),
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: Colors.indigo[400],
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[800],
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}