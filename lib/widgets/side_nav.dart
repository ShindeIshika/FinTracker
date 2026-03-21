import 'package:flutter/material.dart';

class SideNav extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onItemTap;

  const SideNav({
    super.key,
    required this.selectedIndex,
    required this.onItemTap,
  });

  @override
  State<SideNav> createState() => _SideNavState();
}

class _SideNavState extends State<SideNav> {
  int hoveredIndex = -1;

  @override
  Widget build(BuildContext context) {
    final navItems = [
      {'icon': Icons.dashboard, 'label': 'Dashboard'},
      {'icon': Icons.receipt_long, 'label': 'Transactions'},
      {'icon': Icons.pie_chart, 'label': 'Budget'},
      {'icon': Icons.savings, 'label': 'Savings'},
      {'icon': Icons.group, 'label': 'SplitTheBill'},
      {'icon': Icons.receipt,'label':'Bill Manager'},
    ];

    return Container(
      width: 220,
      color: const Color(0xFF083549),
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
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
          const SizedBox(height: 30),

          ...List.generate(navItems.length, (index) {
            final item = navItems[index];
            final isSelected = widget.selectedIndex == index;

            return GestureDetector(
              onTap: () => widget.onItemTap(index),
              child: MouseRegion(
                onEnter: (_) => setState(() => hoveredIndex = index),
                onExit: (_) => setState(() => hoveredIndex = -1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white
                        : hoveredIndex == index
                            ? Colors.white24
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        item['icon'] as IconData,
                        color: isSelected
                            ? const Color(0xFF083549)
                            : Colors.white,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        item['label'] as String,
                        style: TextStyle(
                          color: isSelected
                              ? const Color(0xFF083549)
                              : Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
