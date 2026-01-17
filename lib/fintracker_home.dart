import 'package:flutter/material.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int hoveredIndex = -1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          _buildSideNav(),
          _buildMain(),
        ],
      ),
    );
  }

  // LEFT NAVIGATION
  Widget _buildSideNav() {
    return Container(
      width: 220,
      color: const Color(0xFF083549),
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: const [
                Icon(Icons.account_balance_wallet,
                    color: Colors.white, size: 28),
                SizedBox(width: 10),
                Text(
                  'FinTracker',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            height: 1,
            color: Colors.white24,
          ),
          const SizedBox(height: 20),

          _navItem(0, Icons.dashboard, 'Dashboard'),
          _navItem(1, Icons.receipt_long, 'Transactions'),
          _navItem(2, Icons.pie_chart, 'Budget'),
          _navItem(3, Icons.group, 'Split the bill'),
        ],
      ),
    );
  }

  // MAIN DASHBOARD
  Widget _buildMain() {
    return Expanded(
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
              const Text(
                "Dashboard",
                style: TextStyle(
                  fontSize: 24,
                  color: Color(0xFF083549),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                "Welcome, Username",
                style: TextStyle(fontSize: 16, color: Colors.blueGrey),
              ),

              const SizedBox(height: 20),

              // ===== STAT CARDS =====
              Row(
                children: [
                  _statCard(
                    title: "Total Balance",
                    amount: "₹ 25,000",
                    icon: Icons.account_balance_wallet,
                    iconColor: Colors.blue,
                  ),
                  _statCard(
                    title: "Income",
                    amount: "₹ 12,000",
                    icon: Icons.trending_up,
                    iconColor: Colors.green,
                    amountColor: const Color.fromARGB(255, 2, 135, 7),
                  ),
                  _statCard(
                    title: "Expenses",
                    amount: "₹ 7,500",
                    icon: Icons.trending_down,
                    iconColor: Colors.red,
                    amountColor: const Color.fromARGB(255, 194, 21, 9),
                  ),
                  _statCard(
                    title: "Budget",
                    amount: "₹ 10,000",
                    icon: Icons.savings,
                    iconColor: Colors.orange,
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ===== QUICK ACTIONS =====
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
                          labelColor: Colors.white,
                        ),
                        _quickActionButton(
                          icon: Icons.add_circle_outline,
                          label: "Add Income",
                          color: const Color.fromARGB(255, 2, 135, 7),
                          labelColor:Colors.white,
                        ),
                        _quickActionButton(
                          icon: Icons.flag_outlined,
                          label: "Set Goal",
                          color: const Color.fromARGB(255, 1, 66, 120),
                          labelColor: Colors.white,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ===== CHARTS =====
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _wideCard(
                        "Spending Breakdown", "Pie chart will go here"),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _wideCard(
                        "Spending Trend", "Trend chart will go here"),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ===== RECENT ACTIVITIES =====
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
                      //CARD TITLE
                      const Text(
                        "Recent Activities",
                        style:TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF083549),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Divider(
                        color: Colors.grey.withAlpha((0.3*255).round())
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                      _activityItem("Grocery", "- ₹500", "Today"),
                      Divider(
                        color: Colors.grey.withAlpha((0.3*255).round())
                      ),
                      _activityItem("Electricity Bill", "- ₹1200", "Yesterday"),
                      Divider(
                        color: Colors.grey.withAlpha((0.3*255).round())
                      ),
                      _activityItem("Salary", "+ ₹15,000", "2 days ago"),
                       Divider(
                        color: Colors.grey.withAlpha((0.3*255).round())
                      ),
                      _activityItem("Internet", "- ₹600", "3 days ago"),
                      Divider(
                        color: Colors.grey.withAlpha((0.3*255).round())
                      ),
                      _activityItem("Fuel", "- ₹1,200", "4 days ago"),
                       Divider(
                        color: Colors.grey.withAlpha((0.3*255).round())
                      ),
                      _activityItem("Coffee", "- ₹150", "5 days ago"),
                       Divider(
                        color: Colors.grey.withAlpha((0.3*255).round())
                      ),
                      _activityItem("Bonus", "+ ₹2,500", "6 days ago"),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
            ],
          ),
        ),
      ),
    );
  }

  // QUICK ACTION BUTTON
  Widget _quickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    Color labelColor=Colors.white,
  }) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        child: ElevatedButton.icon(
          onPressed: () {},
          icon: Icon(icon, color: Colors.white),
          label: Text(
            label,
            style: TextStyle(color: labelColor)
            ),
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

  // NAV ITEM
  Widget _navItem(int index, IconData icon, String label) {
    final isHovered = hoveredIndex == index;

    return MouseRegion(
      onEnter: (_) => setState(() => hoveredIndex = index),
      onExit: (_) => setState(() => hoveredIndex = -1),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isHovered ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: isHovered
                    ? const Color(0xFF083549)
                    : Colors.white),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: isHovered
                    ? const Color(0xFF083549)
                    : Colors.white,
              ),
            )
          ],
        ),
      ),
    );
  }

  // STAT CARD
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

  // WIDE CARD
  Widget _wideCard(String title, String content) {
    return Container(
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
          Text(title,
              style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF083549),
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),
          Container(
            height: 220,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFF2F4F7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(content,
                style: const TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  // RECENT ACTIVITIES CARD
 Widget _activityItem( String title, String amount, String date){
  return Padding(
    padding: const EdgeInsets.symmetric(vertical:6),
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
              color: amount.startsWith('-') ? const Color.fromARGB(255, 244, 23, 7) : const Color.fromARGB(255, 36, 165, 40),
            ),
          ),
        ],
      ),
    );
  }

 }


