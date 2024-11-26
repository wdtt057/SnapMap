import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;
  int _selectedIndex = 0;

  String _userName = "Dengtai";
  int _followers = 120;
  int _following = 150;

  // Map-related variables
  late GoogleMapController _mapController;
  final LatLng _initialPosition = const LatLng(37.7749, -122.4194); // Default location (San Francisco)
  Set<Marker> _markers = {};

  // Firebase instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Method to capture an image using the camera
  Future<void> _captureImage() async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    if (photo != null) {
      setState(() {
        _selectedImage = File(photo.path);
      });
      await _uploadImage(_selectedImage!);
    }
  }

  // Method to upload image to Firebase Storage and save metadata to Firestore
  Future<void> _uploadImage(File image) async {
    try {
      // Upload image to Firebase Storage
      final storageRef = FirebaseStorage.instance.ref();
      final imageRef = storageRef.child('photos/${DateTime.now().millisecondsSinceEpoch}.jpg');
      await imageRef.putFile(image);

      // Get download URL
      final downloadUrl = await imageRef.getDownloadURL();

      // Get current user's location (you may need to implement location services)
      // For this example, we'll use the initial map position
      final LatLng userLocation = _initialPosition;

      // Save metadata to Firestore
      await _firestore.collection('photos').add({
        'url': downloadUrl,
        'userId': _auth.currentUser?.uid ?? 'anonymous',
        'userName': _userName,
        'location': {'lat': userLocation.latitude, 'lng': userLocation.longitude},
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Optionally, update markers to include the new photo
      _addMarker(userLocation, downloadUrl);
    } catch (e) {
      print('Error uploading image: $e');
    }
  }

  // Method to add a marker to the map
  void _addMarker(LatLng position, String imageUrl) {
    final marker = Marker(
      markerId: MarkerId(imageUrl),
      position: position,
      infoWindow: InfoWindow(
        title: _userName,
        snippet: 'Photo',
        onTap: () {
          // Handle marker tap if needed
        },
      ),
    );

    setState(() {
      _markers.add(marker);
    });
  }

  // Method to load markers from Firestore
  Future<void> _loadMarkers() async {
    final snapshot = await _firestore.collection('photos').get();
    final markers = snapshot.docs.map((doc) {
      final data = doc.data();
      final location = data['location'];
      return Marker(
        markerId: MarkerId(doc.id),
        position: LatLng(location['lat'], location['lng']),
        infoWindow: InfoWindow(
          title: data['userName'] ?? 'User',
          snippet: 'Photo',
          onTap: () {
            // Handle marker tap if needed
          },
        ),
      );
    }).toSet();

    setState(() {
      _markers = markers;
    });
  }

  void _onBottomNavTap(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _buildContent() {
    switch (_selectedIndex) {
      case 0:
        return Center(child: Text('Home Content Here', style: TextStyle(fontSize: 20)));
      case 1:
        return _buildMapView();
      case 2:
        return _buildPhotoGallery();
      default:
        return Center(child: Text('Home Content Here', style: TextStyle(fontSize: 20)));
    }
  }

  Widget _buildMapView() {
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: _initialPosition,
        zoom: 12,
      ),
      onMapCreated: (controller) {
        _mapController = controller;
        _loadMarkers();
      },
      markers: _markers,
    );
  }

  Widget _buildPhotoGallery() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('photos').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return CircularProgressIndicator();
        final photos = snapshot.data!.docs;
        return GridView.builder(
          itemCount: photos.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
          ),
          itemBuilder: (context, index) {
            final photo = photos[index].data() as Map<String, dynamic>;
            return Image.network(photo['url'], fit: BoxFit.cover);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SnapMap'),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blue,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundImage: NetworkImage("https://via.placeholder.com/150"), // Placeholder image
                  ),
                  SizedBox(height: 10),
                  Text(
                    _userName,
                    style: TextStyle(color: Colors.white, fontSize: 20),
                  ),
                  SizedBox(height: 5),
                  Row(
                    children: [
                      Text(
                        'Followers: $_followers',
                        style: TextStyle(color: Colors.white),
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Following: $_following',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            ListTile(
              leading: Icon(Icons.person),
              title: Text('Profile'),
              onTap: () {
                // Navigate to profile page
              },
            ),
            ListTile(
              leading: Icon(Icons.settings),
              title: Text('Settings'),
              onTap: () {
                // Navigate to settings page
              },
            ),
          ],
        ),
      ),
      body: _buildContent(),
      floatingActionButton: FloatingActionButton(
        onPressed: _captureImage,
        child: Icon(Icons.camera_alt),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onBottomNavTap,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Map',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.photo_library),
            label: 'Gallery',
          ),
        ],
      ),
    );
  }
}
