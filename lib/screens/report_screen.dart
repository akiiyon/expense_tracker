import 'package:expense_tracker/model/expense_provider.dart';
import 'package:expense_tracker/model/user_provider.dart';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    // fetchWeeklyData();
  }

  Future<void> fetchWeeklyData() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final expenseProvider = Provider.of<ExpenseProvider>(
      context,
      listen: false,
    );
    await expenseProvider.fetchWeeklyExpenses(userProvider.userId!);
    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ExpenseProvider>(context);
    final weeklyData = provider.weeklyCategoryTotals;

    // total for percentage calculation
    final totalSpent = weeklyData.fold(0.0, (sum, item) => sum + item["total"]);

    // generate consistent random colors
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green,
        title: const Text(
          "Weekly Report",
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : weeklyData.isEmpty
          ? const Center(child: Text("No expenses this week"))
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // 🥧 Pie Chart
                  AspectRatio(
                    aspectRatio: 1.2,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                        sections: weeklyData.asMap().entries.map((entry) {
                          final index = entry.key;
                          final item = entry.value;
                          final category = item["category"];
                          final total = item["total"];
                          final percentage = totalSpent == 0
                              ? 0
                              : (total / totalSpent) * 100;

                          return PieChartSectionData(
                            color: colors[index % colors.length],
                            value: total,
                            title: "${percentage.toStringAsFixed(1)}%",
                            radius: 100,
                            titleStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 🧾 Legend / Category List
                  Expanded(
                    child: ListView.builder(
                      itemCount: weeklyData.length,
                      itemBuilder: (context, index) {
                        final item = weeklyData[index];
                        final category = item["category"];
                        final total = item["total"];
                        final color = colors[index % colors.length];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: color,
                            radius: 10,
                          ),
                          title: Text(category),
                          trailing: Text(
                            "₹${total.toStringAsFixed(2)}",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
