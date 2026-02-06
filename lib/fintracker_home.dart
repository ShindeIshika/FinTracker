import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_fintracker/fintracker_login.dart';
import 'package:flutter_fintracker/fintracker_splitbill.dart';
import 'package:flutter_fintracker/add_transaction.dart';
import 'package:flutter_fintracker/fintracker_budget.dart';
import 'package:fl_chart/fl_chart.dart';
import 'widgets/side_nav.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';

final List<Map<String, String>> financeTips = [
  {
    "term": "Emergency Fund",
    "tip": "Save at least 3–6 months of expenses for unexpected situations."
  },
  {
    "term": "50/30/20 Rule",
    "tip": "50% needs, 30% wants, 20% savings."
  },
  {
    "term": "Compound Interest",
    "tip": "Money grows faster when interest earns interest."
  },
  {
    "term": "Budget",
    "tip": "A plan for every rupee gives you control, not restriction."
  },
  {
    "term": "SIP",
    "tip": "Invest a fixed amount regularly to reduce market risk."
  },
];

final Map<String, Color> categoryColors = {
  'Food': const Color.fromARGB(255, 91, 54, 0),
  'Transport': const Color.fromARGB(255, 2, 54, 97),
  'Shopping': const Color.fromARGB(255, 68, 2, 79),
  'Entertainment': const Color.fromARGB(255, 156, 12, 2),
  'Bills': const Color.fromARGB(255, 0, 100, 90),
  'Others': const Color.fromARGB(255, 89, 89, 89),
  'General': const Color.fromARGB(255, 151, 23, 106),
};

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  int selectedNavIndex = 0;
  int touchedPieIndex = -1;
  String firstName = "User";

  double totalIncome = 0;
  double totalExpense = 0;
  double totalBalance = 0;

  List<Map<String, dynamic>> recentTransactions = [];
  List<Map<String, dynamic>> allTransactions = [];

  bool hasIncome = false;
  bool hasExpense = false;

  Future<void> showTipOfTheDay() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().split('T').first;
    final lastShown = prefs.getString('tip_last_shown');

    if (lastShown == today) return;

    final randomTip = financeTips[Random().nextInt(financeTips.length)];

    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (_) => AlertDialog(
          title: Text(
            "💡 ${randomTip['term']}",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text(randomTip['tip']!),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("Got it"),
            ),
          ],
        ),
      );
    });

    await prefs.setString('tip_last_shown', today);
  }

  @override
  void initState() {
    super.initState();
    showTipOfTheDay();
    fetchDashboardData();
    fetchUserName();
  }

  void handleNavTap(int index) {
  if (index == selectedNavIndex) return;

  setState(() {
    selectedNavIndex = index;
  });

  switch (index) {
    case 0: // Dashboard
      // Already on dashboard, do nothing
      break;
    case 1: // Transactions
      // Navigate to transactions page if exists
      break;
    case 2: // Budget
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const BudgetPlannerScreen()),
      );
      break;
    case 3: // Savings
      // Navigate to savings page if exists
      break;
    case 4: // Split Bills
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const SplitBillsScreen()),
      );
      break;
  }
  }

  Future<void> fetchUserName() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (doc.exists) {
      setState(() {
        firstName = doc['firstName'];
      });
    }
  }

  Future<void> fetchDashboardData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    double income = 0;
    double expense = 0;

    final snapshot = await _firestore
        .collection('transactions')
        .where('uid', isEqualTo: user.uid)
        .get();

    List<Map<String, dynamic>> tempList = [];
    for (var doc in snapshot.docs) {
      final data = doc.data();
      if (data['type'] == 'income') {
        income += (data['amount'] as num).toDouble();
      } else if (data['type'] == 'expense') {
        expense += (data['amount'] as num).toDouble();
      }
      tempList.add(data);
    }

    tempList.sort((a, b) {
      final aDate = (a['date'] as Timestamp).toDate();
      final bDate = (b['date'] as Timestamp).toDate();
      return bDate.compareTo(aDate);
    });

    setState(() {
      totalIncome = income;
      totalExpense = expense;
      totalBalance = income - expense;
      allTransactions = tempList;
      recentTransactions = tempList.take(8).toList();
      hasIncome = income > 0;
      hasExpense = expense > 0;
    });
  }

  Map<String, double> getCategoryTotals() {
    Map<String, double> categoryTotals = {};
    for (var tx in allTransactions) {
      if (tx['type'] == 'expense') {
        String category = tx['category'].toString().trim();
        double amount = (tx['amount'] as num).toDouble();
        categoryTotals[category] =
            (categoryTotals[category] ?? 0) + amount;
      }
    }
    return categoryTotals;
  }

  Map<int, Map<String, double>> getMonthlyIncomeExpense() {
    Map<int, Map<String, double>> monthlyData = {};
    for (var tx in allTransactions) {
      if (tx['date'] == null) continue;
      final date = (tx['date'] as Timestamp).toDate();
      final month = date.month;
      monthlyData.putIfAbsent(month, () => {'income': 0, 'expense': 0});
      final amount = (tx['amount'] as num).toDouble();
      if (tx['type'] == 'income') {
        monthlyData[month]!['income'] =
            monthlyData[month]!['income']! + amount;
      } else {
        monthlyData[month]!['expense'] =
            monthlyData[month]!['expense']! + amount;
      }
    }
    return monthlyData;
  }

  double getMaxY() {
    double maxY = 0;
    getMonthlyIncomeExpense().forEach((_, data) {
      final total = data['income']! + data['expense']!;
      if (total > maxY) maxY = total;
    });
    return maxY == 0 ? 10 : maxY * 1.2;
  }

  List<BarChartGroupData> getMonthlyBarGroups() {
    final monthly = getMonthlyIncomeExpense();
    return List.generate(12, (i) {
      final data = monthly[i + 1] ?? {'income': 0.0, 'expense': 0.0};
      return BarChartGroupData(
        x: i + 1,
        barRods: [
          BarChartRodData(toY: data['income']!, width: 8, color: Colors.green),
          BarChartRodData(toY: data['expense']!, width: 8, color: Colors.red),
        ],
        barsSpace: 4,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          SideNav(
            selectedIndex: selectedNavIndex,
            onItemTap: handleNavTap,
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFF7FBFF), Color(0xFFEFF3F6)],
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Dashboard",
                          style: TextStyle(
                            fontSize: 24,
                            color: Color(0xFF083549),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.logout),
                          onPressed: () async {
                            await FirebaseAuth.instance.signOut();
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const LoginPage(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Welcome, $firstName",
                      style:
                          const TextStyle(fontSize: 16, color: Colors.blueGrey),
                    ),
                    const SizedBox(height: 20),

                    // ------------------- Stat Cards -------------------
                    Row(
                      children: [
                        _statCard(
                          title: "Total Balance",
                          amount: "₹ ${totalBalance.toStringAsFixed(0)}",
                          icon: Icons.account_balance_wallet,
                          iconColor: Colors.blue,
                        ),
                        _statCard(
                          title: "Income",
                          amount: "₹ ${totalIncome.toStringAsFixed(0)}",
                          icon: Icons.trending_up,
                          iconColor: Colors.green,
                          amountColor: const Color.fromARGB(255, 2, 135, 7),
                        ),
                        _statCard(
                          title: "Expenses",
                          amount: "₹ ${totalExpense.toStringAsFixed(0)}",
                          icon: Icons.trending_down,
                          iconColor: Colors.red,
                          amountColor: const Color.fromARGB(255, 194, 21, 9),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // ------------------- Quick Actions -------------------
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 6,
                            offset: Offset(0, 3),
                          )
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Quick Actions",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF083549),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _quickActionButton(
                                icon: Icons.remove_circle_outline,
                                label: "Add Expense",
                                color: const Color.fromARGB(255, 194, 21, 9),
                                onPressed: () async {
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          AddTransactionPage(type: 'expense'),
                                    ),
                                  );
                                  if (result == true) {
                                    fetchDashboardData();
                                  }
                                },
                              ),
                              _quickActionButton(
                                icon: Icons.add_circle_outline,
                                label: "Add Income",
                                color: const Color.fromARGB(255, 2, 135, 7),
                                onPressed: () async {
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          AddTransactionPage(type: 'income'),
                                    ),
                                  );
                                  if (result == true) {
                                    fetchDashboardData();
                                  }
                                },
                              ),
                              //_quickActionButton(
                               // icon: Icons.flag_outlined,
                               // label: "Set Goal",
                               // color: const Color.fromARGB(255, 1, 66, 120),
                               // onPressed: () {},
                              //),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ------------------- Intro Card (NEW USER) -------------------
                    if (!hasIncome)
                      _introCard(),

                    // ------------------- Spending Breakdown & Income vs Expense -------------------
                    if (hasExpense) ...[
                      const SizedBox(height: 20),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 6,
                                    offset: Offset(0, 3),
                                  )
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Spending Breakdown",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF083549),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    height: 230,
                                    child: PieChart(
                                      PieChartData(
                                        centerSpaceRadius: 0,
                                        sectionsSpace: 2,
                                        pieTouchData: PieTouchData(
                                          touchCallback: (event, response) {
                                            setState(() {
                                              if (!event.isInterestedForInteractions ||
                                                  response == null ||
                                                  response.touchedSection ==
                                                      null) {
                                                touchedPieIndex = -1;
                                              } else {
                                                touchedPieIndex =
                                                    response.touchedSection!
                                                        .touchedSectionIndex;
                                              }
                                            });
                                          },
                                        ),
                                        sections: getCategoryTotals().isEmpty
                                            ? [
                                                PieChartSectionData(
                                                  value: 1,
                                                  title: 'No Data',
                                                  color: Colors.grey,
                                                )
                                              ]
                                            : List.generate(
                                                getCategoryTotals().length,
                                                (index) {
                                                  final entry = getCategoryTotals()
                                                      .entries
                                                      .elementAt(index);
                                                  final total = getCategoryTotals()
                                                      .values
                                                      .fold(0.0, (a, b) => a + b);
                                                  final percent =
                                                      total == 0 ? 0 : (entry.value / total) * 100;
                                                  final isTouched =
                                                      index == touchedPieIndex;

                                                  return PieChartSectionData(
                                                    value: entry.value,
                                                    radius: isTouched ? 110 : 95,
                                                    color: categoryColors[entry.key] ??
                                                        Colors.primaries[index %
                                                            Colors.primaries.length],
                                                    title: isTouched
                                                        ? "${entry.key}\n${percent.toStringAsFixed(1)}%"
                                                        : "",
                                                    titleStyle: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 14,
                                                    ),
                                                  );
                                                },
                                              ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Flexible(
                            child: Container(
                              height: 300,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 6,
                                    offset: Offset(0, 3),
                                  )
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Income vs Expenses",
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF083549)),
                                  ),
                                  const SizedBox(height: 12),
                                  Expanded(
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: SizedBox(
                                        width: 900,
                                        child: BarChart(
                                          BarChartData(
                                            maxY: getMaxY(),
                                            barGroups: getMonthlyBarGroups(),
                                            gridData: FlGridData(show: false),
                                            borderData: FlBorderData(show: false),
                                            titlesData: FlTitlesData(
                                              leftTitles: AxisTitles(
                                                sideTitles: SideTitles(
                                                  showTitles: true,
                                                  reservedSize: 50,
                                                  interval: getMaxY() / 5,
                                                ),
                                              ),
                                              bottomTitles: AxisTitles(
                                                sideTitles: SideTitles(
                                                  showTitles: true,
                                                  reservedSize: 40,
                                                  getTitlesWidget: (value, meta) {
                                                    const months = [
                                                      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                                                      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
                                                    ];
                                                    final index = value.toInt() - 1;
                                                    if (index < 0 || index > 11) return const SizedBox();
                                                    return Text(
                                                      months[index],
                                                      style: const TextStyle(fontSize: 11),
                                                    );
                                                  },
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],

                    // ------------------- Recent Activities -------------------
                    if (hasIncome) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        height: 260,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 6,
                              offset: Offset(0, 3),
                            )
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Recent Activities",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF083549),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: SingleChildScrollView(
                                child: Column(
                                  children: recentTransactions.map((tx) {
                                    final isExpense = tx['type'] == 'expense';
                                    final amount = tx['amount'];
                                    final title = tx['category'];
                                    final date = (tx['date'] as Timestamp).toDate();

                                    return _activityItem(
                                      title,
                                      "${isExpense ? '-' : '+'} ₹$amount",
                                      "${date.day}/${date.month}/${date.year}",
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------- Intro Card Widget -------------------
  Widget _introCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.auto_graph, size: 60, color: Colors.blue.shade300),
          const SizedBox(height: 16),
          const Text(
            "Welcome to FinTracker!",
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue),
          ),
          const SizedBox(height: 8),
          const Text(
            "Add your first income to start tracking your finances.\nThen add expenses to see your spending breakdown.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.blueGrey),
          ),
          const SizedBox(height: 16),
          Text(
            "💡 Tip: ${financeTips[Random().nextInt(financeTips.length)]['tip']}",
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
          ),
        ],
      ),
    );
  }

  // ------------------- Stat Card -------------------
  Widget _statCard({
    required String title,
    required String amount,
    required IconData icon,
    required Color iconColor,
    Color? amountColor,
  }) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: iconColor.withOpacity(0.18),
              child: Icon(icon, color: iconColor),
            ),
            const SizedBox(height: 10),
            Text(title,
                style:
                    const TextStyle(fontSize: 14, color: Colors.blueGrey)),
            const SizedBox(height: 6),
            Text(
              amount,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: amountColor ?? const Color(0xFF083549),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------- Quick Action Button -------------------
  Widget _quickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        child: ElevatedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, color: Colors.white),
          label: Text(label, style: const TextStyle(color: Colors.white)),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            backgroundColor: color,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ),
    );
  }

  // ------------------- Activity Item -------------------
  Widget _activityItem(String title, String amount, String date) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF083549),
                ),
              ),
              Text(
                date,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          Text(
            amount,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: amount.startsWith('-')
                  ? const Color.fromARGB(255, 244, 23, 7)
                  : const Color.fromARGB(255, 36, 165, 40),
            ),
          ),
        ],
      ),
    );
  }
}
