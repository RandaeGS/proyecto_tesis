import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:path/path.dart' as path;

import '../../../services/images/images_provider.dart';
import '../../../services/images/images_service.dart';
import '../../images/server_screen_managment.dart';
import 'category_image_card.dart';

class ProductCategoryTab extends StatelessWidget {
  final String category;

  const ProductCategoryTab({
    Key? key,
    required this.category,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<ServerImageProvider>(
      builder: (context, imageProvider, _) {
        // Obtener detecciones CONFIRMADAS que contienen esta categoría
        final detections = imageProvider.confirmedCenterDetections.where((result) {
          return result.detecciones.any((detection) =>
          (detection['class'] ?? 'unknown') == category
          );
        }).toList();

        // Contar instancias de esta categoría
        int instanceCount = 0;
        for (var result in detections) {
          instanceCount += result.detecciones.where((detection) =>
          (detection['class'] ?? 'unknown') == category
          ).length;
        }

        // Mostrar imágenes que contienen esta categoría
        final List<ServerImage> imagesWithCategory = imageProvider.getImagesForCategory(
            category,
            onlyConfirmed: true
        );

        return CustomScrollView(
          slivers: [
            // Cabecera con información de la categoría
            SliverToBoxAdapter(
              child: _buildCategoryHeader(context, instanceCount, imagesWithCategory.length),
            ),

            // Lista de imágenes con este producto
            imagesWithCategory.isEmpty
                ? SliverFillRemaining(
              child: _buildEmptyState(),
            )
                : SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.8,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                delegate: SliverChildBuilderDelegate(
                      (context, index) {
                    final image = imagesWithCategory[index];
                    final analysisResult = imageProvider.getConfirmedAnalysisForImage(image.id);

                    // Contar cuántas instancias de esta categoría hay en la imagen
                    int imageInstanceCount = 0;
                    if (analysisResult != null) {
                      imageInstanceCount = analysisResult.detecciones.where((detection) =>
                      (detection['class'] ?? 'unknown') == category
                      ).length;
                    }

                    return CategoryImageCard(
                      image: image,
                      analysisResult: analysisResult,
                      imageInstanceCount: imageInstanceCount,
                      imageProvider: imageProvider,
                    );
                  },
                  childCount: imagesWithCategory.length,
                ),
              ),
            ),

            // Espacio adicional al final
            const SliverToBoxAdapter(
              child: SizedBox(height: 24),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCategoryHeader(BuildContext context, int instanceCount, int imageCount) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.secondary,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  category.substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$instanceCount productos en $imageCount ${imageCount == 1 ? 'imagen' : 'imágenes'}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.info_outline,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  'Pulsa en una imagen para ver detalles',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_not_supported_outlined,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 24),
          Text(
            'No hay imágenes disponibles',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No se encontraron productos de esta categoría',
            style: TextStyle(
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}