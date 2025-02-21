import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class AppointmentScreen extends StatefulWidget {
  const AppointmentScreen({Key? key}) : super(key: key);

  @override
  _AppointmentScreenState createState() => _AppointmentScreenState();
}

class _AppointmentScreenState extends State<AppointmentScreen> {
  DateTime _selectedDay = DateTime.now();
  String _username = "Kullanıcı";
  bool _isAdmin = false;

  final TextEditingController _adminNameController = TextEditingController();

  static const List<String> _timeSlots = [
    "09:00",
    "09:45",
    "10:30",
    "11:15",
    "12:00",
    "12:45",
    "13:30",
    "14:15",
    "15:00",
    "15:45",
    "16:30",
    "17:15",
    "18:00",
    "18:45",
    "19:30",
  ];

  final ValueNotifier<List<String>> _selectedServicesNotifier =
      ValueNotifier([]);
  final ValueNotifier<String?> _selectedTimeSlotNotifier = ValueNotifier(null);
  final ValueNotifier<List<String>> _blockedTimeSlotsNotifier =
      ValueNotifier([]);
  final ValueNotifier<List<String>> _bookedTimeSlotsNotifier =
      ValueNotifier([]);

  final int _maxServices = 3;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _fetchBlockedTimes();
    _fetchBookedTimes();
  }

  Future<void> _fetchUserData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      setState(() {
        _username = userDoc.data()?['name'] ?? "Kullanıcı";
        _isAdmin = userDoc.data()?['isAdmin'] ?? false;
      });
    }
  }

  Future<void> _fetchBlockedTimes() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('blocked_times')
        .where('date', isEqualTo: _selectedDay.toIso8601String().split('T')[0])
        .get();

    final blockedTimes =
        snapshot.docs.map((doc) => doc['time'] as String).toList();
    _blockedTimeSlotsNotifier.value = blockedTimes;
  }

  Future<void> _fetchBookedTimes() async {
    final dateString = _selectedDay.toIso8601String().split('T')[0];
    final snapshot = await FirebaseFirestore.instance
        .collection('appointments')
        .where('date', isEqualTo: dateString)
        .get();

    final bookedTimes =
        snapshot.docs.map((doc) => doc['time'] as String).toList();
    _bookedTimeSlotsNotifier.value = bookedTimes;
  }

  Future<void> _saveAppointment() async {
    final user = FirebaseAuth.instance.currentUser;
    final fcmToken = await FirebaseMessaging.instance.getToken();

    if (user == null || fcmToken == null) {
      _showSnackbar('FcmToken alınamadı veya kullanıcı oturumu kapalı!');
      return;
    }

    if (_selectedServicesNotifier.value.isEmpty) {
      _showSnackbar('Lütfen en az bir hizmet seçin.');
      return;
    }

    if (_selectedTimeSlotNotifier.value == null) {
      _showSnackbar('Lütfen bir randevu saati seçin.');
      return;
    }

    final dateString = _selectedDay.toIso8601String().split('T')[0];
    String usernameToSave = _username;

    // Eğer kullanıcı admin ise Ad Soyad alanındaki değeri kullan
    if (_isAdmin) {
      if (_adminNameController.text.isEmpty) {
        _showSnackbar('Lütfen Ad Soyad alanını doldurun.');
        return;
      }
      usernameToSave = _adminNameController.text;
    } else {
      // Eğer kullanıcı admin değilse aynı güne başka randevu almayı engelle
      final existingAppointments = await FirebaseFirestore.instance
          .collection('appointments')
          .where('userId', isEqualTo: user.uid)
          .where('date', isEqualTo: dateString)
          .get();

      if (existingAppointments.docs.isNotEmpty) {
        _showSnackbar('Aynı güne yalnızca bir randevu alabilirsiniz.');
        return;
      }
    }

    // Randevu verilerini Firestore'a kaydet
    final appointmentData = {
      'userId': user.uid,
      'username': usernameToSave,
      'date': dateString,
      'time': _selectedTimeSlotNotifier.value,
      'services': _selectedServicesNotifier.value,
      'fcmToken': fcmToken,
    };

    await FirebaseFirestore.instance
        .collection('appointments')
        .add(appointmentData);

    _showSnackbar('Randevunuz başarıyla kaydedildi.');
    _resetForm();

    // Randevu kaydedildikten sonra booked time'ları yeniden yükle
    await _fetchBookedTimes();
  }

  void _resetForm() {
    _selectedTimeSlotNotifier.value = null;
    _selectedServicesNotifier.value = [];
    if (_isAdmin) {
      _adminNameController.clear();
    }
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  bool _isTimeSlotAvailable(String slot) {
    DateTime now = DateTime.now();
    DateTime slotTime = DateFormat('HH:mm').parse(slot);
    DateTime selectedDateTime = DateTime(
      _selectedDay.year,
      _selectedDay.month,
      _selectedDay.day,
      slotTime.hour,
      slotTime.minute,
    );

    // Eğer seçilen gün bugünün tarihi ise, mevcut saatten önceki saatleri devre dışı bırak
    return selectedDateTime.isAfter(now);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('tr', 'TR')],
      home: Scaffold(
        backgroundColor: Colors.black87,
        appBar: AppBar(
          backgroundColor: const Color.fromARGB(115, 184, 0, 31),
          automaticallyImplyLeading: false,
          title: Text(
            'Randevu Al',
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
              Text(
                "Merhaba, $_username",
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  color: const Color.fromARGB(255, 251, 251, 251),
                ),
              ),
              const SizedBox(height: 10),
              _buildCalendar(),
              const SizedBox(height: 20),
              const Text(
                'Hizmet Seçin:',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color.fromARGB(255, 251, 251, 251),
                ),
              ),
              const SizedBox(height: 10),
              _buildServicesGrid(),
              const SizedBox(height: 20),
              const Text(
                'Randevu Saati Seçin:',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color.fromARGB(255, 251, 251, 251),
                ),
              ),
              const SizedBox(height: 10),
              _buildTimeSlots(),
              if (_isAdmin) ...[
                const SizedBox(height: 20),
                TextFormField(
                  controller: _adminNameController,
                  style: const TextStyle(
                      color: Color.fromARGB(255, 251, 251, 251)),
                  decoration: const InputDecoration(
                    labelText: 'Ad Soyad',
                    labelStyle:
                        TextStyle(color: Color.fromARGB(255, 251, 251, 251)),
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              OutlinedButton(
                style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.all(Colors.green)),
                onPressed: _saveAppointment,
                child: const Text(
                  'Randevuyu Kaydet',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCalendar() {
    return TableCalendar(
      locale: 'tr_TR',
      firstDay: DateTime.now(),
      lastDay: DateTime.now().add(const Duration(days: 6)),
      focusedDay: _selectedDay,
      calendarFormat: CalendarFormat.week,
      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
      onDaySelected: (selectedDay, _) {
        setState(() {
          _selectedDay = selectedDay;
          _selectedTimeSlotNotifier.value = null;
        });
        _fetchBlockedTimes();
        _fetchBookedTimes();
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
        leftChevronPadding: EdgeInsets.all(8),
        rightChevronPadding: EdgeInsets.all(8),
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

  Widget _buildServicesGrid() {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance.collection('services').get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Text(
            'Hizmet bulunamadı.',
            style: TextStyle(color: Color.fromARGB(255, 251, 251, 251)),
          );
        }

        final services = snapshot.data!.docs;

        return ValueListenableBuilder<List<String>>(
          valueListenable: _selectedServicesNotifier,
          builder: (context, selectedServices, _) {
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 2,
              ),
              itemCount: services.length,
              itemBuilder: (context, index) {
                final service = services[index];
                final serviceName = service['name'];

                return GestureDetector(
                  onTap: () {
                    if (selectedServices.contains(serviceName)) {
                      _selectedServicesNotifier.value =
                          List.from(selectedServices)..remove(serviceName);
                    } else if (selectedServices.length < _maxServices) {
                      _selectedServicesNotifier.value =
                          List.from(selectedServices)..add(serviceName);
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: selectedServices.contains(serviceName)
                            ? Colors.green
                            : Colors.grey,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Center(
                      child: Text(
                        serviceName,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: selectedServices.contains(serviceName)
                              ? Colors.green
                              : Color.fromARGB(255, 251, 251, 251),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildTimeSlots() {
    return ValueListenableBuilder<List<String>>(
      valueListenable: _blockedTimeSlotsNotifier,
      builder: (context, blockedTimeSlots, _) {
        return ValueListenableBuilder<List<String>>(
          valueListenable: _bookedTimeSlotsNotifier,
          builder: (context, bookedTimeSlots, __) {
            return ValueListenableBuilder<String?>(
              valueListenable: _selectedTimeSlotNotifier,
              builder: (context, selectedTimeSlot, ___) {
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _timeSlots.map((slot) {
                    final isSelected = selectedTimeSlot == slot;
                    final isBlocked = blockedTimeSlots.contains(slot);
                    final isBooked = bookedTimeSlots.contains(slot);
                    final isAvailable = _isTimeSlotAvailable(slot);

                    Color chipColor;
                    if (isBlocked) {
                      chipColor = Colors.red.withOpacity(.6);
                    } else if (!isAvailable) {
                      chipColor = Colors.orange.withOpacity(.6);
                    } else if (isBooked) {
                      chipColor = Colors.blue.withOpacity(.6);
                    } else if (isSelected) {
                      chipColor = Colors.green;
                    } else {
                      chipColor = Colors.grey.withOpacity(.4);
                    }

                    return ChoiceChip(
                      label: Text(
                        slot,
                        style: const TextStyle(color: Colors.black87),
                      ),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (!isAvailable) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Bu saat geçmişte kaldı, başka bir saat seçin.',
                                style: TextStyle(
                                    color: Color.fromARGB(255, 251, 251, 251)),
                              ),
                            ),
                          );
                        } else if (isBlocked) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Bu saat kapalıdır, başka bir saat seçin.',
                                style: TextStyle(
                                    color: Color.fromARGB(255, 251, 251, 251)),
                              ),
                            ),
                          );
                        } else if (isBooked) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Bu saate daha önce randevu alınmış.',
                                style: TextStyle(
                                    color: Color.fromARGB(255, 251, 251, 251)),
                              ),
                            ),
                          );
                        } else {
                          _selectedTimeSlotNotifier.value =
                              selected ? slot : null;
                        }
                      },
                      selectedColor: chipColor,
                      backgroundColor: chipColor,
                    );
                  }).toList(),
                );
              },
            );
          },
        );
      },
    );
  }
}
