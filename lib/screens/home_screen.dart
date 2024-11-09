import 'dart:async';
import 'dart:ui';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:weather/weather.dart';
import 'package:weather_app/bloc/weather_bloc_bloc.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String salutation = '';
  DateTime currentDateTime = DateTime.now();
  Timer? _timer;
  StreamSubscription? connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _updateSalutation();
    _startRealTimeUpdates();
    _initializeLocationAndWeather();
    _setupConnectivityListener();
    _setupLocationServiceListener();
  }

  @override
  void dispose() {
    _timer?.cancel();
    connectivitySubscription?.cancel();
    super.dispose();
  }

  void _setupConnectivityListener() {
    connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      if (results.isEmpty || results.contains(ConnectivityResult.none)) {
        _showErrorSnackBar(
            'No internet connection. Please check your connectivity.');
      } else {
        _fetchWeatherData(); // Refresh data when connection is restored
      }
    });
  }

  void _setupLocationServiceListener() {
    Geolocator.getServiceStatusStream().listen((ServiceStatus status) {
      if (status == ServiceStatus.disabled) {
        _showErrorSnackBar(
            'Location services are disabled. Please enable location for accurate weather data.');
      } else if (status == ServiceStatus.enabled) {
        _fetchWeatherData(); // Refresh data when location is enabled
      }
    });
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _initializeLocationAndWeather() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        _showErrorSnackBar(
            'Location services are disabled. Please enable location to use the app.');
        // Update the bloc state to show location disabled message
        context.read<WeatherBlocBloc>().add(const LocationDisabled());
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showPermissionDeniedError();
          context.read<WeatherBlocBloc>().add(const LocationPermissionDenied());
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showPermanentlyDeniedError();
        context
            .read<WeatherBlocBloc>()
            .add(const LocationPermissionDeniedForever());
        return;
      }

      await _fetchWeatherData();
    } catch (e) {
      _showErrorSnackBar('An error occurred while initializing the app');
    }
  }

  void _showLocationServiceDisabledError() {
    _showErrorSnackBar(
        'Location services are disabled. Please enable location to use the app.');
    Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      SystemNavigator.pop(); // Close the app
    });
  }

  void _showPermissionDeniedError() {
    _showErrorSnackBar(
        'Location permission denied. The app requires location access to function.');
    Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      SystemNavigator.pop(); // Close the app
    });
  }

  void _showPermanentlyDeniedError() {
    _showErrorSnackBar(
      'Location permission permanently denied. Please enable it in settings to use the app.',
    );
    Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      SystemNavigator.pop(); // Close the app
    });
  }

  void _startRealTimeUpdates() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        currentDateTime = DateTime.now();
        _updateSalutation();
      });
    });
  }

  void _updateSalutation() {
    int hour = currentDateTime.hour;
    if (hour < 12) {
      salutation = 'Good Morning';
    } else if (hour < 17) {
      salutation = 'Good Afternoon';
    } else {
      salutation = 'Good Evening';
    }
  }

  Future<void> _fetchWeatherData() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        _showErrorSnackBar(
            'No internet connection. Please check your connectivity.');
        return;
      }

      Position position = await _determinePosition();
      if (!mounted) return;
      context.read<WeatherBlocBloc>().add(FetchWeather(position));
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Failed to fetch weather data. Please try again.');
    }
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showLocationServiceDisabledError();
      throw Exception('Location services are disabled.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showPermissionDeniedError();
        throw Exception('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showPermanentlyDeniedError();
      throw Exception('Location permissions are permanently denied');
    }

    return await Geolocator.getCurrentPosition();
  }

  Widget getWeatherIcon(int code) {
    switch (code) {
      case >= 200 && < 300:
        return Image.asset('assets/1.png');
      case >= 300 && < 400:
        return Image.asset('assets/2.png');
      case >= 500 && < 600:
        return Image.asset('assets/3.png');
      case >= 600 && < 700:
        return Image.asset('assets/4.png');
      case >= 700 && < 800:
        return Image.asset('assets/5.png');
      case 800:
        return Image.asset('assets/6.png');
      case > 800 && <= 804:
        return Image.asset('assets/7.png');
      default:
        return Image.asset('assets/1.png');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarBrightness: Brightness.dark,
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchWeatherData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height,
            child: Padding(
              padding:
                  const EdgeInsets.fromLTRB(40, 1.2 * kToolbarHeight, 40, 20),
              child: Stack(
                children: [
                  Align(
                    alignment: const AlignmentDirectional(3, -0.3),
                    child: Container(
                      height: 300,
                      width: 300,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.deepPurple,
                      ),
                    ),
                  ),
                  Align(
                    alignment: const AlignmentDirectional(-3, -0.3),
                    child: Container(
                      height: 300,
                      width: 300,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.deepPurple,
                      ),
                    ),
                  ),
                  Align(
                    alignment: const AlignmentDirectional(0, -1.2),
                    child: Container(
                      height: 300,
                      width: 600,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFAB40),
                      ),
                    ),
                  ),
                  BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
                    child: Container(
                      decoration:
                          const BoxDecoration(color: Colors.transparent),
                    ),
                  ),
                  BlocBuilder<WeatherBlocBloc, WeatherBlocState>(
                    builder: (context, state) {
                      if (state is WeatherBlocSuccess) {
                        return SizedBox(
                          width: MediaQuery.of(context).size.width,
                          height: MediaQuery.of(context).size.height,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '📍 ${state.weather.areaName}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w300,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                salutation,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 25,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              getWeatherIcon(
                                  state.weather.weatherConditionCode!),
                              Center(
                                child: Text(
                                  '${state.weather.temperature!.celsius!.round()}°C',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 55,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Center(
                                child: Text(
                                  state.weather.weatherMain!.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 25,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 5),
                              Center(
                                child: Text(
                                  DateFormat('EEEE dd • hh:mm a')
                                      .format(currentDateTime),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w300,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 30),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildSunInfo(
                                    'Sunrise',
                                    'assets/11.png',
                                    state.weather.sunrise!,
                                  ),
                                  _buildSunInfo(
                                    'Sunset',
                                    'assets/12.png',
                                    state.weather.sunset!,
                                  ),
                                ],
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 5),
                                child: Divider(color: Colors.grey),
                              ),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildTempInfo(
                                    'Temp Max',
                                    'assets/13.png',
                                    state.weather.tempMax!,
                                  ),
                                  _buildTempInfo(
                                    'Temp Min',
                                    'assets/14.png',
                                    state.weather.tempMin!,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      } else if (state is WeatherBlocLoading) {
                        return const Center(child: CircularProgressIndicator());
                      } else if (state is WeatherBlocLocationDisabled) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset(
                                'assets/location_disabled.png', // Add this asset or use any other appropriate image
                                width: 100,
                                height: 100,
                                color: Colors.white,
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                'Location Services Disabled',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'Please enable location services\nto see weather information',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton(
                                onPressed: () async {
                                  await Geolocator.openLocationSettings();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.deepPurple,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 12),
                                ),
                                child: const Text('Open Settings'),
                              ),
                            ],
                          ),
                        );
                      } else if (state is WeatherBlocLocationDenied) {
                        return const Center(
                          child: Text(
                            'Location permission denied.\nPlease enable location access to use the app.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white),
                          ),
                        );
                      } else if (state is WeatherBlocLocationDeniedForever) {
                        return const Center(
                          child: Text(
                            'Location permission permanently denied.\nPlease enable it in settings to use the app.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white),
                          ),
                        );
                      } else if (state is WeatherBlocFailure) {
                        return const Center(
                          child: Text(
                            'Failed to load weather data',
                            style: TextStyle(color: Colors.white),
                          ),
                        );
                      } else {
                        return Container();
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSunInfo(String label, String iconPath, DateTime time) {
    return Row(
      children: [
        Image.asset(iconPath, scale: 8),
        const SizedBox(width: 5),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w300)),
            const SizedBox(height: 3),
            Text(DateFormat().add_jm().format(time),
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ],
        ),
      ],
    );
  }

  Widget _buildTempInfo(String label, String iconPath, Temperature temp) {
    return Row(
      children: [
        Image.asset(iconPath, scale: 8),
        const SizedBox(width: 5),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w300)),
            const SizedBox(height: 3),
            Text('${temp.celsius!.round()}°C',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ],
        ),
      ],
    );
  }
}
