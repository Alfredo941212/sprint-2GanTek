import 'package:flutter/material.dart';

import '../../../cattle/data/models/cattle.dart';
import '../../../cattle/data/repositories/cattle_repository.dart';
import '../../data/models/milking_group.dart';
import '../../data/repositories/milking_group_repository.dart';
import '../../data/models/milking_session.dart';
import '../../data/repositories/milking_session_repository.dart';

class MilkingGroupDetailScreen extends StatefulWidget {
  const MilkingGroupDetailScreen({
    super.key,
    required this.group,
  });

  final MilkingGroup group;

  @override
  State<MilkingGroupDetailScreen> createState() =>
      _MilkingGroupDetailScreenState();
}

class _MilkingGroupDetailScreenState extends State<MilkingGroupDetailScreen> {
  final MilkingGroupRepository _groupRepository = MilkingGroupRepository();

  final CattleRepository _cattleRepository = CattleRepository();

  final MilkingSessionRepository _sessionRepository =
      MilkingSessionRepository();

  MilkingSession? _todaySession;

  MilkingSession? _findTodaySession(
    List<MilkingSession> sessions,
  ) {
    for (final session in sessions) {
      if (session.groupId == widget.group.id) {
        return session;
      }
    }

    return null;
  }

  bool _isLoading = true;

  String? _error;

  List<Cattle> _allCattle = [];
  List<int> _assignedCattleIds = [];
  List<int> _allAssignedCattleIds = [];

  List<Cattle> get _assignedCattle {
    return _allCattle.where(
      (animal) {
        if (animal.id == null) {
          return false;
        }

        return _assignedCattleIds.contains(
          animal.id,
        );
      },
    ).toList();
  }

  List<Cattle> get _availableCattle {
    return _allCattle.where(
      (animal) {
        if (animal.id == null) {
          return false;
        }

        if (_assignedCattleIds.contains(animal.id)) {
          return false;
        }

        if (_allAssignedCattleIds.contains(animal.id)) {
          return false;
        }

        if (animal.sex != 'Hembra') {
          return false;
        }

        if (animal.status != 'Activo') {
          return false;
        }

        if (animal.productiveStatus != 'En producción') {
          return false;
        }

        return true;
      },
    ).toList();
  }

  @override
  void initState() {
    super.initState();

    _loadData();
  }

