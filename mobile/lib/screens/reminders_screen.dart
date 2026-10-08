import 'package:flutter/material.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  final List<Map<String, dynamic>> _reminders = [
    {'icon': Icons.medication, 'title': 'Iron Tablet', 'msg': 'Take your iron supplement with water', 'time': '9:00 AM', 'type': 'medication', 'recurring': true, 'done': false, 'color': const Color(0xFFEC4899)},
    {'icon': Icons.water_drop, 'title': 'Drink Water', 'msg': 'Stay hydrated - drink a glass of water', 'time': '10:00 AM', 'type': 'hydration', 'recurring': true, 'done': true, 'color': const Color(0xFF3B82F6)},
    {'icon': Icons.calendar_today, 'title': 'Prenatal Checkup', 'msg': 'Monthly checkup at City Hospital', 'time': '2:00 PM', 'type': 'appointment', 'recurring': false, 'done': false, 'color': const Color(0xFF10B981)},
    {'icon': Icons.restaurant, 'title': 'Evening Snack', 'msg': 'Have a protein-rich snack', 'time': '4:00 PM', 'type': 'nutrition', 'recurring': true, 'done': false, 'color': const Color(0xFFF59E0B)},
    {'icon': Icons.medication, 'title': 'Prenatal Vitamins', 'msg': 'Take folic acid + calcium supplement', 'time': '8:00 PM', 'type': 'medication', 'recurring': true, 'done': false, 'color': const Color(0xFFEC4899)},
  ];

  static const Map<String, IconData> _typeIcons = {
    'medication': Icons.medication,
    'hydration': Icons.water_drop,
    'appointment': Icons.calendar_today,
    'nutrition': Icons.restaurant,
    'general': Icons.alarm,
  };

  static const Map<String, Color> _typeColors = {
    'medication': Color(0xFFEC4899),
    'hydration': Color(0xFF3B82F6),
    'appointment': Color(0xFF10B981),
    'nutrition': Color(0xFFF59E0B),
    'general': Color(0xFF8B5CF6),
  };

  @override
  Widget build(BuildContext context) {
    final pending = _reminders.where((r) => !r['done']).toList();
    final completed = _reminders.where((r) => r['done']).toList();

    final _body = SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text('Reminders',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF14142B))),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => _showAddSheet(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFFFF2D95), Color(0xFFFF73B8)]),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.add, size: 16, color: Colors.white),
                        SizedBox(width: 4),
                        Text('Add', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (pending.isNotEmpty) ...[
              const Text('Today', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF7D6B82))),
              const SizedBox(height: 10),
              ...pending.map((r) => Dismissible(
                    key: ValueKey(r['title'] + r['time']),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      decoration: BoxDecoration(
                          color: Colors.red.shade400,
                          borderRadius: BorderRadius.circular(14)),
                      child:
                          const Icon(Icons.delete_outline, color: Colors.white),
                    ),
                    onDismissed: (_) =>
                        setState(() => _reminders.remove(r)),
                    child: _reminderCard(r),
                  )),
            ],
            if (completed.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text('Completed', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF7D6B82))),
              const SizedBox(height: 10),
              ...completed.map((r) => Dismissible(
                    key: ValueKey(r['title'] + r['time']),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      decoration: BoxDecoration(
                          color: Colors.red.shade400,
                          borderRadius: BorderRadius.circular(14)),
                      child:
                          const Icon(Icons.delete_outline, color: Colors.white),
                    ),
                    onDismissed: (_) =>
                        setState(() => _reminders.remove(r)),
                    child: _reminderCard(r),
                  )),
            ],
          ],
        ),
      ),
    );

    // When hosted inside the Home IndexedStack the parent already draws the
    // bar, so show nothing extra. When pushed as a route (a Quick Action) this
    // Scaffold supplies the AppBar and therefore the back button - without it
    // the user lands on a screen with no way back, which reads as a black page.
    final pushed = Navigator.of(context).canPop();
    return Scaffold(
      backgroundColor: const Color(0xFFFDF7FB),
      appBar: !pushed
          ? null
          : AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              title: const Text('Reminders',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            ),
      body: _body,
    );
  }

  Widget _reminderCard(Map<String, dynamic> r) {
    final Color color = r['color'];
    final bool done = r['done'];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: done ? const Color(0xFFF9FAFB) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: done ? null : [BoxShadow(color: Colors.grey.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 3))],
        border: Border.all(color: done ? Colors.grey.withValues(alpha: 0.15) : color.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(r['icon'], color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Flexible so a long reminder title ellipsises instead
                    // of overflowing against the "Daily" badge.
                    Flexible(
                      child: Text(r['title'], maxLines: 2, style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14,
                        decoration: done ? TextDecoration.lineThrough : null,
                        color: done ? Colors.grey : const Color(0xFF14142B),
                      )),
                    ),
                    if (r['recurring']) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('Daily', style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(r['msg'], style: TextStyle(fontSize: 12, color: done ? Colors.grey : const Color(0xFF7D6B82))),
              ],
            ),
          ),
          // Flexible: at a large text scale this column grew wider than the
          // row could spare and pushed the whole card past the edge.
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              Text(r['time'],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF7D6B82))),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () {
                  setState(() => r['done'] = !r['done']);
                },
                child: Icon(
                  done ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: done ? const Color(0xFF10B981) : Colors.grey.shade400,
                  size: 22,
                ),
              ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddSheet() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    TimeOfDay pickedTime = const TimeOfDay(hour: 9, minute: 0);
    String pickedType = 'medication';
    bool recurring = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => Container(
        padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 16),
            const Text('Add Reminder', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: titleCtrl,
              decoration: InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: const Color(0xFFFFF8FC),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              decoration: InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: const Color(0xFFFFF8FC),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      final t = await showTimePicker(
                          context: context, initialTime: pickedTime);
                      if (t != null) setSheet(() => pickedTime = t);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF8FC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.access_time,
                              size: 18, color: Color(0xFFFF2D95)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(pickedTime.format(context),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: pickedType,
                    items: _typeIcons.keys
                        .map((t) => DropdownMenuItem(
                            value: t,
                            child: Text(
                                '${t[0].toUpperCase()}${t.substring(1)}',
                                style: const TextStyle(fontSize: 14))))
                        .toList(),
                    onChanged: (v) =>
                        setSheet(() => pickedType = v ?? 'medication'),
                    decoration: InputDecoration(
                      labelText: 'Type',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: const Color(0xFFFFF8FC),
                    ),
                  ),
                ),
              ],
            ),
            SwitchListTile(
              value: recurring,
              onChanged: (v) => setSheet(() => recurring = v),
              title: const Text('Repeat daily', style: TextStyle(fontSize: 14)),
              activeColor: const Color(0xFFFF2D95),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  final title = titleCtrl.text.trim();
                  if (title.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Please enter a title')),
                    );
                    return;
                  }
                  setState(() {
                    _reminders.insert(0, {
                      'icon': _typeIcons[pickedType]!,
                      'title': title,
                      'msg': descCtrl.text.trim().isEmpty
                          ? 'Reminder'
                          : descCtrl.text.trim(),
                      'time': pickedTime.format(context),
                      'type': pickedType,
                      'recurring': recurring,
                      'done': false,
                      'color': _typeColors[pickedType]!,
                    });
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Reminder added'),
                      backgroundColor: Color(0xFFFF2D95),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF2D95),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Save Reminder', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}
