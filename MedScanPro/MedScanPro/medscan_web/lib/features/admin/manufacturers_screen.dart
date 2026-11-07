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
              final data = docs[index].data();
              final id = docs[index].id;
              final status = data['status'] ?? 'pending';
              
              return Card(
                child: ListTile(
                  title: Text(data['name'] ?? 'Unknown'),
                  subtitle: Text('Email:  | Status: '),
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
