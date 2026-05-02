import 'package:google_maps_flutter/google_maps_flutter.dart';

class RouteRiddleQuestion {
  final String name;
  final String city;
  final List<LatLng> points;
  final double actualDistanceKm;
  final List<double> options; // 3 distance choices in km
  final String funFact;

  const RouteRiddleQuestion({
    required this.name,
    required this.city,
    required this.points,
    required this.actualDistanceKm,
    required this.options,
    required this.funFact,
  });
}

/// Famous marathon and iconic running routes.
/// Points are simplified polylines (not full GPS detail).
final List<RouteRiddleQuestion> kRouteRiddleBank = [
  const RouteRiddleQuestion(
    name: 'Berlin Marathon',
    city: 'Berlin, Germany',
    actualDistanceKm: 42.195,
    options: [21.1, 42.2, 10.0],
    funFact: 'Berlin is the world record course — Eliud Kipchoge ran 2:01:09 here in 2022.',
    points: [
      LatLng(52.5147, 13.3497),
      LatLng(52.5180, 13.3780),
      LatLng(52.5163, 13.4050),
      LatLng(52.5080, 13.4230),
      LatLng(52.4960, 13.4370),
      LatLng(52.4820, 13.4450),
      LatLng(52.4730, 13.4200),
      LatLng(52.4880, 13.3930),
      LatLng(52.4980, 13.3700),
      LatLng(52.5060, 13.3420),
      LatLng(52.5147, 13.3497),
    ],
  ),
  const RouteRiddleQuestion(
    name: 'Boston Marathon',
    city: 'Boston, USA',
    actualDistanceKm: 42.195,
    options: [42.2, 26.2, 50.0],
    funFact: 'The Boston Marathon is the world\'s oldest annual marathon, first run in 1897.',
    points: [
      LatLng(42.3094, -71.4997),
      LatLng(42.3199, -71.4550),
      LatLng(42.3311, -71.4103),
      LatLng(42.3380, -71.3601),
      LatLng(42.3350, -71.3099),
      LatLng(42.3300, -71.2602),
      LatLng(42.3301, -71.2099),
      LatLng(42.3380, -71.1602),
      LatLng(42.3495, -71.1119),
      LatLng(42.3550, -71.0780),
    ],
  ),
  const RouteRiddleQuestion(
    name: 'Parkrun 5K',
    city: 'Hyde Park, London',
    actualDistanceKm: 5.0,
    options: [3.0, 5.0, 10.0],
    funFact: 'Parkrun started in 2004 with just 13 runners. Now over 2 million people parkrun weekly worldwide.',
    points: [
      LatLng(51.5073, -0.1580),
      LatLng(51.5090, -0.1550),
      LatLng(51.5110, -0.1510),
      LatLng(51.5130, -0.1480),
      LatLng(51.5110, -0.1440),
      LatLng(51.5085, -0.1460),
      LatLng(51.5073, -0.1520),
      LatLng(51.5073, -0.1580),
    ],
  ),
  const RouteRiddleQuestion(
    name: 'Tokyo Marathon',
    city: 'Tokyo, Japan',
    actualDistanceKm: 42.195,
    options: [42.2, 21.1, 30.0],
    funFact: 'Tokyo Marathon is one of the Six World Major Marathons with over 38,000 runners.',
    points: [
      LatLng(35.6803, 139.6925),
      LatLng(35.6780, 139.7010),
      LatLng(35.6720, 139.7100),
      LatLng(35.6650, 139.7200),
      LatLng(35.6590, 139.7300),
      LatLng(35.6530, 139.7400),
      LatLng(35.6478, 139.7490),
      LatLng(35.6540, 139.7580),
      LatLng(35.6620, 139.7520),
      LatLng(35.6700, 139.7450),
    ],
  ),
  const RouteRiddleQuestion(
    name: 'Comrades Ultra',
    city: 'KwaZulu-Natal, SA',
    actualDistanceKm: 89.0,
    options: [42.2, 89.0, 60.0],
    funFact: 'Comrades is the world\'s largest and oldest ultramarathon — run since 1921.',
    points: [
      LatLng(-29.5920, 30.3790),
      LatLng(-29.5500, 30.3200),
      LatLng(-29.5000, 30.2600),
      LatLng(-29.4500, 30.2000),
      LatLng(-29.4000, 30.1400),
      LatLng(-29.8630, 31.0218),
    ],
  ),
];
