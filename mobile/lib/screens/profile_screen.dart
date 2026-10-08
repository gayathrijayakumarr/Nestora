import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emergencyCtrl = TextEditingController();
  final _serverCtrl = TextEditingController();
  int _week = 28;
  String _due = 'Sep 15, 2026';
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SessionService.loadProfile();
    _nameCtrl.text = (p['name'] as String).isEmpty ? 'Priya' : p['name'] as String;
    _phoneCtrl.text = p['phone'] as String;
    _emergencyCtrl.text = p['emergency'] as String;
    _serverCtrl.text = await SessionService.loadServerIp();
    setState(() {
      _week = (p['week'] as int).clamp(1, 42);
      _due = p['due'] as String;
      _loading = false;
    });
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty || _phoneCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name and phone are required')),
      );
      return;
    }
    setState(() => _saving = true);
    await SessionService.saveProfile(
      name: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      week: _week,
      due: _due,
      emergency: _emergencyCtrl.text.trim(),
    );
    await SessionService.saveServerIp(_serverCtrl.text);
    await ApiService.loadBase();
    setState(() => _saving = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profile saved'),
        backgroundColor: Color(0xFFFF2D95),
        behavior: SnackBarBehavior.floating,
      ),
    );
    Navigator.of(context).pop(true);
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('Your local profile will be cleared.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Log out',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    await SessionService.clear();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emergencyCtrl.dispose();
    _serverCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8FC),
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF14142B),
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 44,
                          backgroundColor:
                              const Color(0xFFFF2D95).withValues(alpha: 0.12),
                          child: Text(
                            _nameCtrl.text.isEmpty
                                ? '?'
                                : _nameCtrl.text[0].toUpperCase(),
                            style: const TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFFF2D95)),
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text('Mother Profile',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF14142B))),
                        Text('Patient ID: P001',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _field(_nameCtrl, 'Full Name', Icons.person_outline,
                      TextInputType.text),
                  const SizedBox(height: 12),
                  _field(_phoneCtrl, 'Phone Number', Icons.phone_outlined,
                      TextInputType.phone),
                  const SizedBox(height: 12),
                  _field(_emergencyCtrl, 'Emergency Contact',
                      Icons.contact_phone_outlined, TextInputType.phone),
                  const SizedBox(height: 12),
                  _field(_serverCtrl, 'Server IP (e.g. 10.248.54.151)',
                      Icons.dns_outlined, TextInputType.number),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: const Color(0xFFFFD3E7)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Gestational Week',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14)),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF2D95)
                                    .withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text('Week $_week',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFFF2D95))),
                            ),
                          ],
                        ),
                        Slider(
                          value: _week.toDouble(),
                          min: 1,
                          max: 42,
                          divisions: 41,
                          activeColor: const Color(0xFFFF2D95),
                          onChanged: (v) =>
                              setState(() => _week = v.round()),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller:
                              TextEditingController(text: _due),
                          readOnly: true,
                          onTap: () async {
                            final now = DateTime.now();
                            final picked = await showDatePicker(
                              context: context,
                              initialDate:
                                  now.add(const Duration(days: 90)),
                              firstDate: now,
                              lastDate:
                                  now.add(const Duration(days: 300)),
                            );
                            if (picked != null) {
                              setState(() => _due =
                                  '${picked.day}/${picked.month}/${picked.year}');
                            }
                          },
                          decoration: InputDecoration(
                            labelText: 'Due Date ($_due)',
                            prefixIcon: const Icon(
                                Icons.calendar_today_outlined,
                                color: Color(0xFFFF2D95)),
                            filled: true,
                            fillColor: const Color(0xFFFFF8FC),
                            border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(14)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF2D95),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Text('Save Profile',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: _logout,
                      icon: const Icon(Icons.logout, color: Colors.red),
                      label: const Text('Log Out',
                          style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.redAccent),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon,
      TextInputType type) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFFFF2D95)),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFFFD3E7))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFFFD3E7))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:
                const BorderSide(color: Color(0xFFFF2D95), width: 1.5)),
      ),
    );
  }
}
