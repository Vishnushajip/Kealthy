import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:kealthy/Maps/Delivery_details.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:shimmer/shimmer.dart';
import '../Services/placesuggetions.dart';
import 'package:fluttertoast/fluttertoast.dart';

final currentlocationProviders =
    StateNotifierProvider<LocationNotifier, Position?>((ref) {
  return LocationNotifier(ref);
});

final mapControllerProvider =
    StateProvider<GoogleMapController?>((ref) => null);
final suggestionsProvider = StateProvider<List<String>>((ref) {
  return [];
});

final selectedPositionProvider = StateProvider<LatLng?>((ref) => null);
final isFetchingLocationProvider = StateProvider<bool>((ref) => false);

final isSearchingProvider = StateProvider<bool>((ref) => false);

final addressProvider = StateProvider<String?>((ref) => null);
final selectedLocationProvider = StateProvider<String?>((ref) => null);
final isLoadingProvider = StateProvider<bool>((ref) => false);

class LocationNotifier extends StateNotifier<Position?> {
  LatLng? _selectedPosition;
  final Ref ref;

  LocationNotifier(this.ref) : super(null) {
    Future.microtask(() => _getCurrentLocation());
  }

  LatLng? get selectedPosition => _selectedPosition;

  set selectedPosition(LatLng? position) {
    _selectedPosition = position;
  }

  Future<void> _getCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      if (permission == LocationPermission.deniedForever) return;
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        forceAndroidLocationManager: true,
        timeLimit: const Duration(seconds: 30),
      );
      state = position;
      final LatLng latLngPosition =
          LatLng(position.latitude, position.longitude);
      ref.read(selectedPositionProvider.notifier).state = latLngPosition;
      await _updateAddress(latLngPosition);
    } catch (e) {
      print('Error getting location: $e');
    }
  }

  Future<void> _updateAddress(LatLng position) async {
    try {
      final List<Placemark> placemarks =
          await placemarkFromCoordinates(position.latitude, position.longitude);

      if (placemarks.isNotEmpty) {
        final Placemark placemark = placemarks.first;

        final List<String?> addressComponents = [
          placemark.subLocality,
          placemark.street,
          placemark.postalCode,
          placemark.locality,
          placemark.administrativeArea,
          placemark.country,
        ];
        final address = addressComponents
            .where((component) => component != null && component.isNotEmpty)
            .toSet()
            .join(", ");
        ref.read(addressProvider.notifier).state = address;
      }
    } catch (e) {
      print('Error in reverse geocoding: $e');
    }
  }

  Future<void> suggestLocations(String query) async {
    try {
      final List<Location> locations = await locationFromAddress(query);
      if (locations.isNotEmpty) {
        final suggestions = await Future.wait(locations.map((location) async {
          final placemarks = await placemarkFromCoordinates(
            location.latitude,
            location.longitude,
          );
          if (placemarks.isNotEmpty) {
            final placemark = placemarks.first;
            return "${placemark.street ?? ''} ${placemark.administrativeArea ?? ''} ${placemark.country ?? ''}";
          }
          return '';
        }).toList());

        ref.read(suggestionsProvider.notifier).state = suggestions;
      } else {
        ref.read(suggestionsProvider.notifier).state = [];
      }
    } catch (e) {
      print('Error in getting suggestions: $e');
    }
  }

  Future<void> searchLocation(String placeId) async {
    try {
      ref.read(isSearchingProvider.notifier).state = true;
      final response = await http.get(Uri.parse(
          'https://maps.googleapis.com/maps/api/place/details/json?placeid=$placeId&key=AIzaSyD1MUoakZ0mm8WeFv_GK9k_zAWdGk5r1hA'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'OK' && data['result'] != null) {
          final geometry = data['result']['geometry'];
          final location = geometry['location'];
          final LatLng position = LatLng(location['lat'], location['lng']);

          final GoogleMapController? controller =
              ref.read(mapControllerProvider);
          if (controller != null) {
            await controller.animateCamera(CameraUpdate.newCameraPosition(
              CameraPosition(
                target: position,
                zoom: 18.0,
              ),
            ));
            await _updateAddress(position);
          }
        } else {
          print(
              'Error in searching location: Could not find any result for the supplied address or coordinates.');
        }
      } else {
        print('Failed to fetch place details');
      }
    } catch (e) {
      print('Error in searching location: $e');
    } finally {
      ref.read(isSearchingProvider.notifier).state = false;
    }
  }

  Future<String?> formatAddress(Position? position) async {
    if (position == null) return null;
    try {
      final placemarks =
          await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        final place = placemarks[0];
        return "${place.street ?? ''} ${place.administrativeArea ?? ''} ${place.country ?? ''}";
      } else {
        return "Address not found";
      }
    } catch (e) {
      print('Error in reverse geocoding: $e');
      return "Error getting address";
    }
  }
}

