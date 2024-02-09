import 'dart:async';
import 'dart:developer' as l;
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  LocationData? currentLocation;
  LocationData? destinationLocation;
  Location location = Location();
  Location destLocObj = Location();
  late StreamSubscription<LocationData> _locationSubscription;
  late StreamSubscription<LocationData> _destLocationSubscription;

  LatLng destinationLatLang = const LatLng(28.6124794, 77.3590908);
  LatLng currentlatLang = const LatLng(28.6124794, 77.3590908);
  double circleRadius = 100;

  Set<Marker> markers = {};
  @override
  void initState() {
    super.initState();
    requestLocationPermission().then((permissionStatus) async {
      if (permissionStatus == PermissionStatus.granted) {
        initializeData();
      } else {
        l.log("Location permission not granted");
        showSnack();
      }
    });
  }

  initializeData() async {
    await loadSavedData();
    await getCurrentLocation();
  }

  @override
  void dispose() {
    super.dispose();
    _locationSubscription.cancel();
    _destLocationSubscription.cancel();
  }

  bool isEnabled = false;
  double newDistance = 0.0;

  Future<void> getCurrentLocation() async {
    PermissionStatus permissionStatus = await requestLocationPermission();
    if (permissionStatus != PermissionStatus.granted) {
      showSnack();
    } else {
      await location.getLocation().then((value) {
        setState(() {
          currentLocation = value;
          addCurrentLocMarker(currentLocation!);
          currentlatLang =
              LatLng(currentLocation!.latitude!, currentLocation!.longitude!);
        });
      });

      _locationSubscription = location.onLocationChanged.listen((newLoc) async {
        setState(() {
          currentLocation = newLoc;
          addCurrentLocMarker(newLoc);
        });

        var distanceBetween = haversineDistance(
            LatLng(newLoc.latitude!, newLoc.longitude!), destinationLatLang);
        setState(() {
          newDistance = distanceBetween;
        });

        if (distanceBetween < circleRadius) {
          setState(() {
            isEnabled = true;
          });
        } else {
          setState(() {
            isEnabled = false;
          });
        }
      });
    }
  }

  Future<void> getDestinationLocation() async {
    PermissionStatus permissionStatus = await requestLocationPermission();
    if (permissionStatus == PermissionStatus.granted) {
      try {
        await destLocObj.getLocation().then((value) {
          setState(() {
            destinationLocation = value;
            destinationLatLang = LatLng(
              destinationLocation!.latitude!,
              destinationLocation!.longitude!,
            );
            l.log("destination location: $destinationLatLang");
          });
        });
        setState(() {});
      } catch (e) {
        l.log("Error getting destination location: $e");
        showSnack();
      }
    } else {
      l.log("Destination Location permission not granted");
      showSnack();
    }
  }

  void addCurrentLocMarker(LocationData locationData) {
    markers.removeWhere((marker) =>
        marker.point.latitude == locationData.latitude &&
        marker.point.longitude == locationData.longitude);

    markers.add(Marker(
      width: 80.0,
      height: 80.0,
      point: LatLng(locationData.latitude!, locationData.longitude!),
      child: const Icon(
        Icons.location_on,
        size: 50.0,
        color: Colors.blue,
      ),
    ));
  }

  double haversineDistance(LatLng p1, LatLng p2) {
    double lat1 = p1.latitude;
    double lon1 = p1.longitude;
    double lat2 = p2.latitude;
    double lon2 = p2.longitude;

    var R = 6371e3;
    var phi1 = (lat1 * pi) / 180;
    var phi2 = (lat2 * pi) / 180;
    var deltaPhi = ((lat2 - lat1) * pi) / 180;
    var deltaLambda = ((lon2 - lon1) * pi) / 180;

    var a = sin(deltaPhi / 2) * sin(deltaPhi / 2) +
        cos(phi1) * cos(phi2) * sin(deltaLambda / 2) * sin(deltaLambda / 2);

    var c = 2 * atan2(sqrt(a), sqrt(1 - a));

    var d = R * c;

    return d;
  }

  Future<void> loadSavedData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    double savedRadius = prefs.getDouble('radius') ?? 100;
    double savedLat = prefs.getDouble('latitude') ?? 28.6124794;
    double savedLng = prefs.getDouble('longitude') ?? 77.3590908;
    double savedDestLat = prefs.getDouble('destLatitude') ?? 28.6124794;
    double savedDestLng = prefs.getDouble('destLongitude') ?? 77.3590908;
    setState(() {
      circleRadius = savedRadius;

      currentlatLang = LatLng(savedLat, savedLng);
      destinationLatLang = LatLng(savedDestLat, savedDestLng);
    });
    l.log("curr:=> $currentlatLang");
  }

  Future<void> saveRadius(radius) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('radius', radius);
  }

  Future<void> saveCurrentLocation() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('latitude', currentLocation?.latitude ?? 0);
    await prefs.setDouble('longitude', currentLocation?.longitude ?? 0);
    setState(() {});
    l.log("Current location: $currentLocation");
  }

  Future<void> saveDestinationLocation() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('destLatitude', destinationLatLang.latitude);
    await prefs.setDouble('destLongitude', destinationLatLang.longitude);
    l.log("saved Destination: $destinationLocation");
  }

  bool serviceEnabled = false;

  Future<PermissionStatus> requestLocationPermission() async {
    PermissionStatus permissionStatus = await location.hasPermission();
    try {
      serviceEnabled = await location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await location.requestService();
        if (!serviceEnabled) {
          l.log("Location service not enabled");
          showSnack();
        }
      }

      if (permissionStatus == PermissionStatus.denied) {
        permissionStatus = await location.requestPermission();
        if (permissionStatus != PermissionStatus.granted) {
          l.log("Permission not granted");
          showSnack();
          return permissionStatus;
        }
      } else {
        return permissionStatus;
      }
    } catch (e) {
      return permissionStatus;
    }
    return permissionStatus;
  }

  showSnack() {
    return ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Location Permission not granted.")));
  }

  bool isSavingLoc = false;
  TextEditingController radiusController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: currentLocation == null || isSavingLoc
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.5,
                    child: FlutterMap(
                      mapController: MapController(),
                      options: MapOptions(
                        initialCenter: LatLng(currentLocation!.latitude!,
                            currentLocation!.longitude!),
                        initialZoom: 15.0,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              "https://a.tile.openstreetmap.org/{z}/{x}/{y}.png",
                        ),
                        CircleLayer(
                          circles: [
                            CircleMarker(
                              point: destinationLatLang,
                              radius: circleRadius,
                              useRadiusInMeter: true,
                              color: Colors.green.withOpacity(0.4),
                            ),
                          ],
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              width: 80.0,
                              height: 80.0,
                              point: currentlatLang,
                              child: const Icon(
                                Icons.location_on,
                                size: 30,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: [currentlatLang, destinationLatLang],
                              strokeWidth: 2.0,
                              color: Colors.blue,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: radiusController,
                            decoration: const InputDecoration(
                                labelText: 'Enter Radius'),
                            keyboardType: TextInputType.number,
                            onChanged: (value) {
                              setState(() {
                                circleRadius = double.tryParse(value) ?? 100;
                              });
                            },
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            setState(() {
                              circleRadius =
                                  double.tryParse(radiusController.text) ?? 100;
                              isSavingLoc = true;
                            });

                            await saveRadius(circleRadius).then((_) async {
                              await loadSavedData();
                            });
                            setState(() {
                              isSavingLoc = false;
                            });
                          },
                          child: const Text('Save'),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: ElevatedButton(
                      onPressed: () async {
                        setState(() {
                          isSavingLoc = true;
                        });
                        await getDestinationLocation();
                        await saveDestinationLocation();
                        setState(() {
                          isSavingLoc = false;
                        });
                      },
                      child: const Text('Save College Location'),
                    ),
                  ),
                  Text(
                      "Current Loc: ${currentLocation!.latitude} -- ${currentLocation!.longitude}"),
                  Text(
                      "Destination Loc: ${destinationLatLang.latitude} -- ${destinationLatLang.longitude}"),
                  Text("Distance: $newDistance meters"),
                  Text("Radius: $circleRadius meters"),
                  ElevatedButton(
                    onPressed: isEnabled ? () {} : null,
                    child:
                        Text(isEnabled ? "Mark Attendance" : "Not in campus"),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      setState(() {
                        currentLocation = null;
                      });
                      await loadSavedData();
                      await getCurrentLocation();
                    },
                    child: const Text("Refresh Location"),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }
}
