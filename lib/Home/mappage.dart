import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
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

  static const String _placesApiKey = 'AIzaSyBGOhyR-FU97Fd8hLbRGN8-ERs7gtlvvIs'; // Replace with your actual key
  static const CameraPosition _kGooglePlex =
  CameraPosition(target: LatLng(10.8505, 76.2711), zoom: 7.0);

  Set<Marker> _markers = {};
  Set<Polygon> _polygons = {};
  Set<Polyline> _polylines = {};
  List<Waypoint> _waypoints = [];
  Position? _currentPosition;
  bool _isLoadingLocation = true;
  MapType _currentMapType = MapType.normal;

  // Search UI State
  bool _showSearchBar = false;
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  List<SearchResult> _searchResults = [];
  Timer? _debounce;

  // Ride State
  bool _isRideActive = false;
  Waypoint? _activeDestination;
  List<LatLng> _routePoints = [];
  double _totalDistance = 0.0;
  double _estimatedTime = 0.0; // In minutes

  // Animation
  late AnimationController _rideAnimationController;
  late Animation<double> _rideAnimation;

  // Subscriptions & Timers
  StreamSubscription<Position>? _positionStream;
  Timer? _routeUpdateTimer;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _setInitialMarkers();
    _initializeAnimations();
    _addLandUseZonePolygon();
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

  void _setInitialMarkers() {
    _markers = {};
  }

  // Add a sample polygon (demo)
  void _addLandUseZonePolygon() {
    final List<LatLng> polygonPoints = [
      const LatLng(10.855, 76.275),
      const LatLng(10.860, 76.280),
      const LatLng(10.858, 76.285),
      const LatLng(10.853, 76.280),
    ];
    final Polygon landUseZone = Polygon(
      polygonId: const PolygonId('residential_zone_1'),
      points: polygonPoints,
      fillColor: Colors.blue.withOpacity(0.3),
      strokeColor: Colors.blue,
      strokeWidth: 2,
      zIndex: 0,
    );
    setState(() {
      _polygons.add(landUseZone);
    });
  }

  // Location Handling
  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _handleLocationError('Location services are disabled. Please enable them.');
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
        _handleLocationError('Location permissions are permanently denied. We cannot request permissions.');
        return;
      }
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );
      if (!mounted) return;
      setState(() {
        _currentPosition = position;
        _isLoadingLocation = false;
      });
      _animateToPosition(position.latitude, position.longitude);
      _addUserLocationMarker();
    } on PlatformException catch (e) {
      _handleLocationError('Error checking location permissions: ${e.message}');
    } on TimeoutException {
      _handleLocationError('Location request timed out. Please try again.');
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

  // Map Controls & Actions
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

  // Search Functionality (Places autocomplete)
  Future<void> _searchLocation(String query) async {
    if (query.length < 2) {
      setState(() => _searchResults.clear());
      return;
    }
    setState(() => _isSearching = true);
    String locationBias = '';
    if (_mapController != null) {
      LatLngBounds bounds = await _mapController!.getVisibleRegion();
      LatLng center = LatLng((bounds.northeast.latitude + bounds.southwest.latitude) / 2,
          (bounds.northeast.longitude + bounds.southwest.longitude) / 2);
      locationBias = '&location=${center.latitude},${center.longitude}&radius=50000'; // 50km radius
    }
    final String url =
        'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=${Uri.encodeComponent(query)}&key=$_placesApiKey&types=establishment|geocode$locationBias';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          List<SearchResult?> nullableResults = await Future.wait(
            (data['predictions'] as List).map((p) async {
              final details = await _getPlaceDetails(p['place_id']);
              return details != null
                  ? SearchResult(
                name: p['structured_formatting']['main_text'] ?? p['description'],
                address: p['structured_formatting']['secondary_text'] ?? '',
                latitude: details['lat']!,
                longitude: details['lng']!,
              )
                  : null;
            }),
          );
          final List<SearchResult> finalResults =
          nullableResults.whereType<SearchResult>().toList();
          if (!mounted) return;
          setState(() {
            _searchResults = finalResults;
            _isSearching = false;
          });
        } else {
          _showSearchError();
        }
      } else {
        _showSearchError();
      }
    } catch (e) {
      print('Places API error: $e');
      _showSearchError();
    }
  }

  Future<Map<String, double>?> _getPlaceDetails(String placeId) async {
    final String url =
        'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&fields=geometry&key=$_placesApiKey';
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

  // --- Waypoint Management ---

  void _addWaypoint(String name, double lat, double lng) {
    final waypoint = Waypoint(id: 'waypoint_${_waypoints.length}', name: name, position: LatLng(lat, lng));
    setState(() {
      _waypoints.add(waypoint);
      _markers.add(
        Marker(
          markerId: MarkerId(waypoint.id),
          position: waypoint.position,
          infoWindow: InfoWindow(title: waypoint.name, snippet: 'Waypoint ${_waypoints.length}'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          onTap: () => _showWaypointOptions(waypoint),
        ),
      );
    });
  }

  void _removeWaypoint(String waypointId) => setState(() {
    _waypoints.removeWhere((w) => w.id == waypointId);
    _markers.removeWhere((m) => m.markerId.value == waypointId);
  });

  void _clearAllWaypoints() {
    if (_isRideActive) _cancelRide();
    setState(() {
      _markers.removeWhere((m) => _waypoints.any((w) => w.id == m.markerId.value));
      _waypoints.clear();
    });
    Navigator.pop(context);
  }

  // --- Ride Functionality ---

  Future<void> _startRideToDestination(Waypoint destination) async {
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Current location not available.'),
        backgroundColor: Colors.red,
      ));
      return;
    }
    setState(() {
      _isRideActive = true;
      _activeDestination = destination;
    });
    _rideAnimationController.forward();
    await _createRouteToDestination(destination);
    _startLocationTracking();
  }

  // --- !!! API CALL ONLY WITH VALID (ON-ROAD) WAYPOINTS !!!
  Future<void> _createRouteToDestination(Waypoint destination) async {
    if (_currentPosition == null) return;

    final start = LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
    final end = destination.position;

    // The &alternatives=true parameter is added to get multiple routes
    final url = 'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=${start.latitude},${start.longitude}'
        '&destination=${end.latitude},${end.longitude}'
        '&alternatives=true' // <-- MODIFICATION IS HERE
        '&key=$_placesApiKey';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && (data['routes'] as List).isNotEmpty) {
          // --- Find the route with the maximum distance ---
          List routes = data['routes'];
          Map? longestRoute;
          int maxDistance = 0;
          for (var route in routes) {
            int totalDistance = 0;
            for (var leg in route['legs']) {
              totalDistance += (leg['distance']['value'] as int? ?? 0);
            }
            if (totalDistance > maxDistance) {
              maxDistance = totalDistance;
              longestRoute = route;
            }
          }
          if (longestRoute == null) {
            longestRoute = routes[0]; // fallback
          }

          // --- Detailed polyline from all steps in the longest route ---
          List<LatLng> routePoints = [];
          double _totalDistance = 0.0;
          double _estimatedTime = 0.0;
          for (var leg in longestRoute?['legs']) {
            _totalDistance += (leg['distance']['value'] as int? ?? 0);
            _estimatedTime += (leg['duration']['value'] as int? ?? 0);
            for (var step in leg['steps']) {
              String stepPolyline = step['polyline']['points'];
              routePoints.addAll(_decodePolyline(stepPolyline));
            }
          }

          _totalDistance = _totalDistance / 1000.0;
          _estimatedTime = _estimatedTime / 60.0;

          if (!mounted) return;
          setState(() {
            _routePoints = routePoints;
            this._totalDistance = _totalDistance;
            this._estimatedTime = _estimatedTime;
            _polylines = {
              Polyline(
                polylineId: const PolylineId('route'),
                points: routePoints,
                color: Colors.purple.withOpacity(0.8),
                width: 6,
                zIndex: 1,
              ),
            };
            _markers.removeWhere((m) => m.markerId.value == destination.id);
            _markers.add(
              Marker(
                markerId: MarkerId(destination.id),
                position: destination.position,
                infoWindow: InfoWindow(
                  title: destination.name,
                  snippet:
                  'Destination - ${_totalDistance.toStringAsFixed(1)} km, ~${_estimatedTime.toInt()} min',
                ),
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
              ),
            );
          });
          _fitRouteInView(routePoints);
        } else {
          _showRouteError(data['status']);
        }
      } else {
        _showRouteError('Failed to connect to Directions API');
      }
    } catch (e) {
      _showRouteError('An error occurred while fetching the route: $e');
    }
  }

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
        locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high, distanceFilter: 10))
        .listen((Position position) {
      if (!mounted) return;
      setState(() {
        _currentPosition = position;
        _markers.removeWhere((m) => m.markerId.value == 'user_location');
        _markers.add(
          Marker(
            markerId: const MarkerId('user_location'),
            position: LatLng(position.latitude, position.longitude),
            infoWindow:
            InfoWindow(snippet: 'Speed: ${(position.speed * 3.6).toStringAsFixed(1)} km/h'),
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

    _routeUpdateTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_isRideActive && _activeDestination != null) {
        _createRouteToDestination(_activeDestination!);
      }
    });
  }

  void _arriveAtDestination() {
    _cancelRide();
    _showSimpleDialog('Arrived!', 'You have arrived at ${_activeDestination?.name ?? 'your destination'}!');
  }

  void _fitRouteInView(List<LatLng> routePoints) {
    if (routePoints.isEmpty || _mapController == null) return;
    double minLat = routePoints.first.latitude, maxLat = routePoints.first.latitude;
    double minLng = routePoints.first.longitude, maxLng = routePoints.first.longitude;
    for (var point in routePoints) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLng = math.min(minLng, point.longitude);
      maxLng = math.max(maxLng, point.longitude);
    }
    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(southwest: LatLng(minLat, minLng), northeast: LatLng(maxLat, maxLng)),
        100.0,
      ),
    );
  }

  void _showLocationDialog(String message) => _showSimpleDialog('Location Access', message);
  void _showRouteError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Failed to get directions: $message. Please try again.'),
      backgroundColor: Colors.red,
    ));
    if (_isRideActive) _cancelRide();
  }

  void _showWaypointOptions(Waypoint waypoint) {
    showModalBottomSheet(
      context: context,
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
              icon: const Icon(Icons.directions_car),
              label: const Text('Start Ride'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
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

  // --- Polyline Decode Helper ---
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

  // --- WIDGET BUILD ---
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
            myLocationEnabled: false, // Handled manually
          ),
          if (_showSearchBar) _buildSearchBarAndResults(),
          if (_isRideActive) _buildRideStatusPanel(),
          _buildMapControls(),
          if (_waypoints.isNotEmpty && !_isRideActive) _buildWaypointsPanel(),
          _buildBottomInfoPanel(),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: _buildAppBarButton(
        icon: Icons.arrow_back,
        onPressed: () => Navigator.pop(context),
      ),
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
    return Positioned(
      bottom: _isRideActive ? 120 : (_waypoints.isNotEmpty ? 200 : 150),
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
              child: _buildMapControlButton(
                onPressed: _toggleSearchBar,
                color: _showSearchBar ? Colors.blue : Colors.black,
                child: const Icon(Icons.search, color: Colors.white),
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
      top: 100,
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
      top: 100,
      left: 16,
      right: 16,
      child: AnimatedBuilder(
        animation: _rideAnimation,
        builder: (context, child) => Transform.scale(scale: _rideAnimation.value, child: child),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.purple,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.directions_car, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Riding to ${_activeDestination!.name}',
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
    final String title = isRide ? 'Long Ride Active!' : 'Current Location';
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
                color: isRide ? Colors.purple.shade100 : Colors.blue.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(isRide ? Icons.alt_route : Icons.my_location, color: isRide ? Colors.purple : Colors.blue),
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

  SearchResult({required this.name, required this.address, required this.latitude, required this.longitude});
}