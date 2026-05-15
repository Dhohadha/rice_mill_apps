import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../services/providers.dart';
import '../widgets/device_page.dart';
import 'notifications_screen.dart';

class MonitoringScreen extends ConsumerStatefulWidget {
  const MonitoringScreen({super.key});

  @override
  ConsumerState<MonitoringScreen> createState() => _MonitoringScreenState();
}

class _MonitoringScreenState extends ConsumerState<MonitoringScreen> {
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userProfile = ref.watch(userProfileProvider);

    return userProfile.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) => Scaffold(body: Center(child: Text('Error: $err'))),
      data: (profile) {
        final devices = profile?['assignedDevices'] as List<dynamic>? ?? [];
        final baseMillName = profile?['millName'] ?? 'Rice Mill Lite';

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: Text(
              baseMillName,
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 18),
            ),
            centerTitle: true,
            backgroundColor: Colors.white,
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications_none, color: Colors.blue, size: 28),
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
                },
              ),
            ],
          ),
          body: devices.isEmpty
              ? const Center(child: Text('No devices configured.'))
              : Column(
                  children: [
                    if (devices.length > 1)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: SmoothPageIndicator(
                          controller: _pageController,
                          count: devices.length,
                          effect: const WormEffect(
                            dotHeight: 8,
                            dotWidth: 8,
                            activeDotColor: Colors.teal,
                            dotColor: Colors.black12,
                          ),
                        ),
                      ),
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: devices.length,
                        itemBuilder: (context, index) {
                          return DevicePage(
                            deviceId: devices[index],
                            millName: baseMillName,
                          );
                        },
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}
