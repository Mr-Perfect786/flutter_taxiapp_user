import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_user/pages/loadingPage/loading.dart';
import 'package:flutter_user/styles/styles.dart';
import 'package:flutter_user/translations/translation.dart';
import 'package:flutter_user/widgets/widgets.dart';

import '../../functions/functions.dart';

class OnGoingRides extends StatefulWidget {
  const OnGoingRides({super.key});

  @override
  State<OnGoingRides> createState() => _OnGoingRidesState();
}

class _OnGoingRidesState extends State<OnGoingRides> {
  dynamic _shimmer;
  bool _isLoading = false;
  Set<Polyline> _polylines = {};
  List<LatLng> _polylineCoordinates = [];
  late LatLng _driverLocation;
  late LatLng _pickupLocation;

  @override
  void initState() {
    getHistoryData();
    _shimmer = AnimationController.unbounded(vsync: MyTickerProvider())
      ..repeat(min: -0.5, max: 1.5, period: const Duration(milliseconds: 1000));
    super.initState();
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  // Polyline fetching method using Google Directions API
  Future<void> _getPolyline() async {
    const String googleAPIKey = 'AIzaSyBUB-XEC_v0HTMTozMwsHAzaBsaerE-x24';
    String url = 'https://maps.googleapis.com/maps/api/directions/json?'
        'origin=${_driverLocation.latitude},${_driverLocation.longitude}'
        '&destination=${_pickupLocation.latitude},${_pickupLocation.longitude}'
        '&key=$googleAPIKey';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        Map<String, dynamic> data = json.decode(response.body);

        if (data['routes'] != null && data['routes'].isNotEmpty) {
          var points = data['routes'][0]['overview_polyline']['points'];
          _polylineCoordinates = _decodePolyline(points);

          setState(() {
            _polylines.add(Polyline(
              polylineId: PolylineId('route'),
              points: _polylineCoordinates,
              color: Colors.blue,
              width: 5,
            ));
          });
        } else {
          debugPrint('No routes found in the Directions API response.');
        }
      } else {
        debugPrint('Directions API error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching polyline: $e');
    }
  }

  // Polyline decoder method
  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> polylineCoordinates = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      polylineCoordinates.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return polylineCoordinates;
  }

  // Initialize pickup and driver locations
  getHistoryData() async {
    setState(() {
      _isLoading = true;
      myHistoryPage.clear();
      myHistory.clear();
    });

    // Example pickup and driver coordinates, replace with actual data
    _pickupLocation = LatLng(12.9715987, 77.5945627);
    _driverLocation = LatLng(12.9718915, 77.6411545);

    await _getPolyline(); // Fetch and draw the route

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    var media = MediaQuery.of(context).size;

    return Material(
      child: RefreshIndicator(
        color: Colors.blue,
        onRefresh: () async {
          setState(() {
            _isLoading = true;
            myHistoryPage.clear();
            myHistory.clear();
          });
          historyFiltter = 'on_trip=1';
          await getHistory();
          setState(() {
            _isLoading = false;
          });
        },
        child: Directionality(
          textDirection: (languageDirection == 'rtl')
              ? TextDirection.rtl
              : TextDirection.ltr,
          child: Stack(
            children: [
              Column(
                children: [
                  Container(
                    padding: EdgeInsets.fromLTRB(
                        media.width * 0.05,
                        media.width * 0.05 + MediaQuery.of(context).padding.top,
                        media.width * 0.05,
                        media.width * 0.05),
                    color: page,
                    child: Row(
                      children: [
                        InkWell(
                          onTap: () {
                            Navigator.pop(context);
                          },
                          child: Icon(Icons.arrow_back_ios, color: textColor),
                        ),
                        Expanded(
                          child: MyText(
                            textAlign: TextAlign.center,
                            text: languages[choosenLanguage]
                                ['text_ongoing_rides'],
                            size: media.width * twenty,
                            maxLines: 1,
                            fontweight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(1),
                      width: media.width * 1,
                      color: (myHistory.isEmpty)
                          ? (!isDarkTheme)
                              ? Colors.white
                              : Colors.black
                          : (isDarkTheme)
                              ? Colors.grey
                              : Colors.grey.withOpacity(0.2),
                      child: GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: _pickupLocation,
                          zoom: 14,
                        ),
                        polylines: _polylines,
                        onMapCreated: (GoogleMapController controller) {},
                      ),
                    ),
                  ),
                ],
              ),
              // Loading Indicator
              (_isLoading == true)
                  ? const Positioned(top: 0, child: Loading())
                  : Container()
            ],
          ),
        ),
      ),
    );
  }
}