  Future<void> _loadData() async {
    final int? groupId = widget.group.id;

    if (groupId == null) {
      setState(() {
        _error = 'El grupo no tiene un identificador local válido.';
        _isLoading = false;
      });

      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final results = await Future.wait([
        _cattleRepository.getActiveCattle(),
        _groupRepository.getCattleIdsByGroup(
          groupId,
        ),
        _sessionRepository.getTodaySessions(),
        _groupRepository.getAllAssignedCattleIds(),
      ]);

      if (!mounted) {
        return;
      }

      final sessions = results[2] as List<MilkingSession>;

      setState(() {
        _allCattle = results[0] as List<Cattle>;

        _assignedCattleIds = results[1] as List<int>;

        _todaySession = _findTodaySession(sessions);

        _allAssignedCattleIds = results[3] as List<int>;

        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _showAddCattleDialog() async {
    final available = _availableCattle;

    if (available.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'No hay vacas disponibles para agregar a este grupo.',
            ),
          ),
        );

      return;
    }

    final Cattle? selectedAnimal = await showModalBottomSheet<Cattle>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.70,
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Agregar vaca al grupo',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.separated(
                    itemCount: available.length,
                    separatorBuilder: (_, __) {
                      return const Divider(
                        height: 1,
                      );
                    },
                    itemBuilder: (context, index) {
                      final animal = available[index];

                      return ListTile(
                        leading: const CircleAvatar(
                          child: Icon(
                            Icons.pets_outlined,
                          ),
                        ),
                        title: Text(
                          animal.name.trim().isEmpty
                              ? 'Arete ${animal.code}'
                              : animal.name,
                        ),
                        subtitle: Text(
                          animal.name.trim().isEmpty
                              ? 'En producción'
                              : 'Arete ${animal.code} · En producción',
                        ),
                        trailing: const Icon(
                          Icons.add_circle_outline,
                        ),
                        onTap: () {
                          Navigator.pop(
                            context,
                            animal,
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selectedAnimal == null || selectedAnimal.id == null) {
      return;
    }

    await _assignCattle(
      selectedAnimal,
    );
  }

  Future<void> _assignCattle(
    Cattle animal,
  ) async {
    final int? groupId = widget.group.id;
    final int? cattleId = animal.id;

    if (groupId == null || cattleId == null) {
      return;
    }

    try {
      await _groupRepository.assignCattle(
        groupId: groupId,
        cattleId: cattleId,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              '${_animalDisplayName(animal)} fue agregada al grupo.',
            ),
          ),
        );

      await _loadData();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'No se pudo agregar la vaca. $error',
            ),
          ),
        );
    }
  }

  Future<void> _confirmRemoveCattle(
    Cattle animal,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Quitar vaca del grupo',
          ),
          content: Text(
            '¿Deseas quitar a '
            '${_animalDisplayName(animal)} '
            'de ${widget.group.name}?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  false,
                );
              },
              child: const Text(
                'Cancelar',
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  true,
                );
              },
              child: const Text(
                'Quitar',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await _removeCattle(
      animal,
    );
  }

  Future<void> _removeCattle(
    Cattle animal,
  ) async {
    final int? groupId = widget.group.id;
    final int? cattleId = animal.id;

    if (groupId == null || cattleId == null) {
      return;
    }

    try {
      await _groupRepository.removeCattle(
        groupId: groupId,
        cattleId: cattleId,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              '${_animalDisplayName(animal)} fue retirada del grupo.',
            ),
          ),
        );

      await _loadData();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'No se pudo quitar la vaca. $error',
            ),
          ),
        );
    }
  }

  String _animalDisplayName(
    Cattle animal,
  ) {
    if (animal.name.trim().isEmpty) {
      return 'Arete ${animal.code}';
    }

    return '${animal.name} - ${animal.code}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.group.name,
        ),
        actions: [
          IconButton(
            onPressed: _loadData,
            icon: const Icon(
              Icons.refresh,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _todaySession == null ? _showAddCattleDialog : null,
        icon: Icon(
          _todaySession == null ? Icons.add : Icons.lock_outline,
        ),
        label: Text(
          _todaySession == null ? 'Agregar vaca' : 'Grupo bloqueado',
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
              ),
              const SizedBox(height: 12),
              const Text(
                'No se pudo cargar el grupo.',
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loadData,
                child: const Text(
                  'Reintentar',
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          16,
          16,
          16,
          100,
        ),
        children: [
          _buildSummaryCard(),
          const SizedBox(height: 20),
          const Text(
            'Vacas asignadas',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          if (_assignedCattle.isEmpty)
            _buildEmptyState()
          else
            ..._assignedCattle.map(
              _buildCattleCard,
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    final int total = _assignedCattle.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              child: Text(
                '${widget.group.sortOrder}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.group.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    total == 1 ? '1 vaca asignada' : '$total vacas asignadas',
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Orden de ordeña: ${widget.group.sortOrder}',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(
              Icons.pets_outlined,
              size: 48,
            ),
            const SizedBox(height: 12),
            const Text(
              'Este grupo todavía no tiene vacas.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Usa "Agregar vaca" para comenzar a formar el grupo.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCattleCard(
    Cattle animal,
  ) {
    return Card(
      margin: const EdgeInsets.only(
        bottom: 10,
      ),
      child: ListTile(
        leading: const CircleAvatar(
          child: Icon(
            Icons.pets_outlined,
          ),
        ),
        title: Text(
          animal.name.trim().isEmpty ? 'Arete ${animal.code}' : animal.name,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          animal.name.trim().isEmpty
              ? '${animal.breed} · En producción'
              : 'Arete ${animal.code} · ${animal.breed}',
        ),
        trailing: _todaySession == null
            ? IconButton(
                tooltip: 'Quitar del grupo',
                onPressed: () {
                  _confirmRemoveCattle(
                    animal,
                  );
                },
                icon: const Icon(
                  Icons.remove_circle_outline,
                ),
              )
            : const Icon(
                Icons.lock_outline,
              ),
      ),
    );
  }
}
