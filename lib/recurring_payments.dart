import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RecurringPaymentsPage extends StatefulWidget {
  const RecurringPaymentsPage({super.key});

  @override
  State<RecurringPaymentsPage> createState() =>
      _RecurringPaymentsPageState();
}

class _RecurringPaymentsPageState
    extends State<RecurringPaymentsPage> {
  final user = FirebaseAuth.instance.currentUser;

  // 🎨 Modern Fintech Colors
  static const Color backgroundColor = Color(0xFFF1F5F9);
  static const Color primaryColor = Color(0xFF0F172A);
  static const Color accentColor = Color(0xFF6366F1);
  static const Color dangerColor = Color(0xFFEF4444);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: primaryColor,
        title: const Text(
          "Recurring Payments",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: primaryColor,
          ),
        ),
      ),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance
            .collection('recurring_payments')
            .where('uid', isEqualTo: user!.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final docs = snapshot.data!.docs;

          int active =
              docs.where((d) => d['isActive'] == true).length;
          int paused =
              docs.where((d) => d['isActive'] == false).length;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                "Manage your automated transactions",
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),

              /// 🔹 STAT CARDS
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      "Active",
                      active.toString(),
                      const LinearGradient(
                        colors: [Color.fromARGB(255, 12, 13, 94), Color.fromARGB(255, 8, 4, 87)],
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _buildStatCard(
                      "Paused",
                      paused.toString(),
                      const LinearGradient(
                        colors: [Color.fromARGB(255, 200, 31, 31), Color.fromARGB(255, 193, 22, 22)],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 30),

              /// 🔹 RECURRING LIST
              ...docs.map((doc) => _buildRecurringCard(
                  context, doc.id, doc.data())),
            ],
          );
        },
      ),
    );
  }

  /// ================== STAT CARD ==================

  Widget _buildStatCard(
      String title, String value, Gradient gradient) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            blurRadius: 14,
            color: Colors.black12,
            offset: Offset(0, 6),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  /// ================== RECURRING CARD ==================

  Widget _buildRecurringCard(
      BuildContext context,
      String docId,
      Map<String, dynamic> data) {
    final isActive = data['isActive'] ?? true;
    final List<dynamic> days = data['days'] ?? [];

    final dayNames = [
      "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"
    ];

    String daysText = days.isEmpty
        ? "No days selected"
        : days.map((d) => dayNames[d - 1]).join(" • ");

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: isActive ? 1.0 : 0.45,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () =>
            _showEditDaysSheet(context, docId, days),
        child: Container(
          margin: const EdgeInsets.only(bottom: 18),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                blurRadius: 18,
                color: Colors.black12,
                offset: Offset(0, 8),
              )
            ],
          ),
          child: Row(
            children: [
              /// 🔹 ICON
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 13, 15, 104).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.repeat,
                  color: Color.fromARGB(255, 13, 15, 104),
                ),
              ),

              const SizedBox(width: 18),

              /// 🔹 DETAILS
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['category'] ?? "No Category",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "₹${data['amount']}",
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      daysText,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),

              /// 🔹 TOGGLE
              Switch(
                value: isActive,
                activeThumbColor: const Color.fromARGB(255, 13, 15, 104),
                onChanged: (value) async {
                  if (!value) {
                    _showPauseDialog(context, docId);
                  } else {
                    await FirebaseFirestore.instance
                        .collection('recurring_payments')
                        .doc(docId)
                        .update({'isActive': true});
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// ================== PAUSE DIALOG ==================

  void _showPauseDialog(
      BuildContext context,
      String docId) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text("Pause Recurring Payment?"),
          content: const Text(
              "You can restart it anytime from this page."),
          actions: [
            TextButton(
              child: const Text("Cancel"),
              onPressed: () => Navigator.pop(context),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 13, 15, 104),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(12),
                ),
              ),
              child: const Text("Pause", 
              style: TextStyle(color: Colors.white),
              ),
              
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('recurring_payments')
                    .doc(docId)
                    .update({'isActive': false});

                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  /// ================== EDIT DAYS SHEET ==================

  void _showEditDaysSheet(
      BuildContext context,
      String docId,
      List<dynamic> currentDays) {
    List<int> selectedDays =
        currentDays.map((e) => e as int).toList();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Edit Recurring Days",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(height: 24),

                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: List.generate(7, (index) {
                      final dayNumber = index + 1;
                      final dayName = [
                        "Mon","Tue","Wed","Thu",
                        "Fri","Sat","Sun"
                      ][index];

                      final isSelected =
                          selectedDays.contains(dayNumber);

                      return ChoiceChip(
                        label: Text(dayName),
                        selected: isSelected,
                        selectedColor:
                            accentColor.withOpacity(0.2),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              selectedDays.add(dayNumber);
                            } else {
                              selectedDays.remove(dayNumber);
                            }
                          });
                        },
                      );
                    }),
                  ),

                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(16),
                        ),
                        padding:
                            const EdgeInsets.symmetric(
                                vertical: 14),
                      ),
                      child: const Text(
                        "Save Changes",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      onPressed: () async {
                        await FirebaseFirestore.instance
                            .collection('recurring_payments')
                            .doc(docId)
                            .update({'days': selectedDays});

                        Navigator.pop(context);
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
