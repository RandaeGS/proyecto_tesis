import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/images/images_provider.dart';
import '../entity/inventory_report.dart';
import '../services/inventory_report_provider.dart';
import '../services/inventory_report_sevices.dart';

class CategoryProductsScreen extends StatefulWidget {
  final String? category;
  final int centerId;
  final bool showAllCategories;

  const CategoryProductsScreen({
    Key? key,
    this.category,
    required this.centerId,
    this.showAllCategories = false,
  }) : super(key: key);

  @override
  State<CategoryProductsScreen> createState() => _CategoryProductsScreenState();
}

class _CategoryProductsScreenState extends State<CategoryProductsScreen> {
  bool _isLoading = true;
  String _selectedCategory = '';
  List<String> _availableCategories = [];
  Map<String, ProductReplenishmentInfo> _productInfoByCategory = {};

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    setState(() => _isLoading = true);

    try {
      // Cargar informes para obtener información de productos
      await Provider.of<InventoryReportProvider>(context, listen: false)
          .loadReports(widget.centerId);

      // Cargar imágenes del centro para mostrar ejemplos visuales
      await Provider.of<ServerImageProvider>(context, listen: false)
          .loadCenterImages(widget.centerId);

      // Obtener categorías disponibles
      final reportProvider = Provider.of<InventoryReportProvider>(context, listen: false);
      final latestReport = reportProvider.getLatestReport();

      if (latestReport != null) {
        _availableCategories = latestReport.productRecommendations.keys.toList();
        _productInfoByCategory = latestReport.productRecommendations;
      } else {
        // Si no hay informes, usar categorías predeterminadas
        _availableCategories = InventoryReportService.defaultIdealCounts.keys.toList();
      }

      // Seleccionar categoría inicial
      if (widget.category != null) {
        _selectedCategory = widget.category!;
      } else if (_availableCategories.isNotEmpty) {
        _selectedCategory = _availableCategories.first;
      }
    } catch (e) {
      debugPrint('Error al inicializar: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.showAllCategories
            ? 'Categorías de Productos'
            : 'Categoría: ${widget.category ?? ""}'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : widget.showAllCategories
          ? _buildCategoriesGrid()
          : _buildCategoryDetail(),
    );
  }

  Widget _buildCategoriesGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.8,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _availableCategories.length,
      itemBuilder: (context, index) {
        final category = _availableCategories[index];
        final productInfo = _productInfoByCategory[category];

        // Determinar color según la prioridad
        Color categoryColor = Colors.blue;
        if (productInfo != null) {
          categoryColor = _getPriorityColor(productInfo.priority);
        }

        return Card(
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CategoryProductsScreen(
                    category: category,
                    centerId: widget.centerId,
                  ),
                ),
              );
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Banner de color superior según prioridad
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: categoryColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                ),

                // Imagen representativa de la categoría
                Expanded(
                  child: _buildCategoryImage(category),
                ),

                // Información de la categoría
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      if (productInfo != null) ...[
                        _buildLevelIndicator(
                          productInfo.currentCount,
                          productInfo.idealCount,
                          categoryColor,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Actual: ${productInfo.currentCount}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            Text(
                              'Ideal: ${productInfo.idealCount}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategoryDetail() {
    // Obtener información del producto si está disponible
    final productInfo = _productInfoByCategory[_selectedCategory];

    // Obtener color según la prioridad
    Color categoryColor = Colors.blue;
    if (productInfo != null) {
      categoryColor = _getPriorityColor(productInfo.priority);
    }

    // Obtener imágenes relacionadas con esta categoría
    final imageProvider = Provider.of<ServerImageProvider>(context, listen: false);
    final categoryImages = _selectedCategory.isNotEmpty
        ? imageProvider.getImagesForCategory(_selectedCategory, onlyConfirmed: true)
        : [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tarjeta de información
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                // Banner de color superior según prioridad
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: categoryColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.white,
                        child: Text(
                          productInfo?.priority.toString() ?? "?",
                          style: TextStyle(
                            color: categoryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _selectedCategory,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Detalles del producto
                if (productInfo != null)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        // Nivel de existencias
                        Row(
                          children: [
                            const Icon(Icons.inventory_2, size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              'Nivel de existencias:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildLevelIndicator(
                                productInfo.currentCount,
                                productInfo.idealCount,
                                categoryColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Estadísticas
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatColumn(
                              'Actual',
                              productInfo.currentCount.toString(),
                              Icons.inventory,
                            ),
                            _buildStatColumn(
                              'Ideal',
                              productInfo.idealCount.toString(),
                              Icons.check_circle,
                            ),
                            _buildStatColumn(
                              'Faltantes',
                              productInfo.replenishAmount.toString(),
                              Icons.add_shopping_cart,
                              valueColor: productInfo.replenishAmount > 0 ? Colors.red : Colors.green,
                            ),
                          ],
                        ),

                        if (productInfo.note.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.priority_high, color: Colors.red[700], size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    productInfo.note,
                                    style: TextStyle(color: Colors.red[700]),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 16),

                        // Recomendación
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Recomendación:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                productInfo.replenishAmount > 0
                                    ? 'Se recomienda reponer ${productInfo.replenishAmount} unidades de ${_selectedCategory} para alcanzar el nivel ideal.'
                                    : 'El inventario de ${_selectedCategory} se encuentra en niveles óptimos.',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Imágenes relacionadas con esta categoría
          if (categoryImages.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.photo_library, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Imágenes relacionadas',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: categoryImages.length,
                itemBuilder: (context, index) {
                  final image = categoryImages[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: imageProvider.getImageUrl(image.file),
                        width: 120,
                        height: 120,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[200],
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[200],
                          child: const Icon(Icons.error),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Selector de categorías
          if (_availableCategories.length > 1) ...[
            const Text(
              'Cambiar categoría',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _availableCategories.length,
                itemBuilder: (context, index) {
                  final category = _availableCategories[index];
                  final isSelected = category == _selectedCategory;
                  final catInfo = _productInfoByCategory[category];
                  final catColor = catInfo != null
                      ? _getPriorityColor(catInfo.priority)
                      : Colors.grey;

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
                        color: isSelected ? catColor : Colors.transparent,
                        border: Border.all(
                          color: catColor,
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Center(
                        child: Text(
                          category,
                          style: TextStyle(
                            color: isSelected ? Colors.white : catColor,
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

          const SizedBox(height: 24),

          // Botón para ver todas las categorías
          if (!widget.showAllCategories)
            Center(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CategoryProductsScreen(
                        showAllCategories: true,
                        centerId: widget.centerId,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.grid_view),
                label: const Text('Ver todas las categorías'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryImage(String category) {
    final imageProvider = Provider.of<ServerImageProvider>(context, listen: false);
    final categoryImages = imageProvider.getImagesForCategory(category, onlyConfirmed: true);

    if (categoryImages.isEmpty) {
      // Si no hay imágenes, mostrar un icono
      return Center(
        child: Icon(
          _getCategoryIcon(category),
          size: 64,
          color: Colors.grey[400],
        ),
      );
    }

    // Usar la primera imagen disponible
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(12),
        topRight: Radius.circular(12),
      ),
      child: CachedNetworkImage(
        imageUrl: imageProvider.getImageUrl(categoryImages.first.file),
        fit: BoxFit.cover,
        placeholder: (context, url) => Center(
          child: CircularProgressIndicator(),
        ),
        errorWidget: (context, url, error) => Center(
          child: Icon(
            _getCategoryIcon(category),
            size: 64,
            color: Colors.grey[400],
          ),
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    final lowerCategory = category.toLowerCase();

    if (lowerCategory.contains('bebida')) return Icons.local_drink;
    if (lowerCategory.contains('enlatado')) return Icons.lunch_dining;
    if (lowerCategory.contains('leche')) return Icons.coffee;
    if (lowerCategory.contains('galleta')) return Icons.cookie;
    if (lowerCategory.contains('cereal')) return Icons.breakfast_dining;
    if (lowerCategory.contains('pasta') || lowerCategory.contains('fideo')) return Icons.ramen_dining;
    if (lowerCategory.contains('condimento')) return Icons.kitchen;

    return Icons.inventory_2;
  }

  Widget _buildLevelIndicator(int current, int ideal, Color color) {
    // Calcular el nivel relativo (entre 0 y 1)
    double level = ideal > 0 ? current / ideal : 0;
    if (level > 1) level = 1; // Limitar a 1 máximo

    return Stack(
      children: [
        // Barra de fondo
        Container(
          height: 8,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        // Barra de nivel
        Container(
          height: 8,
          width: MediaQuery.of(context).size.width * 0.3 * level, // Ajustar ancho según nivel
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ],
    );
  }

  Widget _buildStatColumn(String label, String value, IconData icon, {Color? valueColor}) {
    return Column(
      children: [
        Icon(
          icon,
          size: 24,
          color: Colors.blue,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Color _getPriorityColor(int priority) {
    switch (priority) {
      case 5:
        return Colors.red;
      case 4:
        return Colors.orange;
      case 3:
        return Colors.amber;
      case 2:
        return Colors.blue;
      case 1:
      default:
        return Colors.green;
    }
  }
}