import 'package:app_movil/screens/product_managment/component/product_distribution_card.dart';
import 'package:app_movil/screens/product_managment/component/summary_stat_card.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../services/images/images_provider.dart';

class ProductSummaryTab extends StatelessWidget {
  final int centerId;

  const ProductSummaryTab({
    Key? key,
    required this.centerId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<ServerImageProvider>(
      builder: (context, imageProvider, _) {
        final totalImages = imageProvider.confirmedImages.length;
        final productCounts = imageProvider.getProductCounts(onlyConfirmed: true);
        final productCategories = imageProvider.getProductCategories(onlyConfirmed: true);
        final totalProductsDetected = productCounts.values.fold(0, (sum, count) => sum + count);

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SummaryHeader(),
                    const SizedBox(height: 16),

                    // Stats Cards Row
                    SizedBox(
                      height: 120,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          SummaryStatCard(
                            title: 'Imágenes',
                            value: totalImages.toString(),
                            icon: Icons.image,
                            color: Colors.blue,
                          ),
                          SummaryStatCard(
                            title: 'Productos',
                            value: totalProductsDetected.toString(),
                            icon: Icons.category,
                            color: Colors.orange,
                          ),
                          SummaryStatCard(
                            title: 'Categorías',
                            value: productCategories.length.toString(),
                            icon: Icons.folder,
                            color: Colors.green,
                          ),
                          SummaryStatCard(
                            title: 'Centro ID',
                            value: centerId.toString(),
                            icon: Icons.store,
                            color: Colors.purple,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                    Text(
                      'Distribución de productos',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),

            // Lista de productos con conteo
            SliverList(
              delegate: SliverChildBuilderDelegate(
                    (context, index) {
                  final category = productCounts.keys.elementAt(index);
                  final count = productCounts[category] ?? 0;
                  final percentage = totalProductsDetected > 0
                      ? (count / totalProductsDetected * 100)
                      : 0.0;

                  return ProductDistributionCard(
                    category: category,
                    count: count,
                    percentage: percentage,
                    colorIndex: index,
                    onTap: () {
                      final categoryIndex = productCategories.indexOf(category);
                      if (categoryIndex >= 0) {
                        final tabController = DefaultTabController.of(context);
                        if (tabController != null) {
                          tabController.animateTo(categoryIndex + 1);
                        }
                      }
                    },
                  );
                },
                childCount: productCounts.length,
              ),
            ),

            // Bottom space
            const SliverToBoxAdapter(
              child: SizedBox(height: 24),
            ),
          ],
        );
      },
    );
  }
}

class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primary,
            radius: 24,
            child: const Icon(Icons.dashboard, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Resumen General',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Vista general de productos detectados en el centro',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}