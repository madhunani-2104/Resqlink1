import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/constants/app_theme.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/profile/providers/profile_provider.dart';
import 'features/sos/providers/sos_provider.dart';
import 'features/mesh_chat/providers/mesh_chat_provider.dart';
import 'features/calling/call_service.dart';
import 'features/calling/call_screen.dart';
import 'features/map/providers/map_provider.dart';
import 'features/admin/providers/admin_provider.dart';
import 'features/settings/providers/settings_provider.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/rescue_login_screen.dart';
import 'features/auth/screens/rescue_register_screen.dart';
import 'features/home/screens/home_screen.dart';
import 'features/sos/screens/sos_screen.dart';
import 'features/mesh_chat/screens/mesh_chat_screen.dart';
import 'features/map/screens/live_map_screen.dart';
import 'features/admin/screens/admin_dashboard_screen.dart';
import 'features/rescue_team/screens/rescue_team_portal_screen.dart';
import 'features/profile/screens/profile_screen.dart';
import 'widgets/custom_bottom_nav.dart';

class ResQApp extends StatelessWidget {
  const ResQApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ProfileProvider()),
        ChangeNotifierProvider(create: (_) => SosProvider()),
        ChangeNotifierProvider(create: (_) => MapProvider()),
        ChangeNotifierProvider(create: (_) => AdminProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => CallProvider()),
        ChangeNotifierProxyProvider<AuthProvider, MeshChatProvider>(
          create: (ctx) => MeshChatProvider('USER-NODE-001'),
          update: (ctx, auth, previous) =>
              previous ?? MeshChatProvider(auth.user?.id ?? 'USER-NODE-001'),
        ),
      ],
      child: Consumer2<AuthProvider, SettingsProvider>(
        builder: (context, auth, settings, child) {
          return MaterialApp(
            title: 'ResQ Emergency System',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: settings.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            home: auth.isAuthenticated
                ? (auth.user?.role == 'rescue_team'
                    ? const RescueTeamPortalScreen()
                    : const MainNavigationContainer())
                : const LoginScreen(),
            routes: {
              RescueLoginScreen.routeName: (_) => const RescueLoginScreen(),
              RescueRegisterScreen.routeName: (_) => const RescueRegisterScreen(),
            },
          );
        },
      ),
    );
  }
}

class MainNavigationContainer extends StatefulWidget {
  const MainNavigationContainer({Key? key}) : super(key: key);

  @override
  State<MainNavigationContainer> createState() => _MainNavigationContainerState();
}

class _MainNavigationContainerState extends State<MainNavigationContainer> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      final userId = auth.user?.id ?? '';
      if (userId.isNotEmpty) {
        context.read<SosProvider>().connectUserEmergencyAlertStream(userId: userId);
        context.read<CallProvider>().connect(userId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      HomeScreen(
        onNavigateToSos: () => setState(() => _currentIndex = 3),
        onNavigateToChat: () => setState(() => _currentIndex = 1),
        onNavigateToMap: () => setState(() => _currentIndex = 2),
        onNavigateToAdmin: () {
          final role = context.read<AuthProvider>().user?.role;
          if (role != 'admin') return;
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
          );
        },
        onNavigateToRescueTeam: () {
          final role = context.read<AuthProvider>().user?.role;
          if (role != 'rescue_team') return;
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RescueTeamPortalScreen()),
          );
        },
      ),
      const MeshChatScreen(),
      const LiveMapScreen(),
      const SosScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: pages,
          ),
          const CallOverlay(),
        ],
      ),
      bottomNavigationBar: CustomBottomNav(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}