class SelectLocationPage extends ConsumerStatefulWidget {
  final double totalPrice;

  const SelectLocationPage({
    super.key,
    required this.totalPrice,
  });

  @override
  ConsumerState<SelectLocationPage> createState() => _LocationPageState();
}

class _LocationPageState extends ConsumerState<SelectLocationPage> {
  late TextEditingController _searchController;
  static const LatLng restaurantLocation = LatLng(10.064555, 76.322242);

  double calculateDistance(LatLng start, LatLng end) {
    return Geolocator.distanceBetween(
      start.latitude,
      start.longitude,
      end.latitude,
      end.longitude,
    );
  }

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    ref.read(currentlocationProviders.notifier)._getCurrentLocation();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentPosition = ref.watch(currentlocationProviders);
    final selectedPosition = ref.watch(selectedPositionProvider);
    final address = ref.watch(addressProvider);
    final placeSuggestions = ref.watch(placeSuggestionsProvider);
    final isFetchingLoaction = ref.watch(isFetchingLocationProvider);
    double? distanceToRestaurant;

    if (currentPosition == null) {
      print(
          'currentPosition is null. Location might still be loading or not available.');
    }

    if (selectedPosition == null) {
      print(
          'selectedPosition is null. The user might not have selected a location yet.');
    }

