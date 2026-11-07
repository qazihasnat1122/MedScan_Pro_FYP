import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_providers.dart';
import '../../features/login/login_screen.dart';
import '../../services/operational_database_service.dart';

import '../../features/public/home_screen.dart';
import '../../features/public/medicines_screen.dart';
import '../../features/public/medicine_detail_screen.dart';
import '../../features/public/public_screens.dart';

import '../../features/manufacturer/manufacturer_shell.dart';
import '../../features/manufacturer/dashboard_screen.dart';
import '../../features/manufacturer/products_screen.dart';
import '../../features/manufacturer/add_product_screen.dart';
import '../../features/manufacturer/batches_screen.dart';
import '../../features/manufacturer/add_batch_screen.dart';
import '../../features/manufacturer/packaging_screen.dart';
import '../../features/manufacturer/add_packaging_screen.dart';
import '../../features/manufacturer/simple_screens.dart';

import '../../features/analytics/anomalies_screen.dart';
import '../../features/admin/admin_shell.dart';
import '../../features/admin/threat_map_screen.dart';
import '../../features/admin/admin_screens.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final routerRefreshNotifier = ValueNotifier<int>(0);
  ref.listen(authStateProvider, (previous, next) {
    routerRefreshNotifier.value++;
  });

  return GoRouter(
    initialLocation: '/',
    refreshListenable: routerRefreshNotifier,
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      
      final isLoggingIn = state.uri.path == '/login';
      final isPublic = state.uri.path == '/' || state.uri.path == '/medicines' || state.uri.path.startsWith('/medicine/') || state.uri.path == '/alerts' || state.uri.path == '/how-it-works' || state.uri.path == '/about' || state.uri.path == '/assets';
      
      if (authState.isLoading) return null;
      
      // Use synchronous session check to prevent race conditions during login
      final opSession = OperationalDatabaseService.instance.currentSession;
      final user = opSession ?? authState.value;
      
      if (user == null) {
        if (isPublic || isLoggingIn) return null;
        return '/login';
      }

      if (isLoggingIn) {
        // Allow logged in users to access the login screen to switch accounts or view options.
        return null;
      }

      // Allow switching between portals for demonstration purposes
      // if (path.startsWith('/admin') && role != null && role != 'admin') {
      //   return '/manufacturer/dashboard';
      // }

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const PublicHomeScreen(),
      ),
      GoRoute(
        path: '/medicines',
        builder: (context, state) => const MedicinesScreen(),
      ),
      GoRoute(
        path: '/medicine/:id',
        builder: (context, state) => MedicineDetailScreen(medicineId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/alerts',
        builder: (context, state) => const SafetyAlertsScreen(),
      ),
      GoRoute(
        path: '/how-it-works',
        builder: (context, state) => const HowItWorksScreen(),
      ),
      GoRoute(
        path: '/about',
        builder: (context, state) => const AboutScreen(),
      ),
      GoRoute(
        path: '/assets',
        builder: (context, state) => const BrandAssetsScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) {
          final intent = state.uri.queryParameters['intent'];
          return LoginScreen(initialIntent: intent);
        },
      ),

      GoRoute(
        path: '/unauthorized',
        builder: (context, state) => const Scaffold(body: Center(child: Text('Unauthorized Access'))),
      ),
      ShellRoute(
        builder: (context, state, child) => ManufacturerShell(child: child),
        routes: [
          GoRoute(path: '/manufacturer/dashboard', builder: (context, state) => const ManufacturerDashboard()),
          GoRoute(path: '/manufacturer/products', builder: (context, state) => const ProductsScreen()),
          GoRoute(path: '/manufacturer/add_product', builder: (context, state) => const AddProductScreen()),
          GoRoute(path: '/manufacturer/batches', builder: (context, state) => const BatchesScreen()),
          GoRoute(path: '/manufacturer/add_batch', builder: (context, state) => const AddBatchScreen()),
          GoRoute(path: '/manufacturer/packaging', builder: (context, state) => const PackagingScreen()),
          GoRoute(path: '/manufacturer/add_packaging', builder: (context, state) => const AddPackagingScreen()),
          GoRoute(path: '/manufacturer/verification', builder: (context, state) => const PlaceholderScreen('Verification Data')),
          GoRoute(path: '/manufacturer/scans', builder: (context, state) => const PlaceholderScreen('Scan Activity')),
          GoRoute(path: '/manufacturer/reports', builder: (context, state) => const PlaceholderScreen('Suspicious Reports')),
          GoRoute(path: '/manufacturer/alerts', builder: (context, state) => const PlaceholderScreen('Alerts')),
          GoRoute(path: '/manufacturer/analytics', builder: (context, state) => const AnomaliesScreen()),
          GoRoute(path: '/manufacturer/profile', builder: (context, state) => const PlaceholderScreen('Company Profile')),
          GoRoute(path: '/manufacturer/settings', builder: (context, state) => const PlaceholderScreen('Settings')),
        ],
      ),
      ShellRoute(
        builder: (context, state, child) => AdminShell(child: child),
        routes: [
          GoRoute(path: '/admin', redirect: (context, state) => '/admin/dashboard'),
          GoRoute(path: '/admin/dashboard', builder: (context, state) => const AdminPlaceholderScreen('Admin Dashboard')),
          GoRoute(path: '/admin/medicines', builder: (context, state) => const AdminPlaceholderScreen('Medicines')),
          GoRoute(path: '/admin/manufacturers', builder: (context, state) => const AdminPlaceholderScreen('Manufacturers')),
          GoRoute(path: '/admin/approvals', builder: (context, state) => const AdminPlaceholderScreen('Pending Approvals')),
          GoRoute(path: '/admin/threat-map', builder: (context, state) => const ThreatMapScreen()),
          GoRoute(path: '/admin/alerts', builder: (context, state) => const AdminPlaceholderScreen('System Alerts')),
          GoRoute(path: '/admin/reports', builder: (context, state) => const AdminPlaceholderScreen('Citizen Reports Triage')),
          GoRoute(path: '/admin/verification', builder: (context, state) => const AdminPlaceholderScreen('Verification Activity')),
          GoRoute(path: '/admin/users', builder: (context, state) => const AdminPlaceholderScreen('Authorized Users')),
          GoRoute(path: '/admin/audit', builder: (context, state) => const AdminPlaceholderScreen('Security Audit Log')),
          GoRoute(path: '/admin/settings', builder: (context, state) => const AdminPlaceholderScreen('Registry Settings')),
        ],
      ),
    ],
  );
});
