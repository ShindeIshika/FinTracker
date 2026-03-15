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
            fontSize: 18,
            color: primaryColor,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
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

          final int active =
              docs.where((d) => d.data()['isActive'] == true).length;
          final int paused =
              docs.where((d) => d.data()['isActive'] == false).length;

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              const Text(
                "Manage your automated transactions",
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 18),

              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      "Active",
                      active.toString(),
                      const LinearGradient(
                        colors: [
                          Color.fromARGB(255, 12, 13, 94),
                          Color.fromARGB(255, 8, 4, 87),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildStatCard(
                      "Paused",
                      paused.toString(),
                      const LinearGradient(
                        colors: [
                          Color.fromARGB(255, 200, 31, 31),
                          Color.fromARGB(255, 193, 22, 22),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 22),

              ...docs.map(
                (doc) => _buildRecurringCard(
                  context,
                  doc.id,
                  doc.data(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, Gradient gradient) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            blurRadius: 10,
            color: Colors.black12,
            offset: Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecurringCard(
      BuildContext context,
      String docId,
      Map<String, dynamic> data) {
    final isActive = data['isActive'] ?? true;
    final List<dynamic> days = data['days'] ?? [];

    final dayNames = [
      "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"
    ];

    final String daysText = days.isEmpty
        ? "No days selected"
        : days.map((d) => dayNames[d - 1]).join(" • ");

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: isActive ? 1.0 : 0.45,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _showEditDaysSheet(context, docId, days),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                blurRadius: 12,
                color: Colors.black12,
                offset: Offset(0, 5),
              )
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 13, 15, 104)
                      .withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.repeat,
                  color: Color.fromARGB(255, 13, 15, 104),
                  size: 20,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['category'] ?? "No Category",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "₹${data['amount']}",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      daysText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              Transform.scale(
                scale: 0.9,
                child: Switch(
                  value: isActive,
                  activeColor: const Color.fromARGB(255, 13, 15, 104),
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPauseDialog(
      BuildContext context,
      String docId) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            "Pause Recurring Payment?",
            style: TextStyle(fontSize: 18),
          ),
          content: const Text(
            "You can restart it anytime from this page.",
            style: TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              child: const Text("Cancel"),
              onPressed: () => Navigator.pop(context),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 13, 15, 104),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                "Pause",
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

  void _showEditDaysSheet(
      BuildContext context,
      String docId,
      List<dynamic> currentDays) {
    List<int> selectedDays =
        currentDays.map((e) => e as int).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 18,
                right: 18,
                top: 18,
                bottom: MediaQuery.of(context).viewInsets.bottom + 18,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Edit Recurring Days",
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(height: 18),

                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(7, (index) {
                      final dayNumber = index + 1;
                      final dayName = [
                        "Mon",
                        "Tue",
                        "Wed",
                        "Thu",
                        "Fri",
                        "Sat",
                        "Sun"
                      ][index];

                      final isSelected =
                          selectedDays.contains(dayNumber);

                      return ChoiceChip(
                        label: Text(
                          dayName,
                          style: const TextStyle(fontSize: 12),
                        ),
                        selected: isSelected,
                        selectedColor:
                            accentColor.withOpacity(0.2),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              if (!selectedDays.contains(dayNumber)) {
                                selectedDays.add(dayNumber);
                              }
                            } else {
                              selectedDays.remove(dayNumber);
                            }
                          });
                        },
                      );
                    }),
                  ),

                  const SizedBox(height: 18),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: 13,
                        ),
                      ),
                      child: const Text(
                        "Save Changes",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
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