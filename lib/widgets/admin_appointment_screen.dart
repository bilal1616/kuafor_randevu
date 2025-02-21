import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

class AdminAppointmentScreen extends StatefulWidget {
  const AdminAppointmentScreen({super.key});

  @override
  _AdminAppointmentScreenState createState() => _AdminAppointmentScreenState();
}

class _AdminAppointmentScreenState extends State<AdminAppointmentScreen> {
  DateTime _selectedDate = DateTime.now();
  String? _filteredDayName;
  List<DocumentSnapshot> _appointments = [];

  @override
  void initState() {
    super.initState();
    _fetchAppointments();
  }

  void _fetchAppointments() async {
    if (_filteredDayName != null) return; // Filtreleme varsa çalıştırma

    final formattedDate = _selectedDate.toIso8601String().split('T')[0];
    final snapshot = await FirebaseFirestore.instance
        .collection('appointments')
        .where('date', isEqualTo: formattedDate)
        .get();

    setState(() {
      _appointments = snapshot.docs;
      _appointments.sort((a, b) {
        final timeA = a['time'] ?? '00:00';
        final timeB = b['time'] ?? '00:00';
        return timeA.compareTo(timeB);
      });
    });
  }

  Future<void> _deleteAppointment(String appointmentId) async {
    await FirebaseFirestore.instance
        .collection('appointments')
        .doc(appointmentId)
        .delete();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Randevu başarıyla silindi.',
          style: TextStyle(color: Color.fromARGB(255, 251, 251, 251)),
        ),
        backgroundColor: Colors.green,
      ),
    );

    _fetchAppointments();
  }

  void _confirmDelete(String appointmentId) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Randevuyu Sil'),
          content:
              const Text('Bu randevuyu silmek istediğinizden emin misiniz?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Dialog'u kapat
              },
              child: const Text('İptal'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Dialog'u kapat
                _deleteAppointment(appointmentId); // Silme işlemini başlat
              },
              child: const Text('Sil', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
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

  Future<void> _fetchAppointmentsByDay(String selectedDay) async {
    if (_filteredDayName == selectedDay) {
      // Aynı gün seçilmişse filtreyi sıfırla
      setState(() {
        _filteredDayName = null;
      });
      _fetchAppointments(); // Mevcut güne göre listeyi yenile
      return;
    }

    final snapshot =
        await FirebaseFirestore.instance.collection('appointments').get();

    setState(() {
      _appointments = snapshot.docs.where((doc) {
        final rawDate = doc['date'];
        if (rawDate == null) return false;

        final DateTime appointmentDate = DateTime.parse(rawDate);
        final String dayName =
            DateFormat('EEEE', 'tr_TR').format(appointmentDate);
        return dayName == selectedDay;
      }).toList();

      _appointments.sort((a, b) {
        final timeA = a['time'] ?? '00:00';
        final timeB = b['time'] ?? '00:00';
        return timeA.compareTo(timeB);
      });

      _filteredDayName = selectedDay;
      _selectedDate = DateTime.now(); // Takvimdeki işareti kaldır
    });
  }

  Future<void> _fetchAppointmentsByUsername(String username) async {
    if (username.isEmpty) {
      _fetchAppointments();
      return;
    }

    final snapshot = await FirebaseFirestore.instance
        .collection('appointments')
        .where('username', isGreaterThanOrEqualTo: username)
        .where('username', isLessThanOrEqualTo: '${username}z')
        .get();

    setState(() {
      _appointments = snapshot.docs;

      _appointments.sort((a, b) {
        final timeA = a['time'] ?? '00:00';
        final timeB = b['time'] ?? '00:00';
        return timeA.compareTo(timeB);
      });
    });
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
                      const SizedBox(height: 20),
                      const Text(
                        'Randevu Alan Kişileri Ara',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        style: const TextStyle(color: Colors.white),
                        cursorColor: Colors.green,
                        decoration: InputDecoration(
                          hintText: 'Kullanıcı adı girin...',
                          hintStyle: const TextStyle(
                              color: Color.fromARGB(255, 200, 200, 200)),
                          prefixIcon:
                              const Icon(Icons.search, color: Colors.white),
                          filled: true,
                          fillColor: const Color.fromARGB(255, 81, 81, 81),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onSubmitted: (value) {
                          Navigator.pop(context);
                          _fetchAppointmentsByUsername(value.trim());
                        },
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
          'Admin Randevuları',
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
                      'Bu güne ait randevu bulunmamaktadır.',
                      style:
                          TextStyle(color: Color.fromARGB(255, 251, 251, 251)),
                    ),
                  )
                : ListView.builder(
                    itemCount: _appointments.length,
                    itemBuilder: (context, index) {
                      final appointment = _appointments[index];
                      final Map<String, dynamic> appointmentData =
                          appointment.data() as Map<String, dynamic>;

                      final time =
                          appointmentData['time'] ?? 'Saat belirtilmemiş';
                      final services =
                          appointmentData['services']?.join(', ') ??
                              'Hizmet belirtilmemiş';
                      final username = appointmentData['username'] ?? 'N/A';

                      final rawDate = appointmentData['date'];
                      final DateTime appointmentDate = rawDate != null
                          ? DateTime.parse(rawDate)
                          : DateTime.now();
                      final String formattedDate =
                          DateFormat('d MMMM EEEE', 'tr_TR')
                              .format(appointmentDate);

                      return Card(
                        color: const Color.fromARGB(255, 66, 66, 66),
                        margin: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        child: ListTile(
                          title: Text(
                            'Tarih: $formattedDate\nSaat: $time\n',
                            style: const TextStyle(
                                color: Color.fromARGB(255, 251, 251, 251)),
                          ),
                          subtitle: Text(
                            'Hizmetler: $services\nRandevu Alan: $username',
                            style: const TextStyle(
                                color: Color.fromARGB(255, 251, 251, 251)),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              _confirmDelete(appointment.id);
                            },
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
          _filteredDayName == null &&
          isSameDay(_selectedDate, day), // Gün işareti durum kontrolü
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
