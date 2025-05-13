// Archivo: screens/product_management/product_management_screen.dart
import 'package:app_movil/screens/product_managment/widget/error_state_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/images/images_provider.dart';
import 'component/product_category_tab.dart';
import 'component/product_summary_tab.dart';


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
      // Cargar imágenes y detecciones del centro a través del provider
      final imageProvider = Provider.of<ServerImageProvider>(context, listen: false);
      await imageProvider.loadCenterImages(widget.centerId);

      // Obtener categorías de productos
      _productCategories = imageProvider.getProductCategories(onlyConfirmed: true);

      // Inicializar el controlador de pestañas
      _tabController = TabController(
          length: _productCategories.length + 1,
          vsync: this
      );
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    if (!_isLoading) {
      _tabController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text('Catálogo de Productos'),
      backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.4),
      foregroundColor: Colors.white,
      elevation: 0,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _loadData,
          tooltip: 'Actualizar',
        ),
      ],
      bottom: _isLoading || _errorMessage.isNotEmpty
          ? null
          : TabBar(
        controller: _tabController,
        isScrollable: true,
        indicatorColor: Colors.white,
        indicatorWeight: 3,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
        tabs: [
          const Tab(
            child: Row(
              children: [
                Icon(Icons.dashboard),
                SizedBox(width: 8),
                Text('Resumen'),
              ],
            ),
          ),
          ..._productCategories.map((category) => Tab(
            child: Text(category),
          )),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Cargando productos...'),
          ],
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return ErrorStateWidget(
        errorMessage: _errorMessage,
        onRetry: _loadData,
      );
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Theme.of(context).colorScheme.primary.withOpacity(0.05),
            Colors.white,
          ],
        ),
      ),
      child: TabBarView(
        controller: _tabController,
        children: [
          ProductSummaryTab(centerId: widget.centerId),
          ..._productCategories.map((category) =>
              ProductCategoryTab(category: category)
          ),
        ],
      ),
    );
  }
}