import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/permit_provider.dart';
import '../models/permit.dart';
import 'permit_detail_screen.dart';

class PermitListScreen extends StatefulWidget {
  final String? initialStatusFilter;
  const PermitListScreen({super.key, this.initialStatusFilter});

  @override
  State<PermitListScreen> createState() => _PermitListScreenState();
}

class _PermitListScreenState extends State<PermitListScreen> {
  String? _filterStatus;
  String? _filterType;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filterStatus = widget.initialStatusFilter;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PermitProvider>().loadPermits(status: _filterStatus);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _applyFilters() {
    context.read<PermitProvider>().loadPermits(
      status: _filterStatus,
      type: _filterType,
      search: _searchController.text.isEmpty ? null : _searchController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PermitProvider>();

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search permits...',
              prefixIcon: const Icon(Icons.search, color: Colors.white38),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_searchController.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        _applyFilters();
                      },
                    ),
                  IconButton(
                    icon: const Icon(Icons.filter_list),
                    onPressed: _showFilterSheet,
                  ),
                ],
              ),
            ),
            onSubmitted: (_) => _applyFilters(),
          ),
        ),

        // Filter chips
        if (_filterStatus != null || _filterType != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                if (_filterStatus != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Chip(
                      label: Text(_filterStatus!, style: const TextStyle(fontSize: 12)),
                      onDeleted: () {
                        setState(() => _filterStatus = null);
                        _applyFilters();
                      },
                      deleteIconColor: Colors.white54,
                      backgroundColor: const Color(0xFF1C2F42),
                      side: const BorderSide(color: Color(0xFF2A4056)),
                    ),
                  ),
                if (_filterType != null)
                  Chip(
                    label: Text(_filterType!, style: const TextStyle(fontSize: 12)),
                    onDeleted: () {
                      setState(() => _filterType = null);
                      _applyFilters();
                    },
                    deleteIconColor: Colors.white54,
                    backgroundColor: const Color(0xFF1C2F42),
                    side: const BorderSide(color: Color(0xFF2A4056)),
                  ),
              ],
            ),
          ),

        // List
        Expanded(
          child: provider.isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF4FC3F7)))
              : provider.permits.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.description_outlined, size: 64, color: Colors.white24),
                          const SizedBox(height: 16),
                          const Text('No permits found', style: TextStyle(color: Colors.white38, fontSize: 16)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () => provider.loadPermits(status: _filterStatus, type: _filterType),
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: provider.permits.length,
                        itemBuilder: (context, index) => _buildPermitTile(provider.permits[index]),
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildPermitTile(Permit p) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => PermitDetailScreen(permitId: p.id)));
          if (mounted) _applyFilters();
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(p.typeIcon, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(p.permitNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  _StatusBadge(status: p.status, label: p.statusLabel),
                ],
              ),
              const SizedBox(height: 8),
              Text(p.typeLabel, style: const TextStyle(color: Color(0xFF4FC3F7), fontSize: 13)),
              const SizedBox(height: 4),
              Text(p.workLocation, style: const TextStyle(color: Colors.white54, fontSize: 12),
                maxLines: 1, overflow: TextOverflow.ellipsis),
              if (p.applicantName != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.person_outline, size: 14, color: Colors.white38),
                      const SizedBox(width: 4),
                      Text(p.applicantName!, style: const TextStyle(color: Colors.white38, fontSize: 12)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF162A3E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Filter Permits', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              const Text('Status', style: TextStyle(color: Colors.white54, fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ['draft', 'submitted', 'k3_filled', 'k3_umum_approved', 'approved', 'rejected', 'active'].map((s) {
                  return ChoiceChip(
                    label: Text(s),
                    selected: _filterStatus == s,
                    selectedColor: const Color(0xFF4FC3F7),
                    backgroundColor: const Color(0xFF1C2F42),
                    onSelected: (sel) {
                      setSheetState(() => _filterStatus = sel ? s : null);
                      setState(() {});
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              const Text('Type', style: TextStyle(color: Colors.white54, fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ('confined_space', '🕳️ Confined Space'),
                  ('working_at_height', '🪜 Height'),
                  ('excavation', '⛏️ Excavation'),
                  ('electrical', '⚡ Electrical'),
                  ('hot_work', '🔥 Hot Work'),
                ].map((t) {
                  return ChoiceChip(
                    label: Text(t.$2),
                    selected: _filterType == t.$1,
                    selectedColor: const Color(0xFF4FC3F7),
                    backgroundColor: const Color(0xFF1C2F42),
                    onSelected: (sel) {
                      setSheetState(() => _filterType = sel ? t.$1 : null);
                      setState(() {});
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _applyFilters();
                  },
                  child: const Text('Apply Filters'),
                ),
              ),
            ],
          ),
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
