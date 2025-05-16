import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'qr_generator_screen.dart';
import 'event_gallery_screen.dart';
import 'login_screen.dart';

class QRListScreen extends StatefulWidget {
  const QRListScreen({super.key});

  @override
  State<QRListScreen> createState() => _QRListScreenState();
}

class _QRListScreenState extends State<QRListScreen> {
  final DatabaseReference dbRef =
      FirebaseDatabase.instance.ref("Event Gallery App/events");
  List<Map<String, dynamic>> eventList = [];

  @override
  void initState() {
    super.initState();
    _loadQRCodes();
  }

 Future<void> _loadQRCodes() async {
  final snapshot = await dbRef.get();

  if (!mounted) return; // ⬅️ add this check after the await

  if (snapshot.exists) {
    final data = snapshot.value as Map;
    final List<Map<String, dynamic>> loadedEvents = [];
    data.forEach((key, value) {
      loadedEvents.add({
        'id': key,
        'eventName': value['Event Name'] ?? 'Unknown',
        'eventDate': value['event date'] ?? '',
        'status': value['Status'] ?? '',
        'qrImage': value['QRcode image'] ?? '',
      });
    });

    if (mounted) {
      setState(() {
        eventList = loadedEvents;
      });
    }
  } else {
    if (mounted) {
      setState(() {
        eventList = [];
      });
    }
  }
}


  Future<void> _deleteEvent(String id) async {
    await dbRef.child(id).remove();
    setState(() {
      eventList.removeWhere((element) => element['id'] == id);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Event removed")),
    );
  }

  Future<void> _closeEvent(String id) async {
    await dbRef.child(id).update({"Status": "Closed"});
    await _loadQRCodes();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Event marked as Closed")),
    );
  }

  Future<void> _navigateToCreateEvent() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const QRGeneratorScreen(
          eventName: null,
          eventDate: null,
          eventStatus: null,
          eventId: null,
        ),
      ),
    );
    _loadQRCodes(); // reload list after coming back
  }
void _logout() async {
  await FirebaseAuth.instance.signOut();
  if (!mounted) return;
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(builder: (_) => const LoginScreen(eventData: {},)),
  );
}


  void _showEventActionsDialog(Map<String, dynamic> event) {
    TextEditingController eventNameController =
        TextEditingController(text: event['eventName']);
    TextEditingController eventDateController =
        TextEditingController(text: event['eventDate']);
    TextEditingController eventStatusController =
        TextEditingController(text: event['status']);

    bool isEditing = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              insetPadding: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              child: Container(
                padding: const EdgeInsets.all(20),
                constraints: const BoxConstraints(maxHeight: 600),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Align(
                        alignment: Alignment.topRight,
                        child: IconButton(
                          icon: Icon(isEditing ? Icons.save : Icons.edit),
                          onPressed: () async {
                            if (!isEditing) {
                              setDialogState(() {
                                isEditing = true;
                              });
                            } else {
                              final newId =
                                  DateTime.now().millisecondsSinceEpoch.toString();
                              final newQRUrl =
                                  "https://api.qrserver.com/v1/create-qr-code/?data=${Uri.encodeComponent(eventNameController.text)}&size=300x300";

                              await dbRef.child(newId).set({
                                'Event Name': eventNameController.text.trim(),
                                'event date': eventDateController.text.trim(),
                                'Status': eventStatusController.text.trim(),
                                'QRcode image': newQRUrl,
                              });

                              await dbRef.child(event['id']).remove();

                              Navigator.pop(context);
                              _loadQRCodes();

                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text("Event updated successfully")),
                              );
                            }
                          },
                        ),
                      ),
                      isEditing
                          ? TextField(
                              controller: eventNameController,
                              decoration: const InputDecoration(
                                  labelText: 'Event Name'),
                            )
                          : Text(
                              "Event Name: ${event['eventName']}",
                              style: const TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.bold),
                            ),
                      const SizedBox(height: 12),
                      isEditing
                          ? TextField(
                              controller: eventDateController,
                              decoration:
                                  const InputDecoration(labelText: 'Event Date'),
                            )
                          : Text("Date: ${event['eventDate']}",
                              style: const TextStyle(fontSize: 16)),
                      const SizedBox(height: 8),
                      isEditing
                          ? TextField(
                              controller: eventStatusController,
                              decoration:
                                  const InputDecoration(labelText: 'Status'),
                            )
                          : Text("Status: ${event['status']}",
                              style: const TextStyle(fontSize: 16)),
                      const SizedBox(height: 20),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          "https://api.qrserver.com/v1/create-qr-code/?data=${Uri.encodeComponent(event['eventName'])}&size=300x300",
                          height: 240,
                          width: 240,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 30),
                      if (!isEditing)
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.pop(context);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          EventGalleryScreen(eventId: event['id']),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.photo_library),
                                label: const Text("Open Gallery"),
                              ),
                            ),
                            const SizedBox(width: 10),
                            if (event['status'] != 'Closed')
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _showCloseConfirmDialog(event['id']);
                                  },
                                  icon: const Icon(Icons.close),
                                  label: const Text("Close Event"),
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red),
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showCloseConfirmDialog(String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirm Close"),
        content:
            const Text("Are you sure you want to mark this event as Closed?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _closeEvent(id);
            },
            child: const Text("Confirm"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/eventbg.jpeg',
              fit: BoxFit.cover,
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                AppBar(
                  automaticallyImplyLeading: false, // 👈 disables back arrow
                  title: const Text("Events Manager"),
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.logout),
                      tooltip: 'Logout',
                      onPressed: _logout,
                    ),
                  ],
                ),
                Expanded(
                  child: eventList.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                "No Events are Available",
                                style: TextStyle(
                                    fontSize: 18, color: Colors.white),
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton(
                                onPressed: _navigateToCreateEvent,
                                child: const Text("Create Event"),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: eventList.length,
                          itemBuilder: (context, index) {
                            final event = eventList[index];
                            return Dismissible(
                              key: Key(event['id']),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 20),
                                alignment: Alignment.centerRight,
                                color: Colors.red,
                                child: const Icon(Icons.delete,
                                    color: Colors.white),
                              ),
                              confirmDismiss: (direction) async {
                                return await showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text("Confirm Delete"),
                                    content: Text(
                                        "Delete '${event['eventName']}' event?"),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(ctx).pop(false),
                                        child: const Text("Cancel"),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(ctx).pop(true),
                                        child: const Text("Delete"),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              onDismissed: (_) => _deleteEvent(event['id']),
                              child: GestureDetector(
                                onTap: () => _showEventActionsDialog(event),
                                child: Container(
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.85),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.black12,
                                        blurRadius: 6,
                                        offset: Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(event['qrImage'],
                                            width: 60, height: 60),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text("Event Name: ${event['eventName']}",
                                                style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight:
                                                        FontWeight.w500)),
                                            Text("Date: ${event['eventDate']}"),
                                            Text("Status: ${event['status']}"),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: eventList.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _navigateToCreateEvent,
              icon: const Icon(Icons.add),
              label: const Text("Create Event"),
            )
          : null,
      backgroundColor: Colors.transparent,
    );
  }
}
