import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math' as Math;
import '../entity/analytics_report.dart';

class ReportDetailScreen extends StatefulWidget {
  final AnalyticsReport report;

  const ReportDetailScreen({
    Key? key,
    required this.report,
  }) : super(key: key);

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedCategory = '';
  bool _showAverage = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Select the first category by default
    if (widget.report.categories.isNotEmpty) {
      _selectedCategory = widget.report.categories.first;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.report.name),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Resumen'),
            Tab(text: 'Gráficos'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSummaryTab(),
          _buildChartsTab(),
        ],
      ),
    );
  }

  Widget _buildSummaryTab() {
    // Get report statistics
    final totalCategories = widget.report.categories.length;
    final maxConsumptionCategory = widget.report.getMostConsumedCategory();
    final minConsumptionCategory = widget.report.getLeastConsumedCategory();
    final totalConsumption = widget.report.totalConsumption.values.fold(0, (sum, value) => sum + value);
    final averageDailyConsumption = widget.report.getAverageDailyConsumption();
    final peakConsumptionDays = widget.report.getPeakConsumptionDays();

    // Get period type as enum for comparison
    final periodTypeEnum = widget.report.getPeriodTypeEnum();
    final color = periodTypeEnum == PeriodType.weekly ? Colors.blue : Colors.green;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          periodTypeEnum == PeriodType.weekly
                              ? 'ANÁLISIS SEMANAL'
                              : 'ANÁLISIS MENSUAL',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Período: ${widget.report.dateRange.getFormattedRange()}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Creado: ${widget.report.getFormattedDate()}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Resumen del Análisis',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Main statistics
                  _buildInfoRow(
                    'Categorías analizadas:',
                    totalCategories.toString(),
                    Icons.category,
                  ),
                  _buildInfoRow(
                    'Consumo total:',
                    '$totalConsumption unidades',
                    Icons.shopping_basket,
                  ),
                  _buildInfoRow(
                    'Mayor consumo:',
                    maxConsumptionCategory != 'N/A'
                        ? maxConsumptionCategory
                        : 'N/A',
                    Icons.trending_up,
                    valueColor: Colors.green,
                  ),
                  _buildInfoRow(
                    'Menor consumo:',
                    minConsumptionCategory != 'N/A'
                        ? minConsumptionCategory
                        : 'N/A',
                    Icons.trending_down,
                    valueColor: Colors.orange,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Consumption by category table
          const Text(
            'Consumo por Categoría',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Table header
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      children: [
                        const Expanded(
                          flex: 3,
                          child: Text(
                            'Categoría',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const Expanded(
                          flex: 2,
                          child: Text(
                            'Consumo',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const Expanded(
                          flex: 2,
                          child: Text(
                            'Diario',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            periodTypeEnum == PeriodType.weekly
                                ? 'Pico'
                                : 'Semanal',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(),

                  // Table rows
                  ...widget.report.categories.map((category) {
                    final consumption = widget.report.totalConsumption[category] ?? 0;
                    final dailyAvg = averageDailyConsumption[category]?.toStringAsFixed(1) ?? '0';
                    final peakDay = peakConsumptionDays[category] ?? 'N/A';

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(
                              category,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              '$consumption',
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              dailyAvg,
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              periodTypeEnum == PeriodType.weekly
                                  ? peakDay
                                  : (double.parse(dailyAvg) * 7).toStringAsFixed(1),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Recommendations based on analysis
          const Text(
            'Insights y Recomendaciones',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (maxConsumptionCategory != 'N/A') ...[
                    _buildInsightItem(
                      Icons.trending_up,
                      Colors.green,
                      'Mayor demanda: $maxConsumptionCategory',
                      'Esta categoría tuvo el mayor consumo durante el período. Considera aumentar su stock.',
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (minConsumptionCategory != 'N/A' &&
                      widget.report.totalConsumption[minConsumptionCategory.split(' ').first] != 0) ...[
                    _buildInsightItem(
                      Icons.trending_down,
                      Colors.orange,
                      'Menor demanda: $minConsumptionCategory',
                      'Esta categoría tuvo el menor consumo. Evalúa si es necesario reducir su stock.',
                    ),
                    const SizedBox(height: 16),
                  ],

                  // General trend
                  _buildInsightItem(
                    Icons.insights,
                    Colors.blue,
                    'Consumo promedio diario total',
                    'El promedio de consumo diario fue de ${averageDailyConsumption.values.fold(0.0, (sum, value) => sum + value).toStringAsFixed(1)} unidades entre todas las categorías.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: Colors.blue,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 14),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightItem(IconData icon, Color color, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: color,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChartsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category selector
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Selecciona una categoría',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 40,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: widget.report.categories.length,
                      itemBuilder: (context, index) {
                        final category = widget.report.categories[index];
                        final isSelected = category == _selectedCategory;

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedCategory = category;
                            });
                          },
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.blue : Colors.transparent,
                              border: Border.all(
                                color: Colors.blue,
                                width: 1,
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Center(
                              child: Text(
                                category,
                                style: TextStyle(
                                  color: isSelected ? Colors.white : Colors.blue,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
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
          ),

          const SizedBox(height: 24),

          // Bar chart for total consumption
          const Text(
            'Consumo Total por Categoría',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildTotalConsumptionChart(),

          const SizedBox(height: 24),

          // Line chart for consumption over time
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Consumo Detallado',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              // Switch to show average
              Row(
                children: [
                  const Text('Mostrar promedio'),
                  Switch(
                    value: _showAverage,
                    onChanged: (value) {
                      setState(() {
                        _showAverage = value;
                      });
                    },
                    activeColor: Colors.blue,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_selectedCategory.isNotEmpty)
            _buildDetailedConsumptionChart(),
        ],
      ),
    );
  }

  Widget _buildTotalConsumptionChart() {
    // Get data for the chart
    final categories = widget.report.categories;
    final consumptionData = categories.map((category) {
      return widget.report.totalConsumption[category] ?? 0;
    }).toList();

    // Calculate max Y value (ensure it's at least 5 to avoid a horizontal interval of 0)
    final maxY = consumptionData.isEmpty ? 10 : Math.max(5, (consumptionData.reduce((a, b) => a > b ? a : b) * 1.2).ceil());

    // Calculate horizontal interval (ensure it's not zero)
    final horizontalInterval = Math.max(1.0, maxY / 5);

    return SizedBox(
      height: 300,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: consumptionData.isEmpty
              ? const Center(
            child: Text('No hay datos para mostrar'),
          )
              : BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxY.toDouble(),
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  tooltipBgColor: Colors.blueGrey,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    return BarTooltipItem(
                      '${categories[groupIndex]}\n',
                      const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      children: [
                        TextSpan(
                          text: '${rod.toY.round()} unidades',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      if (value >= 0 && value < categories.length) {
                        final category = categories[value.toInt()];
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            category.length > 6
                                ? '${category.substring(0, 6)}...'
                                : category,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      }
                      return const Text('');
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    getTitlesWidget: (value, meta) {
                      if (value == 0) {
                        return const Text('0');
                      }
                      return Text(value.toInt().toString());
                    },
                  ),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              borderData: FlBorderData(show: false),
              barGroups: List.generate(
                categories.length,
                    (index) => BarChartGroupData(
                  x: index,
                  barRods: [
                    BarChartRodData(
                      toY: consumptionData[index].toDouble(),
                      color: Colors.blue,
                      width: 20,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(6),
                        topRight: Radius.circular(6),
                      ),
                    ),
                  ],
                ),
              ),
              gridData: FlGridData(
                show: true,
                horizontalInterval: horizontalInterval, // Use calculated and validated value
                drawVerticalLine: false,
                getDrawingHorizontalLine: (value) {
                  return FlLine(
                    color: Colors.grey.withOpacity(0.2),
                    strokeWidth: 1,
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailedConsumptionChart() {
    // Get data for the chart
    final dataPoints = widget.report.consumptionData[_selectedCategory] ?? [];

    if (dataPoints.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(
            child: Text('No hay datos detallados para esta categoría'),
          ),
        ),
      );
    }

    // Sort points by date
    dataPoints.sort((a, b) => a.getDateTime().compareTo(b.getDateTime()));

    // Calculate max Y value (ensure it's at least 5 to avoid a horizontal interval of 0)
    final maxY = dataPoints.isEmpty
        ? 10
        : Math.max(5, (dataPoints.map((p) => p.count).reduce((a, b) => a > b ? a : b) * 1.2).ceil());

    // Calculate horizontal interval (ensure it's not zero)
    final horizontalInterval = Math.max(1.0, maxY / 5);

    // Calculate average daily consumption
    final averageConsumption = dataPoints.isEmpty
        ? 0.0
        : dataPoints.map((p) => p.count).reduce((a, b) => a + b) / dataPoints.length;

    return SizedBox(
      height: 300,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: LineChart(
            LineChartData(
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  tooltipBgColor: Colors.blueGrey,
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((spot) {
                      final date = spot.x.toInt() >= 0 && spot.x.toInt() < dataPoints.length
                          ? dataPoints[spot.x.toInt()].getFormattedDate()
                          : '';
                      return LineTooltipItem(
                        '$date\n',
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        children: [
                          TextSpan(
                            text: '${spot.y.round()} unidades',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      );
                    }).toList();
                  },
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      if (value >= 0 && value < dataPoints.length) {
                        final date = dataPoints[value.toInt()].getFormattedDate();
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            date,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      }
                      return const Text('');
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    getTitlesWidget: (value, meta) {
                      if (value == 0) {
                        return const Text('0');
                      }
                      return Text(value.toInt().toString());
                    },
                  ),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                show: true,
                horizontalInterval: horizontalInterval, // Use calculated and validated value
                drawVerticalLine: false,
                getDrawingHorizontalLine: (value) {
                  return FlLine(
                    color: Colors.grey.withOpacity(0.2),
                    strokeWidth: 1,
                  );
                },
              ),
              minX: 0,
              maxX: (dataPoints.length - 1).toDouble(),
              minY: 0,
              maxY: maxY.toDouble(),
              lineBarsData: [
                // Consumption line
                LineChartBarData(
                  spots: List.generate(
                    dataPoints.length,
                        (index) => FlSpot(
                      index.toDouble(),
                      dataPoints[index].count.toDouble(),
                    ),
                  ),
                  isCurved: true,
                  color: Colors.blue,
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: true),
                  belowBarData: BarAreaData(
                    show: true,
                    color: Colors.blue.withOpacity(0.2),
                  ),
                ),
                // Average line (optional)
                if (_showAverage)
                  LineChartBarData(
                    spots: List.generate(
                      dataPoints.length,
                          (index) => FlSpot(
                        index.toDouble(),
                        averageConsumption,
                      ),
                    ),
                    isCurved: false,
                    color: Colors.red,
                    barWidth: 2,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    dashArray: [5, 5],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}