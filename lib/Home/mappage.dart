import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

class MapPage extends StatefulWidget {
  const MapPage({Key? key}) : super(key: key);

  @override
  State createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> with TickerProviderStateMixin {
  final Completer<GoogleMapController> _controller = Completer();
  GoogleMapController? _mapController;

  // --- IMPORTANT: REPLACE WITH YOUR KEYS ---
  static const String _googleMapsApiKey = 'AIzaSyBGOhyR-FU97Fd8hLbRGN8-ERs7gtlvvIs'; // Replace with your Google Maps key
  static const String _geminiApiKey = 'AIzaSyB9f1sjZCc7VSV-2M8d3Yj8bXZk6D0abkU'; // Replace with your Gemini API key

  static const CameraPosition _kGooglePlex =
  CameraPosition(target: LatLng(10.8505, 76.2711), zoom: 7.0);

  Set<Marker> _markers = {};
  Set<Polygon> _polygons = {};
  Set<Polyline> _polylines = {};
  List<Waypoint> _waypoints = [];
  Position? _currentPosition;
  bool _isLoadingLocation = true;
  MapType _currentMapType = MapType.normal;

  bool _showSearchBar = false;
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  List<SearchResult> _searchResults = [];
  Timer? _debounce;

  bool _isRideActive = false;
  Waypoint? _activeDestination;
  List<LatLng> _routePoints = [];
  double _totalDistance = 0.0;
  double _estimatedTime = 0.0;

  late AnimationController _rideAnimationController;
  late Animation<double> _rideAnimation;

  StreamSubscription<Position>? _positionStream;
  Timer? _routeUpdateTimer;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _setInitialMarkers();
    _initializeAnimations();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    _rideAnimationController.dispose();
    _positionStream?.cancel();
    _routeUpdateTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  void _initializeAnimations() {
    _rideAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _rideAnimation =
        CurvedAnimation(parent: _rideAnimationController, curve: Curves.easeInOut);
  }

  void _setInitialMarkers() => _markers = {};

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _handleLocationError('Location services are disabled.');
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission != LocationPermission.whileInUse && permission != LocationPermission.always) {
          _handleLocationError('Location permissions are denied.');
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        _handleLocationError('Location permissions are permanently denied.');
        return;
      }
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      if (!mounted) return;
      setState(() {
        _currentPosition = position;
        _isLoadingLocation = false;
      });
      _animateToPosition(position.latitude, position.longitude);
      _addUserLocationMarker();
    } catch (e) {
      _handleLocationError('An error occurred while getting location: $e');
    }
  }

  void _handleLocationError(String message) {
    if (mounted) {
      setState(() => _isLoadingLocation = false);
      _showLocationDialog(message);
    }
  }

  void _addUserLocationMarker() {
    if (_currentPosition != null) {
      setState(() => _markers.add(
        Marker(
          markerId: const MarkerId('user_location'),
          position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          infoWindow: const InfoWindow(title: 'Your Location'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      ));
    }
  }

  Future<void> _animateToPosition(double lat, double lng) async {
    final controller = await _controller.future;
    controller.animateCamera(
      CameraUpdate.newCameraPosition(CameraPosition(target: LatLng(lat, lng), zoom: 16.0)),
    );
  }

  void _onMapTypeButtonPressed() => setState(() {
    _currentMapType = _currentMapType == MapType.normal ? MapType.satellite : MapType.normal;
  });

  void _centerOnUserLocation() {
    if (_currentPosition != null) {
      _animateToPosition(_currentPosition!.latitude, _currentPosition!.longitude);
    } else {
      _getCurrentLocation();
    }
  }

  void _toggleSearchBar() {
    setState(() => _showSearchBar = !_showSearchBar);
    if (!_showSearchBar) {
      _searchController.clear();
      setState(() => _searchResults.clear());
    }
  }

  Future<void> _searchLocation(String query) async {
    if (query.length < 2) {
      setState(() => _searchResults.clear());
      return;
    }
    setState(() => _isSearching = true);
    final String url =
        'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=${Uri.encodeComponent(query)}&key=$_googleMapsApiKey&types=establishment|geocode';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          List<SearchResult> finalResults = await Future.wait(
            (data['predictions'] as List).map((p) async {
              final details = await _getPlaceDetails(p['place_id']);
              return SearchResult(
                name: p['structured_formatting']['main_text'] ?? p['description'],
                address: p['structured_formatting']['secondary_text'] ?? '',
                latitude: details?['lat'] ?? 0.0,
                longitude: details?['lng'] ?? 0.0,
              );
            }),
          );
          if (!mounted) return;
          setState(() {
            _searchResults = finalResults.where((r) => r.latitude != 0.0).toList();
            _isSearching = false;
          });
        } else {
          _showSearchError();
        }
      } else {
        _showSearchError();
      }
    } catch (e) {
      _showSearchError();
    }
  }

  Future<Map<String, double>?> _getPlaceDetails(String placeId) async {
    final String url =
        'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&fields=geometry&key=$_googleMapsApiKey';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final location = data['result']['geometry']['location'];
          return {'lat': location['lat'].toDouble(), 'lng': location['lng'].toDouble()};
        }
      }
    } catch (e) {
      print('Place details error: $e');
    }
    return null;
  }

  void _showSearchError() {
    if (!mounted) return;
    setState(() => _isSearching = false);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(
        content: Text('Search failed. Please check your connection or API key.'),
        backgroundColor: Colors.red,
      ));
  }

  void _selectSearchResult(SearchResult result) {
    _addWaypoint(result.name, result.latitude, result.longitude);
    setState(() {
      _searchResults.clear();
      _searchController.clear();
      _showSearchBar = false;
    });
    _animateToPosition(result.latitude, result.longitude);
  }

  void _addWaypoint(String name, double lat, double lng) {
    final waypoint = Waypoint(id: 'waypoint_${_waypoints.length}', name: name, position: LatLng(lat, lng));
    setState(() {
      _waypoints.add(waypoint);
      _markers.add(
        Marker(
          markerId: MarkerId(waypoint.id),
          position: waypoint.position,
          infoWindow: InfoWindow(title: waypoint.name),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          onTap: () => _showWaypointOptions(waypoint),
        ),
      );
    });
  }
  void _removeWaypoint(String waypointId) {
    setState(() {
      _waypoints.removeWhere((w) => w.id == waypointId);
      _markers.removeWhere((m) => m.markerId.value == waypointId);
    });
  }

  void _clearAllWaypoints() {
    if (_isRideActive) _cancelRide();
    setState(() {
      _markers.removeWhere((m) => m.markerId.value.startsWith('waypoint_'));
      _waypoints.clear();
    });
    Navigator.pop(context);
  }

  // --- Core "Worst Route" Logic ---

  Future<void> _startRideToDestination(Waypoint destination) async {
    if (_currentPosition == null) {
      _showRouteError('Current location not available.');
      return;
    }
    setState(() {
      _isRideActive = true;
      _activeDestination = destination;
    });
    _rideAnimationController.forward();
    await _createWorstRoute(destination);
    _startLocationTracking();
  }

  Future<void> _createWorstRoute(Waypoint destination) async {
    final startPoint = LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
    final endPoint = destination.position;

    final String? startName = await _getPlaceName(startPoint);
    final String? endName = await _getPlaceName(endPoint);

    if (startName == null || endName == null) {
      _showRouteError("Could not identify start or end location names.");
      _cancelRide();
      return;
    }

    final List<String>? waypointNames = await _getWaypointsFromGemini(startName, endName);

    if (waypointNames == null || waypointNames.isEmpty) {
      _showRouteError("Gemini could not provide waypoints. Try again.");
      _cancelRide();
      return;
    }

    final List<LatLng> geocodedWaypoints = await _geocodeWaypointNames(waypointNames);

    if (geocodedWaypoints.length != waypointNames.length) {
      _showRouteError("Could not find all locations suggested by Gemini.");
      _cancelRide();
      return;
    }

    await _getDirectionsWithWaypoints(startPoint, endPoint, geocodedWaypoints);
  }

  // --- Gemini and Geocoding Helpers ---

  Future<String?> _getPlaceName(LatLng coords) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(coords.latitude, coords.longitude);
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        return "${place.name}, ${place.locality}";
      }
    } catch (e) {
      print("Error getting place name: $e");
    }
    return null;
  }

  Future<List<String>?> _getWaypointsFromGemini(String origin, String destination) async {
    final url = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent?key=$_geminiApiKey';

    final prompt = '''
   Find me a deliberately inefficient and long driving route from "$origin" to "$destination".
- The goal is to make the journey absurdly long, roughly 3 to 5 times the normal distance.
- Suggest a series of 3 to 5 intermediate, out-of-the-way towns or landmarks to use as waypoints.
- The final destination must still be "$destination".
- Return ONLY the list of these intermediate place names, separated by a pipe character (|).
- Example format: Place A|Place B|Place C
    ''';

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [{'parts': [{'text': prompt}]}]
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['candidates'][0]['content']['parts'][0]['text'] as String;
        return content.trim().split('|');
      } else {
        print("Gemini API Error: ${response.body}");
        return null;
      }
    } catch (e) {
      print("Error calling Gemini API: $e");
      return null;
    }
  }

  Future<List<LatLng>> _geocodeWaypointNames(List<String> waypointNames) async {
    List<LatLng> geocodedPoints = [];
    for (String name in waypointNames) {
      final url = 'https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(name)}&key=$_googleMapsApiKey';
      try {
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['status'] == 'OK' && (data['results'] as List).isNotEmpty) {
            final location = data['results'][0]['geometry']['location'];
            geocodedPoints.add(LatLng(location['lat'], location['lng']));
          }
        }
      } catch (e) {
        print("Error geocoding '$name': $e");
      }
    }
    return geocodedPoints;
  }

  // --- CORRECTED DIRECTIONS FUNCTION ---
  Future<void> _getDirectionsWithWaypoints(LatLng origin, LatLng destination, List<LatLng> waypoints) async {
    String waypointsString = waypoints.map((p) => '${p.latitude},${p.longitude}').join('|');

    final url = 'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=${origin.latitude},${origin.longitude}'
        '&destination=${destination.latitude},${destination.longitude}'
        '&waypoints=optimize:false|$waypointsString'
        '&key=$_googleMapsApiKey';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && (data['routes'] as List).isNotEmpty) {
          final route = data['routes'][0];

          int totalDistanceInMeters = 0;
          int totalDurationInSeconds = 0;

          // Loop through ALL legs of the route to sum up distance and duration
          for (var leg in route['legs']) {
            totalDistanceInMeters += leg['distance']['value'] as int;
            totalDurationInSeconds += leg['duration']['value'] as int;
          }

          setState(() {
            _routePoints = _decodePolyline(route['overview_polyline']['points']);
            _totalDistance = totalDistanceInMeters / 1000.0; // Correct total distance in km
            _estimatedTime = totalDurationInSeconds / 60.0;   // Correct total time in minutes
            _polylines = {
              Polyline(
                polylineId: const PolylineId('worst_route_gemini'),
                points: _routePoints,
                color: Colors.red.withOpacity(0.8),
                width: 6,
              ),
            };
          });
          _fitRouteInView(_routePoints);
        } else {
          _showRouteError(data['error_message'] ?? 'Could not plot route with waypoints.');
        }
      } else {
        _showRouteError('Directions API request failed.');
      }
    } catch (e) {
      _showRouteError("An error occurred: $e");
    }
  }


  // --- Other Methods (UI, Tracking, etc.) ---

  void _cancelRide() {
    setState(() {
      _isRideActive = false;
      _activeDestination = null;
      _routePoints.clear();
      _polylines.clear();
      _totalDistance = 0.0;
      _estimatedTime = 0.0;
    });
    _rideAnimationController.reverse();
    _positionStream?.cancel();
    _routeUpdateTimer?.cancel();
  }

  void _startLocationTracking() {
    _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10))
        .listen((Position position) {
      if (!mounted) return;
      setState(() {
        _currentPosition = position;
        _markers.removeWhere((m) => m.markerId.value == 'user_location');
        _markers.add(
          Marker(
            markerId: const MarkerId('user_location'),
            position: LatLng(position.latitude, position.longitude),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
            anchor: const Offset(0.5, 0.5),
            rotation: position.heading,
            flat: true,
          ),
        );
      });
      if (_activeDestination != null) {
        final distance = Geolocator.distanceBetween(
            position.latitude, position.longitude, _activeDestination!.position.latitude, _activeDestination!.position.longitude);
        if (distance < 50) _arriveAtDestination();
      }
    });
    _routeUpdateTimer?.cancel();
  }

  void _showRouteError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Route Error: $message'),
      backgroundColor: Colors.red,
    ));
    if (_isRideActive) _cancelRide();
  }

  void _arriveAtDestination() {
    _cancelRide();
    _showSimpleDialog('Arrived!', 'You have finally arrived at ${_activeDestination?.name ?? 'your destination'} after that ridiculous journey!');
  }

  void _fitRouteInView(List<LatLng> routePoints) {
    if (routePoints.isEmpty || _mapController == null) return;
    double minLat = routePoints.first.latitude, maxLat = routePoints.first.latitude;
    double minLng = routePoints.first.longitude, maxLng = routePoints.first.longitude;
    for (var point in routePoints) {
      minLat = min(minLat, point.latitude);
      maxLat = max(maxLat, point.latitude);
      minLng = min(minLng, point.longitude);
      maxLng = max(maxLng, point.longitude);
    }
    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(southwest: LatLng(minLat, minLng), northeast: LatLng(maxLat, maxLng)),
        100.0,
      ),
    );
  }

  void _showLocationDialog(String message) => _showSimpleDialog('Location Access', message);

  void _showWaypointOptions(Waypoint waypoint) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Text(waypoint.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(
                'Lat: ${waypoint.position.latitude.toStringAsFixed(4)}, Lng: ${waypoint.position.longitude.toStringAsFixed(4)}',
                style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _startRideToDestination(waypoint);
              },
              icon: const Icon(Icons.directions_bike_outlined),
              label: const Text('Start Worst Route'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 44)),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _removeWaypoint(waypoint.id);
              },
              icon: const Icon(Icons.delete),
              label: const Text('Remove Waypoint'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 44)),
            ),
          ],
        ),
      ),
    );
  }

  void _showClearWaypointsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Waypoints'),
        content: const Text('Are you sure you want to remove all waypoints?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: _clearAllWaypoints, child: const Text('Clear All', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  void _showSimpleDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
      ),
    );
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;
    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;
      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;
      points.add(LatLng((lat / 1E5), (lng / 1E5)));
    }
    return points;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          GoogleMap(
            mapType: _currentMapType,
            initialCameraPosition: _kGooglePlex,
            markers: _markers,
            polygons: _polygons,
            polylines: _polylines,
            onMapCreated: (controller) {
              _controller.complete(controller);
              _mapController = controller;
            },
            zoomControlsEnabled: false,
            myLocationButtonEnabled: false,
            myLocationEnabled: false,
          ),
          if (_showSearchBar) _buildSearchBarAndResults(),
          if (_isRideActive) _buildRideStatusPanel(),
          _buildMapControls(),
          if (_waypoints.isNotEmpty && !_isRideActive) _buildWaypointsPanel(),
          if (!_showSearchBar) _buildBottomInfoPanel(),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      automaticallyImplyLeading: false,
      actions: [
        if (_waypoints.isNotEmpty)
          _buildAppBarButton(
            icon: Icons.clear_all,
            color: Colors.red,
            onPressed: _showClearWaypointsDialog,
          ),
        _buildAppBarButton(
          icon: _currentMapType == MapType.normal ? Icons.layers : Icons.map,
          onPressed: _onMapTypeButtonPressed,
        ),
      ],
    );
  }

  Widget _buildAppBarButton(
      {required IconData icon, required VoidCallback onPressed, Color color = Colors.black}) {
    return Container(
      margin: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: IconButton(onPressed: onPressed, icon: Icon(icon, color: color)),
    );
  }

  Widget _buildMapControls() {
    double bottomPosition = _isRideActive ? 120 : (_waypoints.isNotEmpty ? 200 : 20);
    if (_showSearchBar) {
      bottomPosition = 20;
    } else if (!_isRideActive && _waypoints.isEmpty) {
      bottomPosition = 120;
    }

    return Positioned(
      bottom: bottomPosition,
      right: 16,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildMapControlButton(
            onPressed: _isLoadingLocation ? null : _centerOnUserLocation,
            child: _isLoadingLocation
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.my_location, color: Colors.blue),
          ),
          if (!_isRideActive)
            Padding(
              padding: const EdgeInsets.only(top: 12.0),
              child: FloatingActionButton(
                onPressed: _toggleSearchBar,
                backgroundColor: _showSearchBar ? Colors.blue.shade700 : Colors.white,
                mini: true,
                elevation: 4.0,
                heroTag: 'search_button',
                child: Icon(Icons.search, color: _showSearchBar ? Colors.white : Colors.black),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMapControlButton(
      {required VoidCallback? onPressed, required Widget child, Color color = Colors.white}) {
    return FloatingActionButton(
      onPressed: onPressed,
      backgroundColor: color,
      mini: true,
      elevation: 4.0,
      heroTag: null,
      child: child,
    );
  }

  Widget _buildSearchBarAndResults() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 16,
      right: 16,
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(25),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
            ),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: (value) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 500), () => _searchLocation(value));
              },
              decoration: InputDecoration(
                hintText: 'Search places, addresses...',
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                prefixIcon: _isSearching
                    ? const Padding(
                    padding: EdgeInsets.all(12.0), child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.search, color: Colors.grey),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(onPressed: _searchController.clear, icon: const Icon(Icons.clear, color: Colors.grey))
                    : null,
              ),
            ),
          ),
          if (_searchResults.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 8),
              height: 200,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _searchResults.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final result = _searchResults[index];
                  return ListTile(
                    leading: const Icon(Icons.location_on, color: Colors.blue),
                    title: Text(result.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: Text(result.address, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    onTap: () => _selectSearchResult(result),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRideStatusPanel() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 16,
      right: 16,
      child: AnimatedBuilder(
        animation: _rideAnimation,
        builder: (context, child) => Transform.scale(scale: _rideAnimation.value, child: child),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.deepOrange,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'AI-Generated Worst Route!',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(onPressed: _cancelRide, icon: const Icon(Icons.close, color: Colors.white)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildRideInfo(Icons.straighten, '${_totalDistance.toStringAsFixed(1)} km'),
                  _buildRideInfo(Icons.access_time, '${_estimatedTime.toInt()} min'),
                  _buildRideInfo(Icons.speed, _currentPosition != null ? '${(_currentPosition!.speed * 3.6).toStringAsFixed(0)} km/h' : '0 km/h'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRideInfo(IconData icon, String text) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(height: 4),
        Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildWaypointsPanel() {
    return Positioned(
      bottom: 120,
      left: 16,
      right: 16,
      child: Container(
        height: 80,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('${_waypoints.length} Waypoint${_waypoints.length > 1 ? 's' : ''}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            Expanded(
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _waypoints.length,
                itemBuilder: (context, index) {
                  final waypoint = _waypoints[index];
                  return Container(
                    margin: const EdgeInsets.only(right: 8, top: 4),
                    child: GestureDetector(
                      onTap: () => _showWaypointOptions(waypoint),
                      child: Chip(
                        avatar: const Icon(Icons.location_on, size: 16),
                        label: Text(waypoint.name, style: const TextStyle(fontSize: 12)),
                        backgroundColor: Colors.green.shade50,
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: () => _removeWaypoint(waypoint.id),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomInfoPanel() {
    final bool isRide = _isRideActive && _activeDestination != null;
    final String title = isRide ? 'Worst Ride Active!' : 'Current Location';
    final String subtitle = isRide
        ? 'To ${_activeDestination!.name}'
        : _currentPosition != null
        ? 'Lat: ${_currentPosition!.latitude.toStringAsFixed(4)}, Lng: ${_currentPosition!.longitude.toStringAsFixed(4)}'
        : 'Getting location...';
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        height: 110,
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: isRide ? Colors.deepOrange.shade100 : Colors.blue.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(isRide ? Icons.auto_awesome : Icons.my_location, color: isRide ? Colors.deepOrange : Colors.blue),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(fontSize: 14, color: Colors.grey[600]), overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Data Classes ---
class Waypoint {
  final String id;
  final String name;
  final LatLng position;

  Waypoint({required this.id, required this.name, required this.position});
}

class SearchResult {
  final String name;
  final String address;
  final double latitude;
  final double longitude;

  SearchResult({
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
  });
}