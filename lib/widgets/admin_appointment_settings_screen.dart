import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:table_calendar/table_calendar.dart';

class AdminAppointmentSettingsScreen extends StatefulWidget {
  const AdminAppointmentSettingsScreen({Key? key}) : super(key: key);

  @override
  _AdminAppointmentSettingsScreenState createState() =>
      _AdminAppointmentSettingsScreenState();
}

class _AdminAppointmentSettingsScreenState
    extends State<AdminAppointmentSettingsScreen> {
  DateTime _selectedDay = DateTime.now();
  List<String> _blockedTimeSlots = [];

  final List<String> _timeSlots = List.generate(
    15,
    (index) {
      final int hour = 9 + (index * 45) ~/ 60;
      final int minute = (index * 45) % 60;
      return "${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}";
    },
  );

  @override
  void initState() {
    super.initState();
    _fetchBlockedTimes();
  }

  Future<void> _fetchBlockedTimes() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('blocked_times')
        .where('date', isEqualTo: _selectedDay.toIso8601String().split('T')[0])
        .get();

    setState(() {
      _blockedTimeSlots =
          snapshot.docs.map((doc) => doc['time'] as String).toList();
    });
  }

  Future<void> _blockTimeSlot(String timeSlot) async {
    setState(() {
      _blockedTimeSlots.add(timeSlot);
    });

    await FirebaseFirestore.instance
        .collection('blocked_times')
        .doc('${_selectedDay.toIso8601String().split('T')[0]}_$timeSlot')
        .set({
      'date': _selectedDay.toIso8601String().split('T')[0],
      'time': timeSlot,
    });
  }

  Future<void> _unblockTimeSlot(String timeSlot) async {
    setState(() {
      _blockedTimeSlots.remove(timeSlot);
    });

    await FirebaseFirestore.instance
        .collection('blocked_times')
        .doc('${_selectedDay.toIso8601String().split('T')[0]}_$timeSlot')
        .delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(115, 184, 0, 31),
        automaticallyImplyLeading: false,
        title: Text(
          'Admin Randevu Ayarları',
          style: GoogleFonts.poppins(
            color: const Color.fromARGB(255, 251, 251, 251),
          ),
        ),
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCalendar(),
            const SizedBox(height: 20),
            const Text(
              'Engellenecek Saatleri Seçin:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color.fromARGB(255, 251, 251, 251),
              ),
            ),
            const SizedBox(height: 10),
            _buildTimeSlots(),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendar() {
    return TableCalendar(
      locale: 'tr_TR',
      firstDay: DateTime.now(),
      lastDay: DateTime.now().add(const Duration(days: 365)),
      focusedDay: _selectedDay,
      calendarFormat: CalendarFormat.week,
      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
      onDaySelected: (selectedDay, _) {
        setState(() {
          _selectedDay = selectedDay;
          _fetchBlockedTimes();
        });
      },
      calendarStyle: const CalendarStyle(
        selectedDecoration: BoxDecoration(
          color: Colors.green,
          shape: BoxShape.circle,
        ),
        todayDecoration: BoxDecoration(
          color: Colors.blue,
          shape: BoxShape.circle,
        ),
        defaultTextStyle: TextStyle(
          color: Color.fromARGB(255, 251, 251, 251),
        ),
        weekendTextStyle: TextStyle(
          color: Color.fromARGB(255, 251, 251, 251),
        ),
      ),
      headerStyle: const HeaderStyle(
        titleTextStyle: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: Color.fromARGB(255, 251, 251, 251),
        ),
        formatButtonVisible: false,
        leftChevronIcon: Icon(
          Icons.chevron_left,
          color: Color.fromARGB(255, 251, 251, 251),
        ),
        rightChevronIcon: Icon(
          Icons.chevron_right,
          color: Color.fromARGB(255, 251, 251, 251),
        ),
      ),
      daysOfWeekStyle: const DaysOfWeekStyle(
        weekdayStyle: TextStyle(
          color: Color.fromARGB(255, 251, 251, 251),
        ),
        weekendStyle: TextStyle(
          color: Color.fromARGB(255, 251, 251, 251),
        ),
      ),
    );
  }

  Widget _buildTimeSlots() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _timeSlots.map((slot) {
        final isBlocked = _blockedTimeSlots.contains(slot);
        return ChoiceChip(
          label: Text(
            slot,
            style: const TextStyle(
              color: Colors.black87,
            ),
          ),
          selected: isBlocked,
          onSelected: (selected) {
            if (selected) {
              _blockTimeSlot(slot);
            } else {
              _unblockTimeSlot(slot);
            }
          },
          selectedColor: Colors.green,
          backgroundColor: Colors.grey.withOpacity(.4),
        );
      }).toList(),
    );
  }
}
