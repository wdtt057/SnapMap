import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditPostPage extends StatefulWidget {
  final String postId;
  final String currentDescription;
  final LatLng currentLocation;

  const EditPostPage({
    required this.postId,
    required this.currentDescription,
    required this.currentLocation,
    Key? key,
  }) : super(key: key);

  @override
  _EditPostPageState createState() => _EditPostPageState();
}

class _EditPostPageState extends State<EditPostPage> {
  late TextEditingController _descriptionController;
  late LatLng _selectedLocation;
  late GoogleMapController _mapController;

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController(text: widget.currentDescription);
    _selectedLocation = widget.currentLocation;
  }

  void _onMapTap(LatLng location) {
    setState(() {
      _selectedLocation = location;
    });
  }

  Future<void> _saveChanges() async {
    try {
      await FirebaseFirestore.instance.collection('photos').doc(widget.postId).update({
        'description': _descriptionController.text,
        'location': {
          'lat': _selectedLocation.latitude,
          'lng': _selectedLocation.longitude,
        },
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Post updated successfully!')),
      );

      Navigator.pop(context); // Return to the previous page
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating post: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Post'),
        actions: [
          IconButton(
            icon: Icon(Icons.save),
            onPressed: _saveChanges,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 20),
            Expanded(
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _selectedLocation,
                  zoom: 14,
                ),
                onMapCreated: (controller) => _mapController = controller,
                onTap: _onMapTap,
                markers: {
                  Marker(
                    markerId: MarkerId('current'),
                    position: _selectedLocation,
                    draggable: true,
                  ),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
