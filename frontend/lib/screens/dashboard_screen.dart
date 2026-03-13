import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../models/permit.dart';
import 'permit_detail_screen.dart';

class DashboardScreen extends StatefulWidget {
  final void Function(String? statusFilter)? onStatTap;
  const DashboardScreen({super.key, this.onStatTap});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _stats;
  List<Permit> _recent = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final api = ApiService();
      final statsRes = await api.getDashboardStats();
      final recentRes = await api.getDashboardRecent();
      if (mounted) {
        setState(() {
          _stats = statsRes.data['stats'];
          _recent = (recentRes.data['permits'] as List).map((e) => Permit.fromJson(e)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user!;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF4FC3F7)));
    }

    return RefreshIndicator(
      onRefresh: () async {
        setState(() => _isLoading = true);
        await _loadData();
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Greeting
          Text(
            'Welcome, Safety First! 👋',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            '${user.roleLabel} • ${user.department ?? 'No Department'}',
            style: const TextStyle(color: Colors.white54),
          ),
          const SizedBox(height: 24),

          // Stats grid
          if (_stats != null) _buildStatsGrid(),
          const SizedBox(height: 24),

          // Recent permits
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Recent Permits', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              Text('${_recent.length} permits', style: const TextStyle(color: Colors.white38, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          if (_recent.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.description_outlined, size: 48, color: Colors.white24),
                    const SizedBox(height: 12),
                    const Text('No permits yet', style: TextStyle(color: Colors.white38)),
                  ],
                ),
              ),
            )
          else
            ..._recent.map((p) => _buildPermitCard(p)),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    final stats = _stats!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 600 ? 4 : 2;
        return GridView.count(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.6,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _StatCard(title: 'Active', value: stats['active']?.toString() ?? '0', icon: Icons.check_circle_outline, color: const Color(0xFF66BB6A), onTap: () => widget.onStatTap?.call('approved')),
            _StatCard(title: 'Pending', value: stats['pending']?.toString() ?? '0', icon: Icons.hourglass_empty, color: const Color(0xFFFFB74D), onTap: () => widget.onStatTap?.call('submitted')),
            _StatCard(title: 'Rejected', value: stats['rejected']?.toString() ?? '0', icon: Icons.cancel_outlined, color: const Color(0xFFEF5350), onTap: () => widget.onStatTap?.call('rejected')),
            _StatCard(title: 'Total', value: stats['total']?.toString() ?? '0', icon: Icons.folder_outlined, color: const Color(0xFF4FC3F7), onTap: () => widget.onStatTap?.call(null)),
          ],
        );
      },
    );
  }

  Widget _buildPermitCard(Permit p) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PermitDetailScreen(permitId: p.id))),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _getStatusColor(p.status).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(p.typeIcon, style: const TextStyle(fontSize: 24)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.permitNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(p.typeLabel, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    if (p.applicantName != null)
                      Text(p.applicantName!, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                  ],
                ),
              ),
              _StatusBadge(status: p.status, label: p.statusLabel),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'approved':
      case 'active':
        return const Color(0xFF66BB6A);
      case 'rejected':
        return const Color(0xFFEF5350);
      case 'submitted':
      case 'k3_filled':
      case 'k3_umum_approved':
      case 'mill_assistant_approved':
        return const Color(0xFFFFB74D);
      case 'draft':
        return const Color(0xFF78909C);
      default:
        return const Color(0xFF4FC3F7);
    }
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _StatCard({required this.title, required this.value, required this.icon, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF162A3E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const Spacer(),
                Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
              ],
            ),
            const SizedBox(height: 4),
            Text(title, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  final String label;

  const _StatusBadge({required this.status, required this.label});

  Color get _color {
    switch (status) {
      case 'approved':
      case 'active':
        return const Color(0xFF66BB6A);
      case 'rejected':
        return const Color(0xFFEF5350);
      case 'submitted':
      case 'k3_filled':
      case 'k3_umum_approved':
      case 'mill_assistant_approved':
        return const Color(0xFFFFB74D);
      case 'draft':
        return const Color(0xFF78909C);
      default:
        return const Color(0xFF4FC3F7);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withValues(alpha: 0.3)),
      ),
      child: Text(label, style: TextStyle(color: _color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}
