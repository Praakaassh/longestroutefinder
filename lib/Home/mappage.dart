import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';

class MapPage extends StatefulWidget {
  const MapPage({Key? key}) : super(key: key);

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final Completer<GoogleMapController> _controller =
  Completer<GoogleMapController>();

  // Default location (San Francisco)
  static const CameraPosition _kGooglePlex = CameraPosition(
    target: LatLng(37.42796133580664, -122.085749655962),
    zoom: 14.4746,
  );

  // Sample location for camera movement
  static const CameraPosition _kLake = CameraPosition(
      bearing: 192.8334901395799,
      target: LatLng(37.43296265331129, -122.08832357078792),
      tilt: 59.440717697143555,
      zoom: 19.151926040649414);

  // Set of markers
  Set<Marker> _markers = {};

  // Map type
  MapType _currentMapType = MapType.normal;

  @override
  void initState() {
    super.initState();
    _setMarkers();
  }

  void _setMarkers() {
    _markers = {
      const Marker(
        markerId: MarkerId('marker_1'),
        position: LatLng(37.42796133580664, -122.085749655962),
        infoWindow: InfoWindow(
          title: 'Google Plex',
          snippet: 'A nice place to work',
        ),
        icon: BitmapDescriptor.defaultMarker,
      ),
      const Marker(
        markerId: MarkerId('marker_2'),
        position: LatLng(37.43296265331129, -122.08832357078792),
        infoWindow: InfoWindow(
          title: 'Lake',
          snippet: 'A beautiful lake',
        ),
      ),
    };
  }

  void _onMapTypeButtonPressed() {
    setState(() {
      _currentMapType = _currentMapType == MapType.normal
          ? MapType.satellite
          : MapType.normal;
    });
  }

  Future<void> _goToTheLake() async {
    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newCameraPosition(_kLake));
  }

  void _onAddMarkerButtonPressed() {
    setState(() {
      _markers.add(Marker(
        markerId: MarkerId('marker_${_markers.length}'),
        position: const LatLng(37.4219983, -122.084),
        infoWindow: InfoWindow(
          title: 'New Marker ${_markers.length}',
          snippet: 'Added marker',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Google Maps'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _onMapTypeButtonPressed,
            icon: const Icon(Icons.map),
            tooltip: 'Change Map Type',
          ),
        ],
      ),
      body: GoogleMap(
        mapType: _currentMapType,
        initialCameraPosition: _kGooglePlex,
        markers: _markers,
        onMapCreated: (GoogleMapController controller) {
          _controller.complete(controller);
        },
        onTap: (LatLng location) {
          // Add marker on tap
          setState(() {
            _markers.add(Marker(
              markerId: MarkerId('tapped_${_markers.length}'),
              position: location,
              infoWindow: InfoWindow(
                title: 'Tapped Location',
                snippet: 'Lat: ${location.latitude.toStringAsFixed(4)}, Lng: ${location.longitude.toStringAsFixed(4)}',
              ),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
            ));
          });
        },
        zoomControlsEnabled: true,
        compassEnabled: true,
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        trafficEnabled: false,
        buildingsEnabled: true,
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: _goToTheLake,
            heroTag: "lake",
            tooltip: 'Go to Lake',
            child: const Icon(Icons.water),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            onPressed: _onAddMarkerButtonPressed,
            heroTag: "marker",
            tooltip: 'Add Marker',
            child: const Icon(Icons.add_location),
          ),
        ],
      ),
    );
  }
}

// Usage example - how to navigate to this page
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Google Maps Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MapPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// Example of how to use it in another widget
class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const MapPage()),
            );
          },
          child: const Text('Open Map'),
        ),
      ),
    );
  }
}