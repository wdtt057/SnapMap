import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class PostDetailPage extends StatelessWidget {
  final String imageUrl;
  final String description;
  final LatLng location;

  const PostDetailPage({
    required this.imageUrl,
    required this.description,
    required this.location,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Post Details"),
      ),
      body: Column(
        children: [
          Image.network(imageUrl, fit: BoxFit.cover),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Description",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  SizedBox(height: 8),
                  Text(description, style: TextStyle(fontSize: 16)),
                  SizedBox(height: 16),
                  Text(
                    "Location",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  SizedBox(height: 8),
                  Expanded(
                    child: GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: location,
                        zoom: 15,
                      ),
                      markers: {
                        Marker(
                          markerId: MarkerId('postLocation'),
                          position: location,
                          infoWindow: InfoWindow(title: "Post Location"),
                        ),
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
