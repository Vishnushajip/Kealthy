import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../Login/login_page.dart';
import '../Maps/SelectAdress.dart';
import '../Orders/ordersTab.dart';

class UserProfile {
  final String name;

  UserProfile({required this.name});
}

class UserProfileNotifier extends StateNotifier<UserProfile> {
  UserProfileNotifier() : super(UserProfile(name: 'User')) {
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    final prefs = await SharedPreferences.getInstance();
    String savedName = prefs.getString('Name') ?? 'User';
    state = UserProfile(name: savedName);
  }
}

final userProfileProvider =
    StateNotifierProvider<UserProfileNotifier, UserProfile>(
  (ref) => UserProfileNotifier(),
);

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  Future<void> _clearPreferencesAndNavigate(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove('phoneNumber');

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginFields()),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userName = ref.watch(userProfileProvider).name;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            CircleAvatar(
              radius: 50,
              backgroundColor: Colors.white,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Color(0xFF273847), width: 2),
                ),
                child: Center(
                  child: Text(
                    userName.isNotEmpty ? userName[0].toUpperCase() : 'K',
                    style: const TextStyle(
                      fontSize: 40,
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              userName,
              style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ListView(
                children: [
                  _buildMenuItem(
                    context,
                    Icons.location_on_outlined,
                    'My Address',
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SelectAdress(totalPrice: 0),
                      ),
                    ),
                  ),
                  _buildMenuItem(
                    context,
                    Icons.shopping_bag_outlined,
                    'Orders',
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const OrdersTabScreen(),
                      ),
                    ),
                  ),
                  _buildMenuItem(
                    context,
                    Icons.exit_to_app,
                    'Logout',
                    () => _clearPreferencesAndNavigate(context),
                  ),
                  _buildMenuItem(
                    context,
                    Icons.article,
                    "Terms and conditions",
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const OrdersTabScreen(),
                      ),
                    ),
                  ),
                  _buildMenuItem(
                    context,
                    Icons.article,
                    "Help & Support",
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const OrdersTabScreen(),
                      ),
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(
      BuildContext context, IconData icon, String title, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Color(0xFF273847),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.white),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        trailing: const Icon(Icons.chevron_right, color: Colors.white),
        onTap: onTap,
      ),
    );
  }
}
