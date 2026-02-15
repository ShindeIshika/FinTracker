import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TipsPage extends StatefulWidget {
  const TipsPage({super.key});

  @override
  State<TipsPage> createState() => _TipsPageState();
}

class _TipsPageState extends State<TipsPage> {
  List<String> tipHistory = [];

  @override
  void initState() {
    super.initState();
    loadTips();
  }

  Future<void> loadTips() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      tipHistory = prefs.getStringList('tip_history') ?? [];
    });
  }

 @override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: Colors.grey.shade100,
    appBar: AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      title: const Text(
        "Financial Tips History",
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      centerTitle: true,
    ),
    body: tipHistory.isEmpty
        ? const Center(
            child: Text(
              "No tips viewed yet.",
              style: TextStyle(color: Colors.grey),
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: tipHistory.length,
            itemBuilder: (context, index) {
              final parts = tipHistory[index].split('|');
              final date = parts[0];
              final term = parts[1];
              final tip = parts[2];

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    
                    showDialog(
  context: context,
  barrierColor: Colors.black.withOpacity(0.4),
  builder: (_) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 420, // Controls width on web
        ),
        child: Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min, // 👈 Important
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                /// Icon
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lightbulb_outline,
                      color: Colors.orange,
                      size: 24,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                /// Title
                Text(
                  term,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 4),

                /// Date
                Text(
                  date,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),

                const SizedBox(height: 16),

                Text(
                  tip,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 20),

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Close"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  },
);

                  },
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.lightbulb,
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              term,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              date,
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Tap to read full tip",
                              style: TextStyle(
                                color: Colors.blue.shade600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios,
                        size: 14,
                        color: Colors.grey,
                      )
                    ],
                  ),
                ),
              );
            },
          ),
  );
}

}