    if (currentPosition != null && selectedPosition != null) {
      distanceToRestaurant = calculateDistance(
        selectedPosition,
        restaurantLocation,
      );
      print('Distance to restaurant: $distanceToRestaurant meters');
    } else if (currentPosition == null && selectedPosition == null) {
      print('Either currentPosition or selectedPosition is null');
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        title: const Text('Confirm delivery location'),
      ),
      body: currentPosition != null
          ? Stack(
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height,
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: LatLng(
                        currentPosition.latitude,
                        currentPosition.longitude,
                      ),
                      zoom: 18.0,
                    ),
                    onMapCreated: (controller) {
                      ref.read(mapControllerProvider.notifier).state =
                          controller;
                    },
                    onCameraMove: (position) {
                      ref.read(selectedPositionProvider.notifier).state =
                          position.target;
                    },
                    onCameraIdle: () {
                      final targetPosition = ref.read(selectedPositionProvider);
                      if (targetPosition != null) {
                        ref
                            .read(currentlocationProviders.notifier)
                            ._updateAddress(targetPosition);
                      }
                    },
                    myLocationButtonEnabled: false,
                    myLocationEnabled: false,
                    mapType: MapType.terrain,
                    mapToolbarEnabled: true,
                  ),
                ),
                Positioned(
                  top: MediaQuery.of(context).size.height * 0.65 / 2 - 25,
                  left: MediaQuery.of(context).size.width / 2 - 25,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/location_icon.png',
                        width: 50,
                      ),
                    ],
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(16.0),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(10.0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 8.0,
                          offset: Offset(0, -2),
                        )
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 10, right: 10),
                          child: Row(
                            children: [
                              const Text(
                                'DELIVERING YOUR ORDER TO',
                                style: TextStyle(
                                  color: Colors.blue,
                                  fontFamily: 'Poppins',
                                  fontSize: 12,
                                ),
                              ),
                              const Spacer(),
                              SizedBox(
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10)),
                                      side: const BorderSide(
                                          color: Color(0xFF273847))),
                                  onPressed: () async {
                                    ref
                                        .read(
                                            isFetchingLocationProvider.notifier)
                                        .state = true;
                                    await ref
                                        .read(currentlocationProviders.notifier)
                                        ._getCurrentLocation();

                                    final currentPosition =
                                        ref.read(currentlocationProviders);

                                    if (currentPosition != null) {
                                      ref
                                          .read(
                                              currentlocationProviders.notifier)
                                          .selectedPosition = LatLng(
                                        currentPosition.latitude,
                                        currentPosition.longitude,
                                      );

                                      final controller =
                                          ref.read(mapControllerProvider);
                                      if (controller != null) {
                                        await controller.animateCamera(
                                          CameraUpdate.newCameraPosition(
                                            CameraPosition(
                                              target: LatLng(
                                                currentPosition.latitude,
                                                currentPosition.longitude,
                                              ),
                                              zoom: 18.0,
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                    ref
                                        .read(
                                            isFetchingLocationProvider.notifier)
                                        .state = false;
                                  },
                                  child: isFetchingLoaction
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            color: Color(0xFF273847),
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.my_location,
                                          color: Color(0xFF273847)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8.0),
                        address != null
                            ? Row(
                                children: [
                                  Image.asset(
                                    'assets/location_icon.png',
                                    width: 40,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      address,
                                      style: const TextStyle(
                                        color: Colors.black,
                                        fontFamily: 'Poppins',
                                        fontSize: 20,
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : Shimmer.fromColors(
                                baseColor: Colors.grey[300]!,
                                highlightColor: Colors.grey[100]!,
                                child: Container(
                                  width: double.infinity,
                                  height: 20,
                                  color: Colors.white,
                                ),
                              ),
                        const SizedBox(height: 20),
                        Align(
                          alignment: Alignment.center,
                          child: SizedBox(
                            width: MediaQuery.of(context).size.width * 0.85,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: () async {
                                final selectedPosition =
                                    ref.watch(selectedPositionProvider);

                                if (selectedPosition != null) {
                                  final distance = calculateDistance(
                                    LatLng(selectedPosition.latitude,
                                        selectedPosition.longitude),
                                    restaurantLocation,
                                  );

                                  if (distance > 20000) {
                                    Fluttertoast.showToast(
                                      msg: "Location not serviceable.",
                                      toastLength: Toast.LENGTH_SHORT,
                                      gravity: ToastGravity.BOTTOM,
                                    );
                                    return;
                                  }

                                  final prefs =
                                      await SharedPreferences.getInstance();
                                  await prefs.setDouble(
                                      'latitude', selectedPosition.latitude);
                                  await prefs.setDouble(
                                      'longitude', selectedPosition.longitude);

                                  _showAddressFormBottomSheet(context);
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFF273847),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(5),
                                ),
                              ),
                              child: const Text(
                                'Add more address details',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'Poppins',
                                  fontSize: 18,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: MediaQuery.of(context).size.height * 0.01,
                  left: 16.0,
                  right: 16.0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10.0),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8.0,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 40,
                                  child: TextField(
                                    cursorHeight: 20,
                                    controller: _searchController,
                                    onChanged: (value) {
                                      if (value.isNotEmpty) {
                                        ref
                                            .read(currentlocationProviders
                                                .notifier)
                                            .searchLocation(
                                              value,
                                            );
                                        ref
                                            .read(placeSuggestionsProvider
                                                .notifier)
                                            .fetchPlaceSuggestions(value);
                                      } else {
                                        ref
                                            .read(placeSuggestionsProvider
                                                .notifier)
                                            // ignore: invalid_use_of_protected_member
                                            .state = [];
                                      }
                                    },
                                    decoration: const InputDecoration(
                                      hintText: 'Search location',
                                      hintStyle: TextStyle(
                                        fontSize: 15,
                                        color: Colors.black38,
                                      ),
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.only(left: 16),
                                    ),
                                    style: const TextStyle(
                                      fontSize: 16.0,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8.0),
                              ref.watch(isSearchingProvider)
                                  ? const SizedBox(
                                      width: 24.0,
                                      height: 24.0,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.0,
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ],
                          ),
                          const SizedBox(height: 8.0),
                          if (placeSuggestions.isNotEmpty &&
                              _searchController.text.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Column(
                                children: placeSuggestions.map((suggestion) {
                                  final suggestionName =
                                      suggestion['description'];

                                  return ListTile(
                                    title:
                                        Text(suggestionName ?? 'Unknown Place'),
                                    onTap: () async {
                                      _searchController.text =
                                          suggestionName ?? '';
                                      ref
                                          .read(
                                              placeSuggestionsProvider.notifier)
                                          // ignore: invalid_use_of_protected_member
                                          .state = [];
                                      final placeId = suggestion['placeId'];
                                      await ref
                                          .read(
                                              currentlocationProviders.notifier)
                                          .searchLocation(
                                            placeId,
                                          );
                                    },
                                  );
                                }).toList(),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            )
          : Center(
              child: LoadingAnimationWidget.discreteCircle(
                color: Color(0xFF273847),
                size: 70,
              ),
            ),
    );
  }

  void _showAddressFormBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: const AddressForm(
          totalPrice: 0,
        ),
      ),
    );
  }
}
