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
      skipLoadingOnReload: true,
      loading: () => Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(backgroundColor: Colors.white, elevation: 0),
        body: Container(color: Colors.white),
      ),
      error: (err, stack) => Scaffold(body: Center(child: Text('Error: $err'))),
      data: (profile) {
        final devices = profile?['assignedDevices'] as List<dynamic>? ?? [];
        final baseMillName = profile?['millName'] ?? 'Rice Mill';

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            titleSpacing: 16.0,
            centerTitle: false,
            backgroundColor: Colors.white,
            elevation: 0,
            title: Text(
              baseMillName,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black,
                fontSize: 22,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              // Circular Logo Badge (Right side, close to notifications)
              Padding(
                padding: const EdgeInsets.only(right: 8.0, top: 6.0, bottom: 6.0),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey.shade50,
                    border: Border.all(color: Colors.teal.shade300, width: 1.5),
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/GPlogo.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              // Circular Notifications Badge (Right side)
              Padding(
                padding: const EdgeInsets.only(right: 12.0, top: 6.0, bottom: 6.0),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.blue.shade50,
                    border: Border.all(color: Colors.blue.shade200, width: 1.5),
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.notifications_none,
                      color: Colors.blue,
                      size: 22,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const NotificationsScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
          body: devices.isEmpty
              ? const Center(child: Text('No devices assigned.'))
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
