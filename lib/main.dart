import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: LocationScreen(),
    );
  }
}

class LocationScreen extends StatefulWidget {
  @override
  _LocationScreenState createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  String locationMessage = "Last known location not available";
  String addressMessage = "Address not available";
  String? selectedCity;
  double? distanceToTargetCity;

  // Coordinates of target cities
  final Map<String, LatLng> cityCoordinates = {
    "Chicago": LatLng(41.8781, -87.6298),
    "New York": LatLng(40.7128, -74.0060),
    "Paris": LatLng(48.8566, 2.3522),
    "Singapore": LatLng(1.3521, 103.8198),
  };

  @override
  void initState() {
    super.initState();
    _getLastKnownLocation();
  }

  // Retrieve the user's last known location
  Future<void> _getLastKnownLocation() async {
    try {
      Position? position = await Geolocator.getLastKnownPosition();
      if (position != null) {
        setState(() {
          locationMessage = "Lat: ${position.latitude}, Long: ${position.longitude}";
        });
        _getAddressFromLatLng(position.latitude, position.longitude);
      } else {
        // Prompt the user to fetch the current location if no last known location is available
        bool? shouldFetch = await _promptUserForCurrentLocation();
        if (shouldFetch == true) {
          _getCurrentLocation();
        } else {
          setState(() {
            locationMessage = "Location access denied by user";
          });
        }
      }
    } catch (e) {
      // Handle the error here (e.g., show a message to the user)
      // setState(() {
      //   locationMessage = "Failed to retrieve last known location: ${e.toString()}";
      // });
      print("Error occurred while fetching last known location: $e");
      bool? shouldFetch = await _promptUserForCurrentLocation();
      if (shouldFetch == true) {
        _getCurrentLocation();
      }else {
        setState(() {
          locationMessage = "Location access denied by user";
        });
      }
    }
  }


  // Prompt user to fetch the current location
  Future<bool?> _promptUserForCurrentLocation() async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Location Not Found"),
        content: Text("No last known location is available. Would you like to get the current location?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text("No"),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text("Yes"),
          ),
        ],
      ),
    );
  }

  // Fetch current location if user consents
  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // 检查位置服务是否开启
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      return;
    }

    // 检查位置权限
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return;
    }
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    // Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    setState(() {
      locationMessage = "Lat: ${position.latitude}, Long: ${position.longitude}";
    });
    _getAddressFromLatLng(position.latitude, position.longitude);
  }

  // Retrieve address information based on latitude and longitude
  Future<void> _getAddressFromLatLng(double latitude, double longitude) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        setState(() {
          addressMessage = "${place.locality}, ${place.country}";
        });
      }
    } catch (e) {
      print(e);
    }
  }

  // Calculate distance from the last known location to the target city
  Future<void> _calculateDistanceToTargetCity() async {
    Position? lastKnownPosition = await Geolocator.getLastKnownPosition();
    if (selectedCity != null && lastKnownPosition != null && cityCoordinates.containsKey(selectedCity)) {
      LatLng targetCityCoords = cityCoordinates[selectedCity]!;
      double distanceInMeters = Geolocator.distanceBetween(
        lastKnownPosition.latitude,
        lastKnownPosition.longitude,
        targetCityCoords.latitude,
        targetCityCoords.longitude,
      );

      setState(() {
        distanceToTargetCity = distanceInMeters / 1000; // Convert to kilometers
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Location & Distance Calculator'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '1. Last Known Location:',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              locationMessage,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20),
            ),
            SizedBox(height: 10),
            Text(
              addressMessage,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            Text(
              '2. Target City:',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            CityPicker(
              selectedCity: selectedCity,
              onCitySelected: (city) {
                setState(() {
                  selectedCity = city;
                  distanceToTargetCity = null; // Reset distance when a new city is selected
                });
                _calculateDistanceToTargetCity();
              },
            ),
            SizedBox(height: 20),
            Text(
              '3. Distance:',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (distanceToTargetCity != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  'Distance to $selectedCity: ${distanceToTargetCity!.toStringAsFixed(2)} km',
                  style: TextStyle(fontSize: 20),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// Define LatLng class
class LatLng {
  final double latitude;
  final double longitude;

  LatLng(this.latitude, this.longitude);
}

// CityPicker widget
class CityPicker extends StatefulWidget {
  final String? selectedCity;
  final Function(String) onCitySelected;

  CityPicker({required this.onCitySelected, this.selectedCity});

  @override
  _CityPickerState createState() => _CityPickerState();
}

class _CityPickerState extends State<CityPicker> {
  String? selectedCity;

  final List<String> cities = ["Chicago", "New York", "Paris", "Singapore"];

  @override
  void initState() {
    super.initState();
    selectedCity = widget.selectedCity;
  }

  @override
  Widget build(BuildContext context) {
    return DropdownButton<String>(
      hint: Text("Select a city"),
      value: selectedCity,
      items: cities.map((String city) {
        return DropdownMenuItem<String>(
          value: city,
          child: Text(city),
        );
      }).toList(),
      onChanged: (String? newValue) {
        setState(() {
          selectedCity = newValue;
        });
        if (newValue != null) {
          widget.onCitySelected(newValue);
        }
      },
    );
  }
}
