import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/location_service.dart';

class LiveTrackingScreen extends StatefulWidget {
  final String sosId;
  final String victimName;
  final String coordinates;
  final double victimLatitude;
  final double victimLongitude;

  const LiveTrackingScreen({
    Key? key,
    required this.sosId,
    required this.victimName,
    required this.coordinates,
    required this.victimLatitude,
    required this.victimLongitude,
  }) : super(key: key);

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
  final MapController _mapController = MapController();
  StreamSubscription<Position>? _positionSubscription;
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _startLocationUpdates();
  }

  Future<void> _startLocationUpdates() async {
    final initialPosition = await LocationService.getCurrentPosition();
    if (!mounted) return;

    if (initialPosition != null) {
      setState(() {
        _currentPosition = initialPosition;
      });
      _fitRoute();
    }

    final positionStream = await LocationService.getPositionStream();
    if (!mounted || positionStream == null) return;

    _positionSubscription = positionStream.listen((position) {
      if (!mounted) return;
      setState(() {
        _currentPosition = position;
      });
      _fitRoute();
    });
  }

  void _fitRoute() {
    final responderLocation = _responderLocation;
    if (responderLocation == null) return;

    try {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints([responderLocation, _victimLocation]),
          padding: const EdgeInsets.all(56),
        ),
      );
    } catch (_) {
      // The map controller is not ready during the first GPS callback.
    }
  }

  String get _displayCoordinates {
    final position = _currentPosition;
    if (position == null) return widget.coordinates;

    return '${position.latitude.toStringAsFixed(5)}, '
        '${position.longitude.toStringAsFixed(5)}';
  }

  LatLng get _victimLocation =>
      LatLng(widget.victimLatitude, widget.victimLongitude);

  LatLng? get _responderLocation {
    final position = _currentPosition;
    if (position == null) return null;
    return LatLng(position.latitude, position.longitude);
  }

  String get _victimCoordinates =>
      '${widget.victimLatitude.toStringAsFixed(5)}, '
      '${widget.victimLongitude.toStringAsFixed(5)}';

  Future<void> _openNavigation() async {
    debugPrint('NAVIGATION ARROW TAPPED');

    final latitude = Uri.encodeQueryComponent(widget.victimLatitude.toString());
    final longitude = Uri.encodeQueryComponent(
      widget.victimLongitude.toString(),
    );
    final navigationUri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude',
    );

    var launched = false;
    try {
      launched = await launchUrl(
        navigationUri,
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      launched = false;
    }

    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to open Google Maps'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Live Tracking: ${widget.victimName}'),
        backgroundColor: AppColors.headerBlue,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _victimLocation,
              initialZoom: 14,
              onMapReady: _fitRoute,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.resq.app',
              ),
              if (_responderLocation != null)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [_responderLocation!, _victimLocation],
                      color: AppColors.headerBlue,
                      strokeWidth: 5,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _victimLocation,
                    width: 48,
                    height: 48,
                    child: const Icon(
                      Icons.warning_rounded,
                      color: AppColors.primary,
                      size: 42,
                    ),
                  ),
                  if (_responderLocation != null)
                    Marker(
                      point: _responderLocation!,
                      width: 48,
                      height: 48,
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _openNavigation,
                          child: Transform.rotate(
                            angle:
                                (_currentPosition?.heading ?? 0) *
                                math.pi /
                                180,
                            child: const Icon(
                              Icons.navigation_rounded,
                              color: AppColors.headerBlue,
                              size: 42,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tracking Victim: ${widget.victimName}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text('SOS: ${widget.sosId}'),
                    Text('Responder: $_displayCoordinates'),
                    Text('Victim: $_victimCoordinates'),
                    const SizedBox(height: 4),
                    const Text(
                      'Blue line: responder route to victim',
                      style: TextStyle(color: AppColors.headerBlue),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom Action Navigation Bar
          Positioned(
            bottom: 24,
            left: 20,
            right: 20,
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(
                      Icons.person_pin_circle_rounded,
                      color: AppColors.primary,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.victimName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const Text(
                            'Distance: 0.8 km • Multi-hop Mesh Beacon',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Marked ${widget.victimName} as Rescued!',
                            ),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      },
                      child: const Text('Mark Rescued'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
