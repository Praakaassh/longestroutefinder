import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:math' as math;

// Coin Flip Widget
class CoinFlipWidget extends StatefulWidget {
  final String frontImagePath;
  final String backImagePath;
  final VoidCallback onFlipComplete;
  final Duration animationDuration;

  const CoinFlipWidget({
    Key? key,
    required this.frontImagePath,
    required this.backImagePath,
    required this.onFlipComplete,
    this.animationDuration = const Duration(milliseconds: 2000),
  }) : super(key: key);

  @override
  State<CoinFlipWidget> createState() => _CoinFlipWidgetState();
}

class _CoinFlipWidgetState extends State<CoinFlipWidget>
    with TickerProviderStateMixin {
  late AnimationController _flipController;
  late AnimationController _bounceController;
  late Animation<double> _flipAnimation;
  late Animation<double> _bounceAnimation;

  bool _isFlipping = false;
  bool _showBack = false;

  @override
  void initState() {
    super.initState();

    // Flip animation controller
    _flipController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    // Bounce animation controller
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // Flip animation with multiple rotations
    _flipAnimation = Tween<double>(
      begin: 0.0,
      end: math.pi * 6, // 3 full rotations
    ).animate(CurvedAnimation(
      parent: _flipController,
      curve: Curves.easeInOut,
    ));

    // Bounce animation for landing effect
    _bounceAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _bounceController,
      curve: Curves.elasticOut,
    ));

    _flipController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _bounceController.forward().then((_) {
          _bounceController.reverse().then((_) {
            widget.onFlipComplete();
          });
        });
      }
    });

    _flipController.addListener(() {
      // Determine which side to show based on rotation
      double rotation = _flipAnimation.value % (math.pi * 2);
      setState(() {
        _showBack = rotation > math.pi / 2 && rotation < 3 * math.pi / 2;
      });
    });
  }

  @override
  void dispose() {
    _flipController.dispose();
    _bounceController.dispose();
    super.dispose();
  }

  void flipCoin() {
    if (_isFlipping) return;

    setState(() {
      _isFlipping = true;
    });

    _flipController.reset();
    _flipController.forward().then((_) {
      setState(() {
        _isFlipping = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: flipCoin,
      child: AnimatedBuilder(
        animation: Listenable.merge([_flipAnimation, _bounceAnimation]),
        builder: (context, child) {
          return Transform.scale(
            scale: _bounceAnimation.value,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY(_flipAnimation.value),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: _showBack
                      ? Image.asset(
                    widget.backImagePath,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.orange,
                        child: const Icon(
                          Icons.star,
                          color: Colors.white,
                          size: 24,
                        ),
                      );
                    },
                  )
                      : Image.asset(
                    widget.frontImagePath,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.amber,
                        child: const Icon(
                          Icons.monetization_on,
                          color: Colors.white,
                          size: 24,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// Coin Result Page
class CoinResultPage extends StatefulWidget {
  final String result;

  const CoinResultPage({
    Key? key,
    required this.result,
  }) : super(key: key);

  @override
  State<CoinResultPage> createState() => _CoinResultPageState();
}

class _CoinResultPageState extends State<CoinResultPage>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));

    // Start animations
    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      _scaleController.forward();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: Listenable.merge([_fadeAnimation, _scaleAnimation]),
          builder: (context, child) {
            return Opacity(
              opacity: _fadeAnimation.value,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: Column(
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const Spacer(),
                          const Text(
                            'Coin Flip Result',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          const SizedBox(width: 48),
                        ],
                      ),
                    ),

                    // Main content
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Result display
                            Container(
                              width: 200,
                              height: 200,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: widget.result == 'heads'
                                      ? [Colors.amber, Colors.orange]
                                      : [Colors.blue, Colors.purple],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: (widget.result == 'heads'
                                        ? Colors.amber
                                        : Colors.blue)
                                        .withOpacity(0.3),
                                    blurRadius: 20,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Icon(
                                  widget.result == 'heads'
                                      ? Icons.monetization_on
                                      : Icons.star,
                                  size: 80,
                                  color: Colors.white,
                                ),
                              ),
                            ),

                            const SizedBox(height: 40),

                            // Result text
                            Text(
                              widget.result.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 4,
                              ),
                            ),

                            const SizedBox(height: 20),

                            Text(
                              'The coin landed on ${widget.result}!',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 18,
                              ),
                            ),

                            const SizedBox(height: 60),

                            // Action buttons
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: () => Navigator.pop(context),
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Flip Again'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(25),
                                    ),
                                  ),
                                ),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.pop(context);
                                  },
                                  icon: const Icon(Icons.map),
                                  label: const Text('Back to Map'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    foregroundColor: Colors.white,
                                    side: const BorderSide(color: Colors.white),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(25),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class MapPage extends StatefulWidget {
  const MapPage({Key? key}) : super(key: key);

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> with TickerProviderStateMixin {
  final Completer<GoogleMapController> _controller = Completer<GoogleMapController>();

  // Add your Google Places API key here
  static const String _placesApiKey = 'AIzaSyBGOhyR-FU97Fd8hLbRGN8-ERs7gtlvvIs';

  // Default location (San Francisco)
  static const CameraPosition _kGooglePlex = CameraPosition(
    target: LatLng(37.42796133580664, -122.085749655962),
    zoom: 14.4746,
  );

  // Set of markers
  Set<Marker> _markers = {};

  // Set of polygons for route
  Set<Polygon> _polygons = {};

  // Set of polylines for route
  Set<Polyline> _polylines = {};

  // Waypoints list
  List<Waypoint> _waypoints = [];

  // User location
  Position? _currentPosition;
  bool _isLoadingLocation = true;

  // Map type
  MapType _currentMapType = MapType.normal;

  // Map controller
  GoogleMapController? _mapController;

  // Animation and UI state
  bool _showSearchBar = false;
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  List<SearchResult> _searchResults = [];
  Timer? _debounce;

  // Ride functionality
  bool _isRideActive = false;
  Waypoint? _activeDestination;
  List<LatLng> _routePoints = [];
  double _totalDistance = 0.0;
  double _estimatedTime = 0.0;

  // Animation controllers
  late AnimationController _rideAnimationController;
  late Animation<double> _rideAnimation;

  // Ride tracking
  StreamSubscription<Position>? _positionStream;
  Timer? _routeUpdateTimer;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _setMarkers();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _rideAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _rideAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _rideAnimationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    _rideAnimationController.dispose();
    _positionStream?.cancel();
    _routeUpdateTimer?.cancel();
    super.dispose();
  }

  // Coin flip functionality
  void _onCoinFlipComplete() {
    // Randomly determine heads or tails
    final random = math.Random();
    final result = random.nextBool() ? 'heads' : 'tails';

    // Navigate to result page with slide transition
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            CoinResultPage(result: result),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;

          var tween = Tween(begin: begin, end: end).chain(
            CurveTween(curve: curve),
          );

          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  // [Keep all your existing methods here - getCurrentLocation, addUserLocationMarker, etc.]
  // I'll include the key ones for context:

  Future<void> _getCurrentLocation() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled;
      LocationPermission permission;

      try {
        serviceEnabled = await Geolocator.isLocationServiceEnabled();
      } on PlatformException catch (e) {
        print('Platform exception: $e');
        serviceEnabled = true;
      } catch (e) {
        print('Error checking location services: $e');
        serviceEnabled = true;
      }

      if (!serviceEnabled) {
        setState(() {
          _isLoadingLocation = false;
        });
        _showLocationDialog('Location services are disabled. Please enable location services.');
        return;
      }

      // Check location permissions
      try {
        permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied) {
            setState(() {
              _isLoadingLocation = false;
            });
            _showLocationDialog('Location permissions are denied');
            return;
          }
        }

        if (permission == LocationPermission.deniedForever) {
          setState(() {
            _isLoadingLocation = false;
          });
          _showLocationDialog('Location permissions are permanently denied, we cannot request permissions.');
          return;
        }
      } on PlatformException catch (e) {
        print('Permission error: $e');
        setState(() {
          _isLoadingLocation = false;
        });
        _showLocationDialog('Error checking location permissions: ${e.message}');
        return;
      }

      // Get current position
      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 15),
        );
        setState(() {
          _currentPosition = position;
          _isLoadingLocation = false;
        });
        _animateToPosition(position.latitude, position.longitude);
        _addUserLocationMarker();
      } on TimeoutException catch (e) {
        setState(() {
          _isLoadingLocation = false;
        });
        _showLocationDialog('Location request timed out. Please try again.');
      } on PlatformException catch (e) {
        setState(() {
          _isLoadingLocation = false;
        });
        _showLocationDialog('Platform error getting location: ${e.message}');
      }
    } catch (e) {
      setState(() {
        _isLoadingLocation = false;
      });
      _showLocationDialog('Error getting location: $e');
    }
  }

  void _addUserLocationMarker() {
    if (_currentPosition != null) {
      setState(() {
        _markers.add(
          Marker(
            markerId: const MarkerId('user_location'),
            position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
            infoWindow: const InfoWindow(
              title: 'Your Location',
              snippet: 'You are here',
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          ),
        );
      });
    }
  }

  void _showLocationDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Location Access'),
          content: Text(message),
          actions: [
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _animateToPosition(double lat, double lng) async {
    if (_mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(lat, lng),
            zoom: 16.0,
          ),
        ),
      );
    }
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
    };
  }

  void _onMapTypeButtonPressed() {
    setState(() {
      _currentMapType = _currentMapType == MapType.normal
          ? MapType.satellite
          : MapType.normal;
    });
  }

  void _centerOnUserLocation() {
    if (_currentPosition != null) {
      _animateToPosition(_currentPosition!.latitude, _currentPosition!.longitude);
    } else {
      _getCurrentLocation();
    }
  }

  void _toggleSearchBar() {
    setState(() {
      _showSearchBar = !_showSearchBar;
      if (!_showSearchBar) {
        _searchResults.clear();
        _searchController.clear();
      }
    });
  }

  // [Include all your other existing methods...]

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          GoogleMap(
            mapType: _currentMapType,
            initialCameraPosition: _kGooglePlex,
            markers: _markers,
            polygons: _polygons,
            polylines: _polylines,
            onMapCreated: (GoogleMapController controller) {
              _controller.complete(controller);
              _mapController = controller;
            },
            onTap: (LatLng location) {
              setState(() {
                _markers.add(Marker(
                  markerId: MarkerId('tapped_${_markers.length}'),
                  position: location,
                  infoWindow: InfoWindow(
                    title: 'New Location',
                    snippet: 'Lat: ${location.latitude.toStringAsFixed(4)}, Lng: ${location.longitude.toStringAsFixed(4)}',
                  ),
                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                ));
              });
            },
            zoomControlsEnabled: false,
            compassEnabled: false,
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            trafficEnabled: false,
            buildingsEnabled: true,
          ),

          // Top Left Controls Container
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Back Button
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: Colors.black),
                    iconSize: 24,
                  ),
                ),

                const SizedBox(height: 12),

                // Google Earth View Toggle Button
                Container(
                  decoration: BoxDecoration(
                    color: _currentMapType == MapType.satellite ? Colors.blue : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    onPressed: _onMapTypeButtonPressed,
                    icon: Icon(
                      _currentMapType == MapType.normal ? Icons.satellite_alt : Icons.map,
                      color: _currentMapType == MapType.satellite ? Colors.white : Colors.black,
                    ),
                    iconSize: 24,
                    tooltip: _currentMapType == MapType.satellite ? 'Normal View' : 'Satellite View',
                  ),
                ),

                const SizedBox(height: 12),

                // Coin Flip Widget
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(6),
                  child: CoinFlipWidget(
                    frontImagePath: 'assets/images/coin_heads.png',
                    backImagePath: 'assets/images/coin_tails.png',
                    onFlipComplete: _onCoinFlipComplete,
                  ),
                ),
              ],
            ),
          ),

          // [Keep all your existing positioned widgets - search bar, ride status, etc.]
          // Search Bar
          if (_showSearchBar)
            Positioned(
              top: 100,
              left: 16,
              right: 16,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) {
                        // Implement your search logic here
                      },
                      decoration: const InputDecoration(
                        hintText: 'Search places, addresses, landmarks...',
                        border: InputBorder.none,
                        prefixIcon: Icon(Icons.search, color: Colors.grey),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Bottom Control Panel
          Positioned(
            bottom: _waypoints.isEmpty && !_isRideActive ? 150 : _isRideActive ? 120 : 200,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Location button
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    onPressed: _isLoadingLocation ? null : _centerOnUserLocation,
                    icon: _isLoadingLocation
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : const Icon(Icons.my_location, color: Colors.blue),
                    iconSize: 24,
                  ),
                ),

                // Search toggle button (hide during ride)
                if (!_isRideActive)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: _showSearchBar ? Colors.blue : Colors.black,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: IconButton(
                      onPressed: _toggleSearchBar,
                      icon: const Icon(Icons.search, color: Colors.white),
                      iconSize: 24,
                    ),
                  ),
              ],
            ),
          ),

          // Bottom Sheet Handle (Uber-style)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 120,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Handle
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Content
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: _isRideActive ? Colors.green.shade100 : Colors.grey[100],
                              borderRadius: BorderRadius.circular(25),
                            ),
                            child: Icon(
                              _isRideActive ? Icons.directions_car : Icons.location_on,
                              color: _isRideActive ? Colors.green : Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _isRideActive ? 'Ride Active' : 'Current Location',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _isRideActive && _activeDestination != null
                                      ? 'To ${_activeDestination!.name}'
                                      : _currentPosition != null
                                      ? 'Lat: ${_currentPosition!.latitude.toStringAsFixed(4)}, Lng: ${_currentPosition!.longitude.toStringAsFixed(4)}'
                                      : 'Getting location...',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
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

// Data classes (keep your existing ones)
class Waypoint {
  final String id;
  final String name;
  final LatLng position;

  Waypoint({
    required this.id,
    required this.name,
    required this.position,
  });
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
