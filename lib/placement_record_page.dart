import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;

class PlacementRecordsPage extends StatefulWidget {
  @override
  _PlacementRecordsPageState createState() => _PlacementRecordsPageState();
}

class _PlacementRecordsPageState extends State<PlacementRecordsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> placementRecords = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _filterBy = 'All'; // Default filter

  // Colors for company cards
  final List<Color> companyColors = [
    Color(0xFFE8F5E9),
    Color(0xFFE3F2FD),
    Color(0xFFFFF8E1),
    Color(0xFFE0F2F1),
    Color(0xFFF3E5F5),
  ];

  @override
  void initState() {
    super.initState();
    fetchPlacementRecords();
  }

  Future<void> fetchPlacementRecords() async {
    setState(() => _isLoading = true);
    
    try {
      // Fetch companies that have hired students
      final querySnapshot = await _firestore
          .collection('applicants')
          .where('status', isEqualTo: 'Hired')
          .get();
      
      // Group by company
      Map<String, Map<String, dynamic>> companiesMap = {};
      
      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final companyId = data['companyId'] ?? 'unknown';
        final companyName = data['companyName'] ?? 'Unknown Company';
        final stipend = data['stipend'] ?? 0;
        
        if (!companiesMap.containsKey(companyId)) {
          // Fetch company details if needed
          String verifiedCompanyName = companyName;
          try {
            final companyDoc = await _firestore
                .collection('companies')
                .doc(companyId)
                .get();
            
            if (companyDoc.exists) {
              final companyData = companyDoc.data() as Map<String, dynamic>;
              if (companyData.containsKey('name')) {
                verifiedCompanyName = companyData['name'];
              }
            }
          } catch (e) {
            print('Error fetching company details: $e');
          }
          
          companiesMap[companyId] = {
            'company': verifiedCompanyName,
            'image': 'https://via.placeholder.com/150',
            'studentsPlaced': 0,
            'stipends': <int>[],
            'color': companyColors[math.Random().nextInt(companyColors.length)],
          };
        }
        
        companiesMap[companyId]!['studentsPlaced'] = 
            (companiesMap[companyId]!['studentsPlaced'] as int) + 1;
        
        if (stipend is int && stipend > 0) {
          companiesMap[companyId]!['stipends'].add(stipend);
        }
      }
      
      // Calculate average and highest packages
      placementRecords = companiesMap.values.map((company) {
        final stipends = company['stipends'] as List<int>;
        final avgStipend = stipends.isNotEmpty 
            ? stipends.reduce((a, b) => a + b) / stipends.length 
            : 0;
        final highestStipend = stipends.isNotEmpty 
            ? stipends.reduce((a, b) => a > b ? a : b) 
            : 0;
        
        return {
          'company': company['company'],
          'image': company['image'],
          'studentsPlaced': company['studentsPlaced'],
          'averagePackage': '${(avgStipend / 1000).toStringAsFixed(1)}K',
          'highestPackage': '${(highestStipend / 1000).toStringAsFixed(1)}K',
          'color': company['color'],
        };
      }).toList();
      
      // Sort by number of students placed (descending)
      placementRecords.sort((a, b) => 
          (b['studentsPlaced'] as int).compareTo(a['studentsPlaced'] as int));
      
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error fetching placement records: $e';
      });
    }
  }

  void _applyFilter(String filter) {
    setState(() {
      _filterBy = filter;
      
      // Apply sorting based on filter
      switch (filter) {
        case 'Students':
          placementRecords.sort((a, b) => 
              (b['studentsPlaced'] as int).compareTo(a['studentsPlaced'] as int));
          break;
        case 'Package':
          placementRecords.sort((a, b) {
            final aValue = double.parse((a['highestPackage'] as String).replaceAll('K', ''));
            final bValue = double.parse((b['highestPackage'] as String).replaceAll('K', ''));
            return bValue.compareTo(aValue);
          });
          break;
        case 'Alphabetical':
          placementRecords.sort((a, b) => 
              (a['company'] as String).compareTo(b['company'] as String));
          break;
        default:
          // Default sorting by students placed
          placementRecords.sort((a, b) => 
              (b['studentsPlaced'] as int).compareTo(a['studentsPlaced'] as int));
      }
    });
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Filter By'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildFilterOption('All Companies', 'All'),
            _buildFilterOption('Most Students', 'Students'),
            _buildFilterOption('Highest Package', 'Package'),
            _buildFilterOption('Company Name', 'Alphabetical'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterOption(String label, String value) {
    return ListTile(
      title: Text(label),
      leading: Radio<String>(
        value: value,
        groupValue: _filterBy,
        onChanged: (String? newValue) {
          Navigator.pop(context);
          if (newValue != null) {
            _applyFilter(newValue);
          }
        },
      ),
    );
  }

  void _showCompanyDetails(Map<String, dynamic> company) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: company['color'],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Image.network(
                    company['image'],
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        Icons.business,
                        size: 30,
                        color: Colors.grey,
                      );
                    },
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Text(
                    company['company'],
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 24),
            Text(
              'Placement Statistics',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.indigo,
              ),
            ),
            SizedBox(height: 16),
            _buildDetailCard(
              'Students Placed',
              company['studentsPlaced'].toString(),
              Icons.people,
            ),
            SizedBox(height: 12),
            _buildDetailCard(
              'Average Stipend',
              company['averagePackage'],
              Icons.attach_money,
            ),
            SizedBox(height: 12),
            _buildDetailCard(
              'Highest Stipend',
              company['highestPackage'],
              Icons.trending_up,
            ),
            SizedBox(height: 24),
            Text(
              'Recent Placements',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.indigo,
              ),
            ),
            SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<QuerySnapshot>(
                future: _firestore
                    .collection('applicants')
                    .where('status', isEqualTo: 'Hired')
                    .where('companyName', isEqualTo: company['company'])
                    .limit(5)
                    .get(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }
                  
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Text('No recent placement details available'),
                    );
                  }
                  
                  return ListView.builder(
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      final doc = snapshot.data!.docs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      
                      return ListTile(
                        leading: CircleAvatar(
                          child: Text(
                            data['name']?.substring(0, 1) ?? 'S',
                            style: TextStyle(color: Colors.white),
                          ),
                          backgroundColor: Colors.indigo,
                        ),
                        title: Text(data['name'] ?? 'Student'),
                        subtitle: Text(data['university'] ?? 'University'),
                        trailing: Text(
                          '₹${data['stipend'] ?? 0}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.teal,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailCard(String label, String value, IconData icon) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.indigo.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: Colors.indigo,
            ),
          ),
          SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Calculate total students placed
    final totalStudentsPlaced = _isLoading ? 0 : placementRecords.fold<int>(
        0, (sum, record) => sum + record['studentsPlaced'] as int);
    
    // Find highest package
    String highestPackage = '0K';
    if (!_isLoading && placementRecords.isNotEmpty) {
      highestPackage = placementRecords
          .map((record) => record['highestPackage'] as String)
          .reduce((a, b) {
            final aValue = double.parse(a.replaceAll('K', ''));
            final bValue = double.parse(b.replaceAll('K', ''));
            return aValue > bValue ? a : b;
          });
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Placement Records'),
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.indigo,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      body: _isLoading 
          ? Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!, style: TextStyle(color: Colors.red)))
              : Column(
                  children: [
                    // Summary Card
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Placement Summary',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildSummaryItem(
                                icon: Icons.business,
                                title: 'Companies',
                                value: placementRecords.length.toString(),
                              ),
                              _buildSummaryItem(
                                icon: Icons.people,
                                title: 'Students Placed',
                                value: totalStudentsPlaced.toString(),
                              ),
                              _buildSummaryItem(
                                icon: Icons.trending_up,
                                title: 'Highest Package',
                                value: highestPackage,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    // Title for records
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          Text(
                            'Company Details',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: _showFilterDialog,
                            icon: const Icon(Icons.filter_list),
                            label: Text(_filterBy == 'All' ? 'Filter' : 'Filter: $_filterBy'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.indigo,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // List of companies
                    Expanded(
                      child: placementRecords.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.business, size: 64, color: Colors.grey),
                                  SizedBox(height: 16),
                                  Text(
                                    'No placement records found',
                                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: placementRecords.length,
                              itemBuilder: (context, index) {
                                final record = placementRecords[index];
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  decoration: BoxDecoration(
                                    color: record['color'],
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Row(
                                          children: [
                                            // Company Logo with container
                                            Container(
                                              width: 70,
                                              height: 70,
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius: BorderRadius.circular(12),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black.withOpacity(0.05),
                                                    blurRadius: 4,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                              child: Image.network(
                                                record['image'],
                                                errorBuilder: (context, error, stackTrace) {
                                                  return const Icon(
                                                    Icons.business,
                                                    size: 40,
                                                    color: Colors.grey,
                                                  );
                                                },
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            // Company Details
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    record['company'],
                                                    style: const TextStyle(
                                                      fontSize: 20,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  _buildDetailRow(
                                                    Icons.people,
                                                    'Students Placed',
                                                    record['studentsPlaced'].toString(),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  _buildDetailRow(
                                                    Icons.money,
                                                    'Average Package',
                                                    record['averagePackage'],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            // View more icon
                                            IconButton(
                                              icon: const Icon(Icons.arrow_forward_ios, size: 16),
                                              onPressed: () => _showCompanyDetails(record),
                                              color: Colors.grey[700],
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Stats container
                                      Container(
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.7),
                                          borderRadius: const BorderRadius.only(
                                            bottomLeft: Radius.circular(16),
                                            bottomRight: Radius.circular(16),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                          children: [
                                            _buildStat('Highest', record['highestPackage']),
                                            _buildDivider(),
                                            _buildStat('Students', '${record['studentsPlaced']}'),
                                            _buildDivider(),
                                            _buildStat('Roles', '${math.Random().nextInt(5) + 1}'),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.indigo,
        child: const Icon(Icons.refresh),
        onPressed: fetchPlacementRecords,
        tooltip: 'Refresh Data',
      ),
    );
  }

  Widget _buildSummaryItem({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.indigo.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: Colors.indigo,
            size: 24,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.indigo,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: Colors.grey[600],
        ),
        const SizedBox(width: 4),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 2),
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

  Widget _buildDivider() {
    return Container(
      height: 24,
      width: 1,
      color: Colors.grey[300],
    );
  }
}