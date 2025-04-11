import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class JobListingPage extends StatefulWidget {
  const JobListingPage({Key? key}) : super(key: key);

  @override
  _JobListingPageState createState() => _JobListingPageState();
}

class _JobListingPageState extends State<JobListingPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  List<Map<String, dynamic>> availableJobs = [];
  List<String> appliedJobIds = [];
  bool _isLoading = true;
  String? _errorMessage;
  String? _searchQuery;
  String? _selectedFilter;

  final List<String> filterOptions = ['All', 'Full-time', 'Part-time', 'Internship', 'Remote'];

  @override
  void initState() {
    super.initState();
    fetchJobs();
    fetchUserApplications();
  }

  Future<void> fetchJobs() async {
    setState(() => _isLoading = true);
    
    try {
      // Fetch active jobs
      final querySnapshot = await _firestore
          .collection('postedJobs')
          .where('status', isEqualTo: 'Active')
          .get();
      
      availableJobs = querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
      
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error fetching jobs: $e';
      });
    }
  }

  Future<void> fetchUserApplications() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final applicationsSnapshot = await _firestore
            .collection('applicants')
            .where('userId', isEqualTo: user.uid)
            .get();
        
        setState(() {
          appliedJobIds = applicationsSnapshot.docs
              .map((doc) => (doc.data() as Map<String, dynamic>)['jobId'] as String)
              .toList();
        });
      }
    } catch (e) {
      print('Error fetching user applications: $e');
    }
  }

  List<Map<String, dynamic>> getFilteredJobs() {
    List<Map<String, dynamic>> filteredJobs = List.from(availableJobs);
    
    // Apply search filter
    if (_searchQuery != null && _searchQuery!.isNotEmpty) {
      filteredJobs = filteredJobs.where((job) => 
        job['title'].toString().toLowerCase().contains(_searchQuery!.toLowerCase()) ||
        job['location'].toString().toLowerCase().contains(_searchQuery!.toLowerCase()) ||
        (job['description'] != null && job['description'].toString().toLowerCase().contains(_searchQuery!.toLowerCase()))
      ).toList();
    }
    
    // Apply type filter
    if (_selectedFilter != null && _selectedFilter != 'All') {
      filteredJobs = filteredJobs.where((job) => 
        job['type'] == _selectedFilter
      ).toList();
    }
    
    return filteredJobs;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text('Job Listings'),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.blue[700]!, Colors.blue[900]!],
            ),
          ),
        ),
      ),
      body: _isLoading 
          ? Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
              : Column(
                  children: [
                    _buildSearchFilter(),
                    Expanded(child: _buildJobsList()),
                  ],
                ),
    );
  }

  Widget _buildSearchFilter() {
    return Container(
      padding: EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: 'Search jobs',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
          SizedBox(height: 12),
          Container(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: filterOptions.map((filter) {
                final isSelected = _selectedFilter == filter || (_selectedFilter == null && filter == 'All');
                return Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(filter),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedFilter = selected ? filter : null;
                      });
                    },
                    backgroundColor: Colors.grey[200],
                    selectedColor: Colors.blue[100],
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.blue[800] : Colors.black,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJobsList() {
    final filteredJobs = getFilteredJobs();
    
    if (filteredJobs.isEmpty) {
      return Center(child: Text('No jobs found matching your criteria'));
    }
    
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: filteredJobs.length,
      itemBuilder: (context, index) {
        final job = filteredJobs[index];
        final hasApplied = appliedJobIds.contains(job['id']);
        
        // Find company details (you'd want to fetch this in a real app)
        final companyName = job['companyName'] ?? 'Company Name';
        final companyLogo = job['companyLogo'];
        
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
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: companyLogo != null
                            ? Image.network(companyLogo)
                            : Center(
                                child: Text(
                                  companyName[0],
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue[800],
                                  ),
                                ),
                              ),
                      ),
                      SizedBox(width: 16),
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
                            SizedBox(height: 4),
                            Text(
                              companyName,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.bookmark_border,
                        color: Colors.grey[600],
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      _buildJobInfoChip(job['type'], Icons.work),
                      SizedBox(width: 8),
                      _buildJobInfoChip(job['location'], Icons.location_on),
                      SizedBox(width: 8),
                      if (job['salary'] != null)
                        _buildJobInfoChip('\$${job['salary']}', Icons.attach_money),
                    ],
                  ),
                  SizedBox(height: 16),
                  if (job['description'] != null && job['description'].toString().isNotEmpty)
                    Text(
                      job['description'].toString().length > 100
                          ? '${job['description'].toString().substring(0, 100)}...'
                          : job['description'],
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Posted: ${_formatDate(job['postedDate'])}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: hasApplied ? null : () => _applyForJob(job),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: hasApplied ? Colors.grey[300] : Colors.blue[700],
                          foregroundColor: hasApplied ? Colors.grey[700] : Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        ),
                        child: Text(hasApplied ? 'Applied' : 'Apply Now'),
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
  }

  Widget _buildJobInfoChip(String label, IconData icon) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: Colors.blue[800],
          ),
          SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.blue[800],
            ),
          ),
        ],
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

  void _showJobDetailsDialog(BuildContext context, Map<String, dynamic> job) {
    final hasApplied = appliedJobIds.contains(job['id']);
    
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
                Text(
                  job['companyName'] ?? 'Company Name',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[700],
                  ),
                ),
                SizedBox(height: 16),
                _detailItem('Type', job['type']),
                _detailItem('Location', job['location']),
                if (job['salary'] != null)
                  _detailItem('Salary', '\$${job['salary']}'),
                _detailItem('Posted Date', _formatDate(job['postedDate'])),
                SizedBox(height: 16),
                Text(
                  'Job Description',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  job['description'] ?? 'No description provided',
                  style: TextStyle(
                    fontSize: 14,
                  ),
                ),
                if (job['requirements'] != null) ...[
                  SizedBox(height: 16),
                  Text(
                    'Requirements',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    job['requirements'],
                    style: TextStyle(
                      fontSize: 14,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Close'),
            ),
            ElevatedButton(
              onPressed: hasApplied ? null : () {
                Navigator.of(context).pop();
                _applyForJob(job);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: hasApplied ? Colors.grey[300] : Colors.blue[700],
                foregroundColor: hasApplied ? Colors.grey[700] : Colors.white,
              ),
              child: Text(hasApplied ? 'Already Applied' : 'Apply Now'),
            ),
          ],
        );
      },
    );
  }

  Widget _detailItem(String label, String value) {
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

  void _applyForJob(Map<String, dynamic> job) {
    final user = _auth.currentUser;
    if (user == null) {
      _showLoginPrompt();
      return;
    }
    
    _showApplicationForm(job);
  }

  void _showLoginPrompt() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Sign In Required'),
        content: Text('You need to sign in to apply for jobs.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Navigate to login page
              // Navigator.of(context).push(MaterialPageRoute(builder: (_) => LoginPage()));
            },
            child: Text('Sign In'),
          ),
        ],
      ),
    );
  }

  void _showApplicationForm(Map<String, dynamic> job) {
    final _formKey = GlobalKey<FormState>();
    final _nameController = TextEditingController();
    final _emailController = TextEditingController();
    final _phoneController = TextEditingController();
    final _universityController = TextEditingController();
    final _experienceController = TextEditingController();
    final _coverLetterController = TextEditingController();
    
    // Pre-fill with user data if available
    final user = _auth.currentUser;
    if (user != null) {
      _emailController.text = user.email ?? '';
      _nameController.text = user.displayName ?? '';
      
      // You could also fetch additional user data from Firestore here
    }
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Apply for ${job['title']}'),
          content: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(labelText: 'Full Name *'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your name';
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(labelText: 'Email *'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!value.contains('@')) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: _phoneController,
                    decoration: InputDecoration(labelText: 'Phone Number'),
                    keyboardType: TextInputType.phone,
                  ),
                  TextFormField(
                    controller: _universityController,
                    decoration: InputDecoration(labelText: 'University/College'),
                  ),
                  TextFormField(
                    controller: _experienceController,
                    decoration: InputDecoration(labelText: 'Years of Experience'),
                    keyboardType: TextInputType.number,
                  ),
                  TextFormField(
                    controller: _coverLetterController,
                    decoration: InputDecoration(
                      labelText: 'Cover Letter / Additional Information',
                      alignLabelWithHint: true,
                    ),
                    maxLines: 5,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Resume/CV Upload option would be here',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.grey[600],
                    ),
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
              onPressed: () => _submitApplication(
                context,
                _formKey,
                job,
                {
                  'name': _nameController.text,
                  'email': _emailController.text,
                  'phone': _phoneController.text,
                  'university': _universityController.text,
                  'experience': _experienceController.text,
                  'coverLetter': _coverLetterController.text,
                },
              ),
              child: Text('Submit Application'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _submitApplication(
    BuildContext context,
    GlobalKey<FormState> formKey,
    Map<String, dynamic> job,
    Map<String, String> applicationData,
  ) async {
    if (formKey.currentState!.validate()) {
      try {
        final user = _auth.currentUser;
        if (user == null) {
          Navigator.of(context).pop();
          _showLoginPrompt();
          return;
        }
        
        // Prepare application data
        final application = {
          'jobId': job['id'],
          'companyId': job['companyId'],
          'userId': user.uid,
          'status': 'New',
          'applicationDate': Timestamp.now(),
          ...applicationData,
        };
        
        // Submit to Firestore
        await _firestore.collection('applicants').add(application);
        
        // Update local state
        setState(() {
          appliedJobIds.add(job['id']);
        });
        
        Navigator.of(context).pop();
        _showApplicationSuccessDialog();
      } catch (e) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting application: $e')),
        );
      }
    }
  }

  void _showApplicationSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Application Submitted!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 64,
            ),
            SizedBox(height: 16),
            Text(
              'Your application has been successfully submitted. The employer will review your application and contact you if interested.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }
}