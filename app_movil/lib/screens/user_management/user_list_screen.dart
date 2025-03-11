import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/auth_services/auth_provider.dart';
import '../../../entities/user.dart';
import '../../../entities/center.dart' as app_center;
import '../../../services/user_provider.dart';
import 'user_detail.dart';
import 'user_form_screen.dart';

class UserListScreen extends StatefulWidget {
  const UserListScreen({Key? key}) : super(key: key);

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  late final UserProvider _userProvider;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  int? _centerId;
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _userProvider = Provider.of<UserProvider>(context, listen: false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeScreen();
    });
  }

  Future<void> _initializeScreen() async {
    setState(() => _isInitializing = true);

    try {
      // Obtener el ID del centro del usuario actual
      _centerId = await _userProvider.getCurrentUserCenterId(context);

      if (_centerId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se pudo determinar su centro. Contacte al administrador.'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() => _isInitializing = false);
        }
        return;
      }

      await _loadUsers();
    } catch (e) {
      if (mounted) {
        debugPrint('Error en inicialización: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al inicializar: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isInitializing = false);
      }
    }
  }

  Future<void> _loadUsers() async {
    if (_centerId != null) {
      try {
        await _userProvider.loadUsers(_centerId!);
      } catch (e) {
        if (mounted) {
          debugPrint('Error al cargar usuarios: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al cargar usuarios: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isInitializing = false);
        }
      }
    } else {
      setState(() => _isInitializing = false);
    }
  }

  Future<void> _searchUsers() async {
    if (_centerId != null) {
      await _userProvider.searchUsers(_centerId!, _searchQuery);
    }
  }

  Future<void> _deleteUser(User user) async {
    if (_centerId != null) {
      final success = await _userProvider.deleteUser(_centerId!, user.email);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Usuario ${user.name} eliminado correctamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _checkSessionAndRedirect() async {
    // Si hay un error de sesión, redirigimos al login
    if (_userProvider.errorMessage.contains("sesión ha expirado") ||
        _userProvider.errorMessage.contains("No autorizado")) {

      // Limpiar los datos de la sesión
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.logout();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Su sesión ha expirado. Iniciando sesión nuevamente...'),
            backgroundColor: Colors.orange,
          ),
        );

        // Navegar a la pantalla de login
        Navigator.of(context).pushNamedAndRemoveUntil(
            '/login',
                (route) => false
        );
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Verificar si hay error de sesión
    if (_userProvider.errorMessage.contains("sesión ha expirado") ||
        _userProvider.errorMessage.contains("No autorizado")) {
      _checkSessionAndRedirect();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Usuarios'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          // Debug info button
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              final authProvider = Provider.of<AuthProvider>(context, listen: false);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Centro ID: $_centerId, Usuario: ${authProvider.user?.name}'),
                  backgroundColor: Colors.blue,
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isInitializing
            ? null
            : () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UserFormScreen(isEditing: false, centerId: _centerId),
            ),
          );

          if (result == true && mounted) {
            _loadUsers();
          }
        },
        backgroundColor: _isInitializing ? Colors.grey : Colors.blue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _isInitializing
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          // Información del centro
          Consumer<UserProvider>(
            builder: (context, provider, _) {
              final center = provider.currentCenter;
              final centerName = center?.name ?? 'No disponible';
              final centerId = center?.id.toString() ?? 'Desconocido';

              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Centro',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              'ID: $centerId',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          centerName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (center?.address != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            center!.address,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          // Barra de búsqueda
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar usuarios...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                    _loadUsers();
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
                if (value.isEmpty) {
                  _loadUsers();
                }
              },
              onSubmitted: (_) => _searchUsers(),
            ),
          ),

          const SizedBox(height: 16),

          // Lista o mensajes de error/vacío
          Expanded(
            child: Consumer<UserProvider>(
              builder: (context, provider, _) {
                if (provider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (provider.errorMessage.isNotEmpty) {
                  return _buildErrorView(provider.errorMessage);
                }

                if (provider.users.isEmpty) {
                  return _buildEmptyView();
                }

                return _buildUserList(provider.users);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserList(List<User> users) {
    return RefreshIndicator(
      onRefresh: _loadUsers,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: users.length,
        itemBuilder: (context, index) {
          final user = users[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              leading: CircleAvatar(
                backgroundColor: user.isSuperuser
                    ? Colors.blue.shade100
                    : Colors.grey.shade200,
                child: Text(
                  user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: user.isSuperuser ? Colors.blue : Colors.grey.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(
                user.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.email),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: user.isSuperuser
                              ? Colors.blue.shade100
                              : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          user.isSuperuser ? 'Administrador' : 'Usuario estándar',
                          style: TextStyle(
                            fontSize: 12,
                            color: user.isSuperuser
                                ? Colors.blue.shade800
                                : Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => UserFormScreen(
                            isEditing: true,
                            user: user,
                            centerId: _centerId,
                          ),
                        ),
                      );

                      if (result == true && mounted) {
                        _loadUsers();
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _confirmDelete(user),
                  ),
                ],
              ),
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => UserDetailScreen(
                      user: user,
                      centerId: _centerId,
                    ),
                  ),
                );

                if (result == true && mounted) {
                  _loadUsers();
                }
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          const Text(
            'No hay usuarios registrados',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Presiona el botón + para agregar un nuevo usuario',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadUsers,
            icon: const Icon(Icons.refresh),
            label: const Text('Actualizar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(String errorMessage) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red,
          ),
          const SizedBox(height: 16),
          const Text(
            'Error al cargar usuarios',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Text(
              errorMessage,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadUsers,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(User user) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar eliminación'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('¿Está seguro que desea eliminar al usuario ${user.name}?'),
                const SizedBox(height: 8),
                const Text(
                  'Esta acción no se puede deshacer.',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text(
                'Eliminar',
                style: TextStyle(color: Colors.red),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                _deleteUser(user);
              },
            ),
          ],
        );
      },
    );
  }
}
