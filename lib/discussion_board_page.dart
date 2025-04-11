import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DiscussionBoardPage extends StatefulWidget {
  @override
  _DiscussionBoardPageState createState() => _DiscussionBoardPageState();
}

class _DiscussionBoardPageState extends State<DiscussionBoardPage> {
  final TextEditingController _postController = TextEditingController();
  final CollectionReference postsCollection =
      FirebaseFirestore.instance.collection('posts');
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? currentUser;
  String username = '';

  @override
  void initState() {
    super.initState();
    _getCurrentUser();
  }

  void _getCurrentUser() async {
    currentUser = _auth.currentUser;
    
    if (currentUser != null) {
      // First try to get the display name
      if (currentUser!.displayName != null && currentUser!.displayName!.isNotEmpty) {
        setState(() {
          username = currentUser!.displayName!;
        });
      } 
      // If no display name is available, try to get from Firestore users collection
      else {
        try {
          DocumentSnapshot userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser!.uid)
              .get();
          
          if (userDoc.exists) {
            var userData = userDoc.data() as Map<String, dynamic>;
            if (userData['username'] != null) {
              setState(() {
                username = userData['username'];
              });
            } else {
              // Fallback to email if no username field
              setState(() {
                username = currentUser!.email?.split('@')[0] ?? 'Anonymous';
              });
            }
          } else {
            // Fallback to email if user document doesn't exist
            setState(() {
              username = currentUser!.email?.split('@')[0] ?? 'Anonymous';
            });
          }
        } catch (e) {
          print('Error fetching username: $e');
          // Fallback to email
          setState(() {
            username = currentUser!.email?.split('@')[0] ?? 'Anonymous';
          });
        }
      }
    } else {
      setState(() {
        username = 'Anonymous';
      });
    }
  }

  void _addPost() async {
    if (_postController.text.isNotEmpty) {
      await postsCollection.add({
        'username': username, // Now using the retrieved username
        'userId': currentUser?.uid ?? 'anonymous',
        'message': _postController.text,
        'timestamp': Timestamp.now(),
        'replies': [],
      });
      _postController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Discussion Board'),
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _postController,
                    decoration: InputDecoration(
                      hintText: 'Write your post...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.send, color: Colors.blue),
                  onPressed: _addPost,
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder(
              stream: postsCollection.orderBy('timestamp', descending: true).snapshots(),
              builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }
                return ListView(
                  padding: EdgeInsets.all(16),
                  children: snapshot.data!.docs.map((doc) {
                    var post = doc.data() as Map<String, dynamic>;
                    return Card(
                      elevation: 4,
                      margin: EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  child: Text(post['username'][0].toUpperCase()),
                                  backgroundColor: Colors.blue[100],
                                ),
                                SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      post['username'],
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      post['timestamp'].toDate().toString().substring(0, 16),
                                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Text(post['message']),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}