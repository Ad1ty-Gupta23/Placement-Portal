import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'company_jobs_utils.dart';

class CompanyJobsPage extends StatefulWidget {
  final String companyId;
  
  const CompanyJobsPage({Key? key, required this.companyId}) : super(key: key);
  
  @override
  _CompanyJobsPageState createState() => _CompanyJobsPageState();
}

class _CompanyJobsPageState extends State<CompanyJobsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  List<Map<String, dynamic>> postedJobs = [];
  List<Map<String, dynamic>> applicants = [];
  bool _isLoading = true;
  String? _errorMessage;
  String companyName = 'Company Dashboard'; // Default name until loaded

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    fetchCompanyName(); // Fetch company name first
    fetchData();
  }

  // Add method to fetch company name
  Future<void> fetchCompanyName() async {
    try {
      final companyDoc = await _firestore
          .collection('companies')
          .doc(widget.companyId)
          .get();
      
      if (companyDoc.exists) {
        final data = companyDoc.data() as Map<String, dynamic>;
        if (data.containsKey('name')) {
          setState(() {
            companyName = data['name'];
          });
        }
      }
    } catch (e) {
      print('Error fetching company name: $e');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> fetchData() async {
    setState(() => _isLoading = true);
    
    try {
      // Fetch company's posted jobs
      final querySnapshot = await _firestore
          .collection('postedJobs')
          .where('companyId', isEqualTo: widget.companyId)
          .get();
      
      postedJobs = querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
      
      // Fetch applicants for this company's jobs
      final jobIds = postedJobs.map((job) => job['id']).toList();
      
      if (jobIds.isNotEmpty) {
        final applicantsSnapshot = await _firestore
            .collection('applicants')
            .where('jobId', whereIn: jobIds)
            .get();
        
        applicants = applicantsSnapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'id': doc.id,
            ...data,
          };
        }).toList();
      }
      
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error fetching data: $e';
      });
    }
  }

  // Job stats summary
  Map<String, dynamic> _getJobStats() {
    final activeJobs = postedJobs.where((job) => job['status'] == 'Active').length;
    final totalApplications = applicants.length;
    final interviews = applicants.where((app) => app['status'] == 'Interview').length;
    
    return {
      'activeJobs': activeJobs.toString(),
      'totalApplications': totalApplications.toString(),
      'interviews': interviews.toString(),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(companyName), // Use the fetched company name here
        centerTitle: true,
        elevation: 0,
        actions: [
          // Add logout button
          IconButton(
            icon: Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () => _showLogoutConfirmation(context),
          ),
        ],
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.blue[700]!, Colors.blue[900]!],
            ),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          tabs: [
            Tab(text: 'POSTED JOBS', icon: Icon(Icons.work)),
            Tab(text: 'APPLICATIONS', icon: Icon(Icons.people)),
          ],
        ),
      ),
      body: _isLoading 
          ? Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildPostedJobsTab(),
                    _buildApplicationsTab(),
                  ],
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showAddJobDialog(context);
        },
        backgroundColor: Colors.blue[700],
        child: Icon(Icons.add),
        tooltip: 'Post New Job',
      ),
    );
  }

  Widget _buildPostedJobsTab() {
    final stats = _getJobStats();
    
    return Column(
      children: [
        // Stats Overview
        Container(
          margin: EdgeInsets.all(16),
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              CompanyJobsUtils.buildStatItem(stats['activeJobs'], 'Active Jobs', Icons.work, Colors.blue),
              CompanyJobsUtils.buildVerticalDivider(),
              CompanyJobsUtils.buildStatItem(stats['totalApplications'], 'Total Applications', Icons.description, Colors.green),
              CompanyJobsUtils.buildVerticalDivider(),
              CompanyJobsUtils.buildStatItem(stats['interviews'], 'Interviews', Icons.event, Colors.orange),
            ],
          ),
        ),
        
        // Rest of the tab content
        // ... (rest of the method remains the same, just replace _formatDate with CompanyJobsUtils.formatDate)
        
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Posted Positions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[900],
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  // Filter functionality
                },
                icon: Icon(Icons.filter_list, size: 18),
                label: Text('Filter'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.blue[700],
                ),
              ),
            ],
          ),
        ),
        
        Expanded(
          child: postedJobs.isEmpty
              ? Center(child: Text('No jobs posted yet'))
              : ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  itemCount: postedJobs.length,
                  itemBuilder: (context, index) {
                    final job = postedJobs[index];
                    final applicationCount = applicants
                        .where((app) => app['jobId'] == job['id'])
                        .length;
                    
                    return Card(
                      margin: EdgeInsets.only(bottom: 16),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          _showJobDetailsDialog(context, job);
                        },
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          job['title'],
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Container(
                                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: Colors.blue[100],
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                job['type'],
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.blue[800],
                                                ),
                                              ),
                                            ),
                                            SizedBox(width: 8),
                                            Icon(
                                              Icons.location_on,
                                              size: 14,
                                              color: Colors.grey[600],
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              job['location'],
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: job['status'] == 'Active' 
                                          ? Colors.green[100] 
                                          : Colors.grey[300],
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      job['status'],
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: job['status'] == 'Active' 
                                            ? Colors.green[800] 
                                            : Colors.grey[700],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.calendar_today,
                                        size: 14,
                                        color: Colors.grey[600],
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'Posted: ${CompanyJobsUtils.formatDate(job['postedDate'])}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.blue[50],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.person,
                                          size: 14,
                                          color: Colors.blue[800],
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          '$applicationCount Applications',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue[800],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton.icon(
                                    onPressed: () {
                                      _editJobListing(context, job);
                                    },
                                    icon: Icon(Icons.edit, size: 16),
                                    label: Text('Edit'),
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.blue[700],
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  TextButton.icon(
                                    onPressed: () {
                                      _toggleJobStatus(job);
                                    },
                                    icon: Icon(
                                      job['status'] == 'Active' ? Icons.close : Icons.refresh, 
                                      size: 16
                                    ),
                                    label: Text(job['status'] == 'Active' ? 'Close' : 'Reopen'),
                                    style: TextButton.styleFrom(
                                      foregroundColor: job['status'] == 'Active' ? Colors.red : Colors.green,
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
                ),
        ),
      ],
    );
  }

  Widget _buildApplicationsTab() {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(16),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search applicants',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        Expanded(
          child: applicants.isEmpty
              ? Center(child: Text('No applications received yet'))
              : ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  itemCount: applicants.length,
                  itemBuilder: (context, index) {
                    final applicant = applicants[index];
                    // Find job title for this application
                    final jobTitle = postedJobs
                        .firstWhere((job) => job['id'] == applicant['jobId'], 
                                   orElse: () => {'title': 'Unknown Position'})['title'];
                    
                    return Card(
                      margin: EdgeInsets.only(bottom: 12),
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(applicant['name'][0]),
                          backgroundColor: Colors.blue[100],
                        ),
                        title: Text(applicant['name']),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(jobTitle),
                            Text(applicant['university'] ?? 'No university specified'),
                          ],
                        ),
                        trailing: Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: CompanyJobsUtils.getStatusColor(applicant['status']),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            applicant['status'],
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        onTap: () => _showApplicantDetailsDialog(context, applicant),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // Dialog methods
  void _showJobDetailsDialog(BuildContext context, Map<String, dynamic> job) {
    final applicationsForJob = applicants.where((app) => app['jobId'] == job['id']).toList();
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(job['title']),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CompanyJobsUtils.detailItem('Type', job['type']),
                CompanyJobsUtils.detailItem('Location', job['location']),
                CompanyJobsUtils.detailItem('Status', job['status']),
                CompanyJobsUtils.detailItem('Posted Date', CompanyJobsUtils.formatDate(job['postedDate'])),
                CompanyJobsUtils.detailItem('Description', job['description'] ?? 'No description provided'),
                Divider(),
                Text('Applications (${applicationsForJob.length}):', 
                     style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                ...applicationsForJob.map((app) => 
                  Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text('- ${app['name']} (${app['status']})'),
                  )
                ).toList(),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showApplicantDetailsDialog(BuildContext context, Map<String, dynamic> applicant) {
    // Find job that this applicant applied to
    final job = postedJobs.firstWhere(
      (job) => job['id'] == applicant['jobId'],
      orElse: () => {'title': 'Unknown Position'},
    );
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(applicant['name']),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CompanyJobsUtils.detailItem('Applied For', job['title']),
                CompanyJobsUtils.detailItem('Status', applicant['status']),
                CompanyJobsUtils.detailItem('Email', applicant['email'] ?? 'No email provided'),
                CompanyJobsUtils.detailItem('University', applicant['university'] ?? 'No university provided'),
                CompanyJobsUtils.detailItem('Experience', applicant['experience']?.toString() ?? 'Not specified'),
                if (applicant['status'] == 'Hired' && applicant['stipend'] != null)
                  CompanyJobsUtils.detailItem('Stipend', '₹${applicant['stipend']} per month'),
                Divider(),
                Text('Actions:', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () => _updateApplicantStatus(applicant, 'Review'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: Text('Review', style: TextStyle(fontSize: 12)),
                    ),
                    ElevatedButton(
                      onPressed: () => _updateApplicantStatus(applicant, 'Interview'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: Text('Interview', style: TextStyle(fontSize: 12)),
                    ),
                    ElevatedButton(
                      onPressed: () => _updateApplicantStatus(applicant, 'Rejected'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: Text('Reject', style: TextStyle(fontSize: 12)),
                    ),
                    ElevatedButton(
                      onPressed: () => _showHireDialog(context, applicant),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: Text('Hire', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Close'),
            ),
          ],
        );
      },
    );
  }

  // Add job dialog
  void _showAddJobDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    String title = '';
    String type = 'Full-time';
    String location = '';
    String description = '';
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Post New Job'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Company name field (editable)
                  TextFormField(
                    initialValue: companyName,
                    decoration: InputDecoration(
                      labelText: 'Company Name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a company name';
                      }
                      return null;
                    },
                    onChanged: (value) {
                      setState(() {
                        companyName = value;
                      });
                    },
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Job Title', 
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a job title';
                      }
                      return null;
                    },
                    onSaved: (value) => title = value!,
                  ),
                  SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Job Type',
                      border: OutlineInputBorder(),
                    ),
                    value: type,
                    items: ['Full-time', 'Part-time', 'Internship', 'Contract']
                        .map((type) => DropdownMenuItem(
                              value: type,
                              child: Text(type),
                            ))
                        .toList(),
                    onChanged: (value) => type = value!,
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Location',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a location';
                      }
                      return null;
                    },
                    onSaved: (value) => location = value!,
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    maxLines: 5,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a job description';
                      }
                      return null;
                    },
                    onSaved: (value) => description = value!,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  formKey.currentState!.save();
                  Navigator.of(context).pop();
                  _addNewJob(context, formKey, title, type, location, description);
                }
              },
              child: Text('Post Job'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addNewJob(BuildContext context, GlobalKey<FormState> formKey, String title, String type, String location, String description) async {
    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 16),
              Text('Posting job...'),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );
      
      // Ensure we have the latest company name from Firestore
      await fetchCompanyName();
      
      // Add job to Firestore
      await _firestore.collection('postedJobs').add({
        'title': title,
        'type': type,
        'location': location,
        'description': description,
        'status': 'Active',
        'companyId': widget.companyId,
        'companyName': companyName, // Using the fetched company name
        'postedDate': Timestamp.now(),
      });
      
      // Refresh data
      await fetchData();
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Job posted successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error posting job: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Hire dialog
  void _showHireDialog(BuildContext context, Map<String, dynamic> applicant) {
    final TextEditingController stipendController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Hire ${applicant['name']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Please enter the monthly stipend amount:'),
              SizedBox(height: 16),
              TextField(
                controller: stipendController,
                decoration: InputDecoration(
                  labelText: 'Stipend (₹)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.currency_rupee),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final stipendText = stipendController.text.trim();
                if (stipendText.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Please enter a stipend amount')),
                  );
                  return;
                }
                
                final stipend = int.tryParse(stipendText);
                if (stipend == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Please enter a valid number')),
                  );
                  return;
                }
                
                Navigator.of(context).pop();
                _hireApplicant(applicant, stipend);
              },
              child: Text('Confirm Hire'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _hireApplicant(Map<String, dynamic> applicant, int stipend) async {
    try {
      // Update applicant status to Hired and add stipend
      await _firestore
          .collection('applicants')
          .doc(applicant['id'])
          .update({
            'status': 'Hired',
            'stipend': stipend,
            'hiredDate': Timestamp.now(),
          });
      
      // Refresh data
      await fetchData();
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${applicant['name']} has been hired successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error hiring applicant: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Job and applicant update methods
  Future<void> _updateApplicantStatus(Map<String, dynamic> applicant, String status) async {
    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 16),
              Text('Updating status...'),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );
      
      // Update applicant status in Firestore
      await _firestore
          .collection('applicants')
          .doc(applicant['id'])
          .update({
            'status': status,
            'statusUpdatedDate': Timestamp.now(),
          });
      
      // Refresh data
      await fetchData();
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Status updated to $status successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _editJobListing(BuildContext context, Map<String, dynamic> job) {
    // ... (implementation remains the same)
  }

  Future<void> _updateJobListing(BuildContext context, GlobalKey<FormState> formKey, String jobId, String title, String type, String location, String description) async {
    // ... (implementation remains the same)
  }

  Future<void> _toggleJobStatus(Map<String, dynamic> job) async {
    // ... (implementation remains the same)
  }

  // Logout methods
  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Logout'),
          content: Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _logout(context);
              },
              child: Text('Logout'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _logout(BuildContext context) async {
    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 16),
              Text('Logging out...'),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );
      
      // Sign out from Firebase Auth
      await FirebaseAuth.instance.signOut();
      
      // Navigate to welcome page and remove all previous routes
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/welcome',
        (route) => false,
      );
    } catch (e) {
      // Show error message if logout fails
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error logging out: $e')),
      );
    }
  }
}