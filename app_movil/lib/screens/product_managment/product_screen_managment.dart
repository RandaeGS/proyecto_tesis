import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:path/path.dart' as path;

import '../../../screens/image_capture_screen.dart';
import '../../services/images/images_provider.dart';
import '../../services/images/images_service.dart';

class ProductManagementScreen extends StatefulWidget {
  final int centerId;

  const ProductManagementScreen({
    Key? key,
    required this.centerId,
  }) : super(key: key);

  @override
  State<ProductManagementScreen> createState() => _ProductManagementScreenState();
}

class _ProductManagementScreenState extends State<ProductManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, int> _productCounts = {};
  List<String> _productCategories = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // Cargar imágenes y detecciones del centro
      final imageProvider = Provider.of<ServerImageProvider>(context, listen: false);
      await imageProvider.loadCenterImages(widget.centerId);

      // Procesar datos de productos
      _processProductData(imageProvider);

      // Inicializar el controlador de pestañas
      _tabController = TabController(length: _productCategories.length + 1, vsync: this);
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _processProductData(ServerImageProvider imageProvider) {
    // Conteo de productos por categoría
    final Map<String, int> counts = {};
    final Set<String> categories = {};

    // Iterar sobre los resultados de análisis para contar objetos por categoría
    imageProvider.analysisResults.forEach((imageId, result) {
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
  void dispose() {
    if (_isLoading == false) {
      _tabController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Productos'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Recargar datos',
          ),
        ],
        bottom: _isLoading || _errorMessage.isNotEmpty
            ? null
            : TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [
            const Tab(text: 'Resumen'),
            ..._productCategories.map((category) => Tab(text: category)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
          ? _buildErrorState()
          : TabBarView(
        controller: _tabController,
        children: [
          _buildSummaryTab(),
          ..._productCategories.map((category) => _buildCategoryTab(category)),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red.shade400,
          ),
          const SizedBox(height: 16),
          const Text(
            'Error al cargar datos',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade700,
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryTab() {
    return Consumer<ServerImageProvider>(
      builder: (context, imageProvider, _) {
        final totalImages = imageProvider.centerImages.length;
        final totalProductsDetected = _productCounts.values.fold(0, (sum, count) => sum + count);

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
                      _buildStatRow('Total de imágenes', '$totalImages'),
                      _buildStatRow('Total de productos', '$totalProductsDetected'),
                      _buildStatRow('Categorías', '${_productCategories.length}'),

                      // Información del centro
                      const Divider(),
                      _buildStatRow('Centro ID', '${widget.centerId}'),
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
                final percentage = totalProductsDetected > 0
                    ? (count / totalProductsDetected * 100).toStringAsFixed(1)
                    : '0.0';

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
                      final categoryIndex = _productCategories.indexOf(category);
                      if (categoryIndex >= 0) {
                        _tabController.animateTo(categoryIndex + 1);
                      }
                    },
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategoryTab(String category) {
    return Consumer<ServerImageProvider>(
      builder: (context, imageProvider, _) {
        // Filtrar imágenes que tienen detecciones de esta categoría
        final imagesWithCategory = imageProvider.centerImages
            .where((image) {
          final result = imageProvider.analysisResults[image.id];
          if (result == null) return false;

          return result.detecciones
              .any((detection) => detection['class'] == category);
        })
            .toList();

        // Contar el total de instancias de esta categoría
        int totalInstances = 0;
        for (var imageId in imageProvider.analysisResults.keys) {
          final result = imageProvider.analysisResults[imageId];
          if (result != null) {
            totalInstances += result.detecciones
                .where((detection) => detection['class'] == category)
                .length;
          }
        }

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
                        '$totalInstances productos en ${imagesWithCategory.length} imágenes',
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
                  final image = imagesWithCategory[index];
                  final analysisResult = imageProvider.analysisResults[image.id];

                  if (analysisResult == null) {
                    return const SizedBox.shrink();
                  }

                  // Contar cuántas instancias de esta categoría hay en la imagen
                  final instanceCount = analysisResult.detecciones
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
                            builder: (context) => ServerImageDetailScreen(
                              image: image,
                              analysisResult: analysisResult,
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
                                CachedNetworkImage(
                                  imageUrl: ImageService().getImageUrl(image.file),
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                    color: Colors.grey.shade200,
                                    child: const Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) => Container(
                                    color: Colors.grey.shade200,
                                    child: const Icon(
                                      Icons.error,
                                      color: Colors.red,
                                    ),
                                  ),
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
                              path.basename(image.file),
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
      },
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