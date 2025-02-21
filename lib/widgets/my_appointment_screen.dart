// ignore_for_file: unused_local_variable

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

class MyAppointmentScreen extends StatefulWidget {
  const MyAppointmentScreen({super.key});

  @override
  _MyAppointmentScreenState createState() => _MyAppointmentScreenState();
}

class _MyAppointmentScreenState extends State<MyAppointmentScreen> {
  DateTime _selectedDate = DateTime.now();
  String? _filteredDayName;
  List<DocumentSnapshot<Map<String, dynamic>>> _appointments = [];

  @override
  void initState() {
    super.initState();
    _fetchAppointments();
  }

  void _fetchAppointments() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    if (_filteredDayName != null) return; // Filtreleme varsa çalıştırma

    final formattedDate = _selectedDate.toIso8601String().split('T')[0];
    final snapshot = await FirebaseFirestore.instance
        .collection('appointments')
        .where('userId', isEqualTo: userId)
        .where('date', isEqualTo: formattedDate)
        .get();

    setState(() {
      _appointments = snapshot.docs;
    });
  }

  Future<void> _fetchAppointmentsByDay(String selectedDay) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    if (_filteredDayName == selectedDay) {
      // Aynı gün seçilmişse filtreyi sıfırla
      setState(() {
        _filteredDayName = null;
      });
      _fetchAppointments(); // Mevcut güne göre listeyi yenile
      return;
    }

    final snapshot = await FirebaseFirestore.instance
        .collection('appointments')
        .where('userId', isEqualTo: userId)
        .get();

    setState(() {
      _appointments = snapshot.docs.where((doc) {
        final rawDate = doc['date'];
        if (rawDate == null) return false;

        final DateTime appointmentDate = DateTime.parse(rawDate);
        final String dayName =
            DateFormat('EEEE', 'tr_TR').format(appointmentDate);
        return dayName == selectedDay;
      }).toList();

      _filteredDayName = selectedDay; // Filtrelenmiş gün ismi
      _selectedDate = DateTime.now(); // Takvimdeki işareti kaldır
    });
  }

  DateTime _getStartOfWeek(DateTime date) {
    final dayOfWeek = date.weekday;
    return date.subtract(Duration(days: dayOfWeek - 1));
  }

  List<DateTime> _generateWeekDays(DateTime startOfWeek) {
    return List.generate(7, (index) => startOfWeek.add(Duration(days: index)));
  }

  String _getDayName(DateTime date) {
    const dayNames = [
      'Pazartesi',
      'Salı',
      'Çarşamba',
      'Perşembe',
      'Cuma',
      'Cumartesi',
      'Pazar'
    ];
    return dayNames[date.weekday - 1];
  }

  void _showFilterBottomSheet() {
    final days = _generateWeekDays(_getStartOfWeek(_selectedDate));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color.fromARGB(255, 66, 66, 66),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: StatefulBuilder(
            builder: (BuildContext context, StateSetter setModalState) {
              return SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.date_range_outlined,
                            color: Colors.white,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Randevu Günleri',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: days.map((day) {
                          final isSelected =
                              _filteredDayName == _getDayName(day);

                          return GestureDetector(
                            onTap: () {
                              Navigator.pop(context); // BottomSheet'i kapat
                              _fetchAppointmentsByDay(_getDayName(day));
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 10, horizontal: 16),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.green
                                    : const Color.fromARGB(255, 251, 251, 251),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _getDayName(day),
                                style: TextStyle(
                                  color: isSelected
                                      ? const Color.fromARGB(255, 251, 251, 251)
                                      : Colors.black87,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildFilterButton() {
    return Align(
      alignment: Alignment.centerRight,
      child: IconButton(
        icon: const Icon(Icons.filter_list, color: Colors.white, size: 30),
        onPressed: () => _showFilterBottomSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(115, 184, 0, 31),
        automaticallyImplyLeading: false,
        title: Text(
          'Randevularım',
          style: GoogleFonts.poppins(
            color: const Color.fromARGB(255, 251, 251, 251),
          ),
        ),
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
        actions: [_buildFilterButton()],
      ),
      body: Column(
        children: [
          _buildCalendar(),
          const SizedBox(height: 10),
          Expanded(
            child: _appointments.isEmpty
                ? const Center(
                    child: Text(
                      'Bu güne ait randevunuz bulunmamaktadır.',
                      style:
                          TextStyle(color: Color.fromARGB(255, 251, 251, 251)),
                    ),
                  )
                : ListView.builder(
                    itemCount: _appointments.length,
                    itemBuilder: (context, index) {
                      final appointment = _appointments[index];
                      final data = appointment.data();

                      if (data == null) return const SizedBox.shrink();

                      // Randevu tarihi formatlama
                      final rawDate = data['date'];
                      final DateTime appointmentDate = rawDate != null
                          ? DateTime.parse(rawDate)
                          : DateTime.now();
                      final String formattedDate =
                          DateFormat('d MMMM EEEE', 'tr_TR')
                              .format(appointmentDate);

                      final timeSlot = data['time'] ?? 'Saat belirtilmemiş';
                      final services =
                          (data['services'] as List<dynamic>).join(', ');
                      final username =
                          data['username'] ?? 'Ad Soyad Bilinmiyor';

                      return Card(
                        color: const Color.fromARGB(255, 66, 66, 66),
                        margin: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        child: ListTile(
                          title: Text(
                            'Tarih: $formattedDate\nSaat: $timeSlot\n',
                            style: const TextStyle(
                                color: Color.fromARGB(255, 251, 251, 251)),
                          ),
                          subtitle: Text(
                            'Hizmetler: $services\nRandevu Alan: $username',
                            style: const TextStyle(
                                color: Color.fromARGB(255, 251, 251, 251)),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar() {
    return TableCalendar(
      locale: 'tr_TR',
      firstDay: DateTime.utc(2023, 1, 1),
      lastDay: DateTime.utc(2099, 12, 31),
      focusedDay: _selectedDate,
      selectedDayPredicate: (day) =>
          _filteredDayName == null && isSameDay(_selectedDate, day),
      onDaySelected: (selectedDay, focusedDay) {
        setState(() {
          _selectedDate = selectedDay;
          _filteredDayName = null; // Gün seçimi yapılırsa filtreyi sıfırla
        });
        _fetchAppointments();
      },
      calendarFormat: CalendarFormat.week,
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
}
