import os

base_path = r'd:\medscan\MedScanPro\medscan_web\lib'

files = {
    'features/admin/admin_shell.dart': '''
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_providers.dart';

class AdminShell extends ConsumerWidget {
  final Widget child;
  const AdminShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isDesktop = MediaQuery.of(context).size.width >= 800;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Portal - MedScan Pro'),
        backgroundColor: Colors.red.shade800,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authRepositoryProvider).logout(),
          )
        ],
      ),
      drawer: isDesktop ? null : Drawer(child: _buildNavigation(context)),
      body: Row(
        children: [
          if (isDesktop) 
            SizedBox(width: 250, child: _buildNavigation(context)),
          if (isDesktop) const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _buildNavigation(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        DrawerHeader(
          decoration: BoxDecoration(color: Colors.red.shade900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: const [
              Text('MedScan Pro', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('System Administrator', style: TextStyle(color: Colors.white70)),
            ],
          ),
        ),
        _navItem(context, Icons.dashboard, 'Dashboard', '/admin/dashboard'),
        _navItem(context, Icons.people, 'Users', '/admin/users'),
        _navItem(context, Icons.factory, 'Manufacturers', '/admin/manufacturers'),
        _navItem(context, Icons.medication, 'Medicines', '/admin/medicines'),
        _navItem(context, Icons.layers, 'Batches', '/admin/batches'),
        const Divider(),
        _navItem(context, Icons.verified_user, 'Verification Records', '/admin/verification'),
        _navItem(context, Icons.report, 'Reports', '/admin/reports'),
        _navItem(context, Icons.warning, 'Alerts', '/admin/alerts'),
        _navItem(context, Icons.analytics, 'Analytics', '/admin/analytics'),
        const Divider(),
        _navItem(context, Icons.list_alt, 'Audit Logs', '/admin/audit'),
        _navItem(context, Icons.settings, 'System Mgmt', '/admin/system'),
      ],
    );
  }

  Widget _navItem(BuildContext context, IconData icon, String title, String route) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      onTap: () {
        if (Scaffold.of(context).isDrawerOpen) Navigator.pop(context);
        context.go(route);
      },
    );
  }
}
''',
    'features/admin/admin_screens.dart': '''
import 'package:flutter/material.dart';

class AdminPlaceholderScreen extends StatelessWidget {
  final String title;
  const AdminPlaceholderScreen(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 16),
            const Text('Secure Administrative View', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
''',
    'features/admin/manufacturers_screen.dart': '''
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

final adminManufacturersProvider = StreamProvider((ref) {
  return FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'manufacturer').snapshots();
});

class AdminManufacturersScreen extends ConsumerWidget {
  const AdminManufacturersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(adminManufacturersProvider);

    return Scaffold(
      body: asyncData.when(
        data: (snapshot) {
          final docs = snapshot.docs;
          if (docs.isEmpty) return const Center(child: Text('No manufacturers found.'));
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final id = docs[index].id;
              final status = data['status'] ?? 'pending';
              
              return Card(
                child: ListTile(
                  title: Text(data['name'] ?? 'Unknown'),
                  subtitle: Text('Email: \${data['email']} | Status: \$status'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (status != 'approved')
                        TextButton(
                          child: const Text('Approve', style: TextStyle(color: Colors.green)),
                          onPressed: () => FirebaseFirestore.instance.collection('users').doc(id).update({'status': 'approved'}),
                        ),
                      if (status == 'approved')
                        TextButton(
                          child: const Text('Suspend', style: TextStyle(color: Colors.red)),
                          onPressed: () => FirebaseFirestore.instance.collection('users').doc(id).update({'status': 'suspended'}),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
'''
}

for filepath, content in files.items():
    full_path = os.path.join(base_path, filepath)
    os.makedirs(os.path.dirname(full_path), exist_ok=True)
    with open(full_path, 'w', encoding='utf-8') as f:
        f.write(content.strip() + '\\n')

print("Admin panel generated")
