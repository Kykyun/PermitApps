import 'package:flutter/material.dart';
import 'forms/confined_space_form.dart';
import 'forms/hot_work_form.dart';
import 'forms/working_at_height_form.dart';

class PermitFormScreen extends StatelessWidget {
  const PermitFormScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Permit Type'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'What type of work permit do you need?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Please select the permit type first before filling out the form.',
              style: TextStyle(color: Colors.white54, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            _buildTypeCard(
              context,
              '🕳️ Confined Space',
              'Entry into tanks, vessels, manholes, or vaults.',
              const Color(0xFFE57373),
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ConfinedSpaceForm())),
            ),
            const SizedBox(height: 16),
            _buildTypeCard(
              context,
              '🔥 Hot Work',
              'Welding, cutting, grinding, or using open flames.',
              const Color(0xFFFFB74D),
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HotWorkForm())),
            ),
            const SizedBox(height: 16),
            _buildTypeCard(
              context,
              '🪜 Working at Height',
              'Working on roofs, scaffolding, or elevated platforms.',
              const Color(0xFF64B5F6),
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WorkingAtHeightForm())),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeCard(BuildContext context, String title, String subtitle, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1C2F42),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF2A4056)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.description, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 13, color: Colors.white54),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white54),
          ],
        ),
      ),
    );
  }
}
