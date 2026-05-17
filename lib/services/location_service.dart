import 'package:mindpilot/export.dart';

class LocationService {
  static Future<String?> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error(
        'Location permissions are permanently denied, we cannot request permissions.',
      );
    }

    try {
      Position position = await Geolocator.getCurrentPosition();
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        String? street = place.street;
        String? subLocality = place.subLocality;
        String? city = place.locality;
        String? state = place.administrativeArea;
        String? country = place.country;

        List<String> parts = [];
        if (street != null && street.isNotEmpty)
          parts.add(street);
        else if (subLocality != null && subLocality.isNotEmpty)
          parts.add(subLocality);

        if (city != null && city.isNotEmpty) parts.add(city);
        if (state != null && state.isNotEmpty) parts.add(state);
        if (country != null && country.isNotEmpty) parts.add(country);

        return parts.join(", ");
      }
      return "Unknown Location";
    } catch (e) {
      return Future.error("Error: $e");
    }
  }
}
