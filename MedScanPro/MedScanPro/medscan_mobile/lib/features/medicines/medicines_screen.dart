import 'package:flutter/material.dart';
import '../../shared/widgets/app_bar.dart';
import '../../shared/widgets/empty_state.dart';

class MedicinesScreen extends StatelessWidget {
  const MedicinesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Medicines'),
      body: const EmptyState(
        message: 'No medicines added yet.',
        icon: Icons.medical_services_outlined,
      ),
    );
  }
}
