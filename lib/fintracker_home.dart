import 'dart:math';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_fintracker/add_transaction.dart';
import 'package:flutter_fintracker/fintracker_bills.dart';
import 'package:flutter_fintracker/fintracker_budget.dart';
import 'package:flutter_fintracker/fintracker_login.dart';
import 'package:flutter_fintracker/fintracker_savings.dart';
import 'package:flutter_fintracker/fintracker_splitbill.dart';
import 'package:flutter_fintracker/fintracker_transaction.dart';
import 'package:flutter_fintracker/previous_tips.dart';
import 'package:flutter_fintracker/recurring_payments.dart';
import 'widgets/side_nav.dart';
import 'split_bills_request_page.dart';
import 'package:http/http.dart' as http;


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

enum PieChartMode { month, year }

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _tipShownThisSession = false;
  bool _tipShown = false;

  int selectedNavIndex = 0;
  int touchedPieIndex = -1;
  String firstName = "User";

  double totalIncome = 0;
  double totalExpense = 0;
  double totalBalance = 0;
  double monthlyIncome = 0;
  double monthlyExpense = 0;

  List<Map<String, dynamic>> recentTransactions = [];
  List<Map<String, dynamic>> allTransactions = [];

  bool hasIncome = false;
  bool hasExpense = false;
  bool _isLoading = true;

  PieChartMode selectedPieMode = PieChartMode.month;
  int selectedPieMonth = DateTime.now().month;
  int selectedPieYear = DateTime.now().year;

  String get pieChartTitle {
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    if (selectedPieMode == PieChartMode.month) {
      return "Spending – ${months[selectedPieMonth - 1]} $selectedPieYear";
    } else {
      return "Spending – Year $selectedPieYear";
    }
  }

  // ── Fetch tip from API ────────────────────────────────────────────────────
  Future<Map<String, String>?> fetchTipFromAPI() async {
    try {
      final response = await http.get(
        Uri.parse('https://api.api-ninjas.com/v1/quotes?category=money'),
        headers: {'X-Api-Key': 'YOUR_API_KEY'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data != null && data.length > 0) {
          return {
            "term": "Finance Tip",
            "tip": data[0]['quote'],
          };
        }
      }
    } catch (e) {
      debugPrint("API Error: $e");
    }
    return null;
  }

  // ── Logout with confirmation ──────────────────────────────────────────────
  Future<void> _handleLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to log out?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF083549),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              "Logout",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (shouldLogout ?? false) {
      await FirebaseAuth.instance.signOut();
      if (!context.mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    }
  }

  // ── Show tip of the day (API-based) ───────────────────────────────────────
  Future<void> showTipOfTheDay() async {
    if (_tipShown) return;

    _tipShown = true;

    final today = DateTime.now().toIso8601String().split('T').first;
    final user = _auth.currentUser;
    if (user == null) return;

    final todayTip = await fetchTipFromAPI();
    if (todayTip == null) return;

    final String docId = "${today}_${todayTip['term']!.replaceAll(' ', '_')}";

    final tipDocRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('previous_tips')
        .doc(docId);

    final existingDoc = await tipDocRef.get();
    if (!existingDoc.exists) {
      await tipDocRef.set({
        'term': todayTip['term'],
        'tip': todayTip['tip'],
        'date': today,
        'shownAt': FieldValue.serverTimestamp(),
      });
    }

    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const Icon(
                  Icons.lightbulb_outline,
                  color: Color(0xFF083549),
                  size: 40,
                ),
                const SizedBox(height: 12),
                Text(
                  todayTip['term']!,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF083549),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  todayTip['tip']!,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF083549),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      "Got it",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          );
        },
      );
    });
  }

  // ── Show local tip (Firestore-based) ─────────────────────────────────────
  Future<void> showLoginTipIfNeeded() async {
    if (_tipShownThisSession) return;

    final user = _auth.currentUser;
    if (user == null) return;

    _tipShownThisSession = true;

    try {
      final previousTipsRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('previous_tips');

      final previousTipsSnapshot = await previousTipsRef.get();

      final Set<String> shownTerms = previousTipsSnapshot.docs
          .map((doc) {
            final data = doc.data();
            return (data['term'] ?? '').toString().trim();
          })
          .where((term) => term.isNotEmpty)
          .toSet();

      final List<Map<String, String>> unseenTips = financeTips.where((tip) {
        final term = (tip['term'] ?? '').trim();
        return !shownTerms.contains(term);
      }).toList();

      if (unseenTips.isEmpty) return;

      final Map<String, String> selectedTip =
          unseenTips[Random().nextInt(unseenTips.length)];

      final String term = selectedTip['term'] ?? '';
      final String tip = selectedTip['tip'] ?? '';

      final String docId = term.replaceAll(' ', '_').toLowerCase();

      final existingDoc = await previousTipsRef.doc(docId).get();
      if (!existingDoc.exists) {
        await previousTipsRef.doc(docId).set({
          'term': term,
          'tip': tip,
          'date': DateTime.now().toIso8601String().split('T').first,
          'shownAt': FieldValue.serverTimestamp(),
        });
      }

      if (!mounted) return;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (_) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const Icon(
                    Icons.lightbulb_outline,
                    color: Color(0xFF083549),
                    size: 40,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "💡 $term",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF083549),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    tip,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF083549),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(
                        "Got it",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            );
          },
        );
      });
    } catch (e) {
      debugPrint("Error showing login tip: $e");
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showLoginTipIfNeeded();
    });
    Future.delayed(const Duration(milliseconds: 500), () {
      showTipOfTheDay();
    });
    fetchDashboardData();
    fetchUserName();
    _generateRecurringTransactions();
  }

  Future<void> _generateRecurringTransactions() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final today = DateTime.now();
    final todayWeekday = today.weekday;

    final recurringSnapshot = await FirebaseFirestore.instance
        .collection('recurring_payments')
        .where('uid', isEqualTo: user.uid)
        .where('isActive', isEqualTo: true)
        .get();

    for (var doc in recurringSnapshot.docs) {
      final data = doc.data();
      final List days = data['daysOfWeek'] ?? [];

      if (!days.contains(todayWeekday)) continue;

      final lastGenerated = data['lastGeneratedDate'] != null
          ? (data['lastGeneratedDate'] as Timestamp).toDate()
          : null;

      final alreadyGeneratedToday = lastGenerated != null &&
          lastGenerated.year == today.year &&
          lastGenerated.month == today.month &&
          lastGenerated.day == today.day;

      if (alreadyGeneratedToday) continue;

      await FirebaseFirestore.instance.collection('transactions').add({
        'uid': user.uid,
        'type': data['type'],
        'amount': data['amount'],
        'category': data['category'],
        'account': data['account'],
        'date': Timestamp.fromDate(today),
        'createdAt': FieldValue.serverTimestamp(),
        'isAutoGenerated': true,
      });

      await doc.reference.update({
        'lastGeneratedDate': Timestamp.fromDate(today),
      });
    }
  }

  void handleNavTap(int index) {
    if (index == selectedNavIndex) return;
    setState(() => selectedNavIndex = index);

    switch (index) {
      case 0: break;
      case 1:
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const TransactionsPage()));
        break;
      case 2:
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const BudgetPlannerScreen()));
        break;
      case 3:
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const SavingsPage()));
        break;
      case 4:
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const SplitBillPage()));
        break;
      case 5:
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const BillsPage()));
        break;
    }
  }

  Future<void> fetchUserName() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (doc.exists && mounted) {
      setState(() => firstName = doc['firstName'] ?? "User");
    }
  }

  Future<void> fetchDashboardData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    double income = 0;
    double expense = 0;
    double mIncome = 0;
    double mExpense = 0;

    final now = DateTime.now();

    final snapshot = await _firestore
        .collection('transactions')
        .where('uid', isEqualTo: user.uid)
        .get();

    List<Map<String, dynamic>> tempList = [];

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final amount = (data['amount'] as num).toDouble();
      final type = data['type'];

      if (type == 'income') income += amount;
      else if (type == 'expense') expense += amount;

      if (data['date'] != null && data['date'] is Timestamp) {
        final txDate = (data['date'] as Timestamp).toDate();
        if (txDate.year == now.year && txDate.month == now.month) {
          if (type == 'income') mIncome += amount;
          else if (type == 'expense') mExpense += amount;
        }
        tempList.add(data);
      }
    }

    tempList.sort((a, b) {
      final aDate = a['date'] as Timestamp;
      final bDate = b['date'] as Timestamp;
      return bDate.compareTo(aDate);
    });

    if (!mounted) return;

    setState(() {
      totalIncome = income;
      totalExpense = expense;
      totalBalance = income - expense;
      monthlyIncome = mIncome;
      monthlyExpense = mExpense;
      allTransactions = tempList;
      recentTransactions = tempList.take(8).toList();
      hasIncome = income > 0;
      hasExpense = expense > 0;
      _isLoading = false;
    });
  }

  Map<String, double> getCategoryTotals() {
    Map<String, double> categoryTotals = {};

    for (var tx in allTransactions) {
      if (tx['type'] != 'expense') continue;
      if (tx['date'] == null || tx['date'] is! Timestamp) continue;

      final txDate = (tx['date'] as Timestamp).toDate();

      bool include = false;
      if (selectedPieMode == PieChartMode.month) {
        include = txDate.year == selectedPieYear && txDate.month == selectedPieMonth;
      } else {
        include = txDate.year == selectedPieYear;
      }

      if (!include) continue;

      final category = tx['category'].toString().trim();
      final amount = (tx['amount'] as num).toDouble();
      categoryTotals[category] = (categoryTotals[category] ?? 0) + amount;
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
        monthlyData[month]!['income'] = monthlyData[month]!['income']! + amount;
      } else {
        monthlyData[month]!['expense'] = monthlyData[month]!['expense']! + amount;
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
          BarChartRodData(toY: data['income']!, width: 6, color: Colors.green),
          BarChartRodData(toY: data['expense']!, width: 6, color: Colors.red),
        ],
        barsSpace: 3,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF083549),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        title: const Text(
          "Dashboard",
          style: TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection("split_bill_requests")
                .where("toUid", isEqualTo: _auth.currentUser?.uid)
                .where("status", isEqualTo: "pending")
                .snapshots(),
            builder: (context, snapshot) {
              final count = snapshot.data?.docs.length ?? 0;
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications, color: Colors.white),
                    tooltip: "Split Bill Requests",
                    onPressed: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const SplitBillRequestsPage())),
                  ),
                  if (count > 0)
                    Positioned(
                      right: 8, top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                        constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                        child: Text("$count",
                            style: const TextStyle(color: Colors.white, fontSize: 10),
                            textAlign: TextAlign.center),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.repeat, color: Colors.white),
            tooltip: "Recurring Payments",
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const RecurringPaymentsPage())),
          ),
          IconButton(
            icon: const Icon(Icons.lightbulb, color: Colors.yellow),
            tooltip: "Finance Tips",
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const TipsPage())),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: "Logout",
            onPressed: _handleLogout,
          ),
        ],
      ),
      drawer: Drawer(
        child: SideNav(selectedIndex: selectedNavIndex, onItemTap: handleNavTap),
      ),
      body: Container(
        padding: const EdgeInsets.all(12),
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
              const SizedBox(height: 6),
              Text("Welcome, $firstName",
                  style: const TextStyle(fontSize: 16, color: Colors.blueGrey)),
              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(child: _statCard(
                    title: "Total Balance",
                    amount: "₹ ${totalBalance.toStringAsFixed(0)}",
                    subtitle: "All time",
                    icon: Icons.account_balance_wallet,
                    iconColor: Colors.blue,
                  )),
                  const SizedBox(width: 8),
                  Expanded(child: _statCard(
                    title: "Income",
                    amount: "₹ ${monthlyIncome.toStringAsFixed(0)}",
                    subtitle: "This month",
                    icon: Icons.trending_up,
                    iconColor: Colors.green,
                    amountColor: const Color.fromARGB(255, 2, 135, 7),
                  )),
                  const SizedBox(width: 8),
                  Expanded(child: _statCard(
                    title: "Expenses",
                    amount: "₹ ${monthlyExpense.toStringAsFixed(0)}",
                    subtitle: "This month",
                    icon: Icons.trending_down,
                    iconColor: Colors.red,
                    amountColor: const Color.fromARGB(255, 194, 21, 9),
                  )),
                ],
              ),

              const SizedBox(height: 20),

              if (hasIncome)
                Row(
                  children: [
                    _quickActionButton(
                      icon: Icons.add_circle_outline,
                      label: "Add Income",
                      color: const Color.fromARGB(255, 2, 135, 7),
                      onPressed: () async {
                        final result = await Navigator.push(context,
                            MaterialPageRoute(builder: (_) => AddTransactionPage(type: 'income')));
                        if (result == true) fetchDashboardData();
                      },
                    ),
                    const SizedBox(width: 10),
                    _quickActionButton(
                      icon: Icons.remove_circle_outline,
                      label: "Add Expense",
                      color: const Color.fromARGB(255, 194, 21, 9),
                      onPressed: () async {
                        final result = await Navigator.push(context,
                            MaterialPageRoute(builder: (_) => AddTransactionPage(type: 'expense')));
                        if (result == true) fetchDashboardData();
                      },
                    ),
                  ],
                ),

              const SizedBox(height: 20),

              if (!_isLoading && !hasIncome) _introCard(),

              if (hasExpense) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(pieChartTitle,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF083549))),
                          ),
                          Flexible(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _filterToggle("Month", selectedPieMode == PieChartMode.month, () {
                                          setState(() { selectedPieMode = PieChartMode.month; touchedPieIndex = -1; });
                                        }),
                                        _filterToggle("Year", selectedPieMode == PieChartMode.year, () {
                                          setState(() { selectedPieMode = PieChartMode.year; touchedPieIndex = -1; });
                                        }),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (selectedPieMode == PieChartMode.month)
                                    DropdownButtonHideUnderline(
                                      child: DropdownButton<int>(
                                        value: selectedPieMonth,
                                        style: const TextStyle(color: Color(0xFF083549), fontSize: 13, fontWeight: FontWeight.w600),
                                        items: List.generate(12, (i) {
                                          const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
                                          return DropdownMenuItem(value: i + 1, child: Text(m[i]));
                                        }),
                                        onChanged: (value) {
                                          if (value == null) return;
                                          setState(() { selectedPieMonth = value; touchedPieIndex = -1; });
                                        },
                                      ),
                                    ),
                                  const SizedBox(width: 8),
                                  DropdownButtonHideUnderline(
                                    child: DropdownButton<int>(
                                      value: selectedPieYear,
                                      style: const TextStyle(color: Color(0xFF083549), fontSize: 13, fontWeight: FontWeight.w600),
                                      items: List.generate(5, (i) {
                                        final year = DateTime.now().year - i;
                                        return DropdownMenuItem(value: year, child: Text("$year"));
                                      }),
                                      onChanged: (value) {
                                        if (value == null) return;
                                        setState(() { selectedPieYear = value; touchedPieIndex = -1; });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 200,
                        child: Builder(builder: (context) {
                          final categoryTotals = getCategoryTotals();
                          final total = categoryTotals.values.fold(0.0, (a, b) => a + b);
                          return Center(
                            child: PieChart(PieChartData(
                              centerSpaceRadius: 0,
                              sectionsSpace: 1,
                              pieTouchData: PieTouchData(
                                touchCallback: (event, response) {
                                  setState(() {
                                    if (!event.isInterestedForInteractions ||
                                        response == null || response.touchedSection == null) {
                                      touchedPieIndex = -1;
                                    } else {
                                      touchedPieIndex = response.touchedSection!.touchedSectionIndex;
                                    }
                                  });
                                },
                              ),
                              sections: categoryTotals.isEmpty
                                  ? [PieChartSectionData(value: 1, title: 'No Data', color: Colors.grey, radius: 70,
                                      titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))]
                                  : List.generate(categoryTotals.length, (index) {
                                      final entry = categoryTotals.entries.elementAt(index);
                                      final percent = total == 0 ? 0 : (entry.value / total) * 100;
                                      final isTouched = index == touchedPieIndex;
                                      return PieChartSectionData(
                                        value: entry.value,
                                        radius: isTouched ? 80 : 70,
                                        color: categoryColors[entry.key] ??
                                            Colors.primaries[index % Colors.primaries.length],
                                        title: isTouched ? "${entry.key}\n${percent.toStringAsFixed(1)}%" : "",
                                        titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                                      );
                                    }),
                            )),
                          );
                        }),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                Container(
                  height: 240,
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Income vs Expenses",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF083549))),
                      const SizedBox(height: 12),
                      Expanded(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: BarChart(BarChartData(
                              maxY: getMaxY(),
                              barGroups: getMonthlyBarGroups(),
                              gridData: FlGridData(show: false),
                              borderData: FlBorderData(show: false),
                              titlesData: FlTitlesData(
                                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 42,
                                    interval: getMaxY() / 5,
                                    getTitlesWidget: (value, meta) {
                                      final text = value >= 1000
                                          ? "${(value / 1000).toStringAsFixed(1)}K"
                                          : value.toInt().toString();
                                      return Text(text, style: const TextStyle(fontSize: 9), softWrap: false);
                                    },
                                  ),
                                ),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 28,
                                    getTitlesWidget: (value, meta) {
                                      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
                                      final index = value.toInt() - 1;
                                      if (index < 0 || index > 11) return const SizedBox();
                                      return Text(months[index], style: const TextStyle(fontSize: 9));
                                    },
                                  ),
                                ),
                              ),
                            )),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (hasIncome) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  height: 260,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Recent Activities",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF083549))),
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
    );
  }

  Widget _introCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.auto_graph, size: 60, color: Colors.blue.shade300),
          const SizedBox(height: 16),
          const Text("Start tracking your money",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF083549))),
          const SizedBox(height: 10),
          const Text("You're 2 steps away:", style: TextStyle(fontSize: 14, color: Colors.blueGrey)),
          const SizedBox(height: 8),
          const Text("1. Add your income 💰\n2. Add expenses 🧾",
              textAlign: TextAlign.center, style: TextStyle(fontSize: 14)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () async {
              final result = await Navigator.push(context,
                  MaterialPageRoute(builder: (_) => AddTransactionPage(type: 'income')));
              if (result == true) fetchDashboardData();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF083549),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text("Add Income", style: TextStyle(color: Colors.white)),
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

  Widget _filterToggle(String label, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF083549) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                color: isActive ? Colors.white : Colors.grey)),
      ),
    );
  }

  Widget _statCard({
    required String title,
    required String amount,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    Color? amountColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: iconColor.withOpacity(0.18),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(height: 8),
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
          const SizedBox(height: 4),
          Text(amount, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                  color: amountColor ?? const Color(0xFF083549))),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _quickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Expanded(
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white, size: 18),
        label: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
          backgroundColor: color,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  Widget _activityItem(String title, String amount, String date) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF083549))),
                Text(date, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(amount,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: amount.startsWith('-')
                    ? const Color.fromARGB(255, 244, 23, 7)
                    : const Color.fromARGB(255, 36, 165, 40),
              )),
        ],
      ),
    );
  }
}

class FintrackerHome extends StatelessWidget {
  const FintrackerHome({super.key});

  @override
  Widget build(BuildContext context) => const DashboardScreen();
}