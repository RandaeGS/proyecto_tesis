import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path/path.dart' as path;

import '../../../entities/analisysresult.dart';
import '../../../screens/image_capture_screen.dart';


class ProductManagementScreen extends StatefulWidget {
  final Map<String, AnalysisResult> analysisResults;
  final int? centerId;

  const ProductManagementScreen({
    Key? key,
    required this.analysisResults,
    this.centerId,
  }) : super(key: key);

  @override
  State<ProductManagementScreen> createState() => _ProductManagementScreenState();
}

class _ProductManagementScreenState extends State<ProductManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, int> _productCounts = {};
  List<String> _productCategories = [];

  @override
  void initState() {
    super.initState();
    _processProductData();
    _tabController = TabController(length: _productCategories.length + 1, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _processProductData() {
    // Conteo de productos por categoría
    final Map<String, int> counts = {};
    final Set<String> categories = {};

    widget.analysisResults.forEach((path, result) {
      for (var detection in result.detecciones) {
        final String className = detection['class'] ?? 'unknown';
        counts[className] = (counts[className] ?? 0) + 1;
        categories.add(className);
      }
    });

    setState(() {
      _productCounts = counts;
      _productCategories = categories.toList()..sort();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Productos'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [
            const Tab(text: 'Resumen'),
            ..._productCategories.map((category) => Tab(text: category)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSummaryTab(),
          ..._productCategories.map((category) => _buildCategoryTab(category)),
        ],
      ),
    );
  }

  Widget _buildSummaryTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tarjeta de estadísticas
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Estadísticas generales',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Divider(),
                  _buildStatRow('Total de imágenes', '${widget.analysisResults.length}'),
                  _buildStatRow('Total de productos', '${_productCounts.values.fold(0, (sum, count) => sum + count)}'),
                  _buildStatRow('Categorías', '${_productCategories.length}'),

                  // Información del centro si está disponible
                  if (widget.centerId != null) ...[
                    const Divider(),
                    _buildStatRow('Centro ID', '${widget.centerId}'),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Distribución de productos
          const Text(
            'Distribución de productos',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),

          // Lista de productos con conteo
          ...List.generate(_productCounts.length, (index) {
            final category = _productCounts.keys.elementAt(index);
            final count = _productCounts[category] ?? 0;
            final percentage = (count / _productCounts.values.fold(0, (sum, count) => sum + count) * 100).toStringAsFixed(1);

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.primaries[index % Colors.primaries.length],
                  child: Text(
                    category.substring(0, 1).toUpperCase(),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(category),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      count.toString(),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text('$percentage%', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  ],
                ),
                onTap: () {
                  _tabController.animateTo(_productCategories.indexOf(category) + 1);
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCategoryTab(String category) {
    // Filtrar imágenes que contienen esta categoría
    final imagesWithCategory = widget.analysisResults.entries
        .where((entry) => entry.value.detecciones
        .any((detection) => detection['class'] == category))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cabecera con información de la categoría
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey.shade100,
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.blue,
                child: Text(
                  category.substring(0, 1).toUpperCase(),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold
                    ),
                  ),
                  Text(
                    '${_productCounts[category] ?? 0} productos en ${imagesWithCategory.length} imágenes',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Lista de imágenes con este producto
        Expanded(
          child: imagesWithCategory.isEmpty
              ? const Center(
            child: Text('No hay imágenes con este producto'),
          )
              : GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.8,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: imagesWithCategory.length,
            itemBuilder: (context, index) {
              final entry = imagesWithCategory[index];
              final imagePath = entry.key;
              final result = entry.value;

              // Contar cuántas instancias de esta categoría hay en la imagen
              final instanceCount = result.detecciones
                  .where((detection) => detection['class'] == category)
                  .length;

              return Card(
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 3,
                child: InkWell(
                  onTap: () {
                    // Navegar a los detalles de la imagen
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ImageDetailScreen(
                          image: File(imagePath),
                          analysisResult: result,
                        ),
                      ),
                    );
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.file(
                              File(imagePath),
                              fit: BoxFit.cover,
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '$instanceCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          path.basename(imagePath),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade700),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}