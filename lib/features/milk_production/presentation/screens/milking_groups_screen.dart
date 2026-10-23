import 'package:flutter/material.dart';
import 'milking_group_detail_screen.dart';
import '../../data/models/milking_group.dart';
import '../../data/repositories/milking_group_repository.dart';
import '../../data/repositories/milking_session_repository.dart';
import '../../data/models/milking_session.dart';
import 'milking_history_screen.dart';

class MilkingGroupsScreen extends StatefulWidget {
  const MilkingGroupsScreen({
    super.key,
  });

  @override
  State<MilkingGroupsScreen> createState() => _MilkingGroupsScreenState();
}

class _MilkingGroupsScreenState extends State<MilkingGroupsScreen> {
  final MilkingGroupRepository _repository = MilkingGroupRepository();

  final MilkingSessionRepository _sessionRepository =
      MilkingSessionRepository();

  bool _isLoading = true;
  String? _error;

  List<MilkingSession> _todaySessions = [];
  List<MilkingGroup> _groups = [];
  final Map<int, int> _cattleCountByGroup = {};

  MilkingSession? _getSessionForGroup(int groupId) {
    for (final session in _todaySessions) {
      if (session.groupId == groupId) {
        return session;
      }
    }

    return null;
  }

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _finishSession(
    MilkingSession session,
  ) async {
    String litersText = '';
    String observations = '';

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Finalizar ordeña',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Litros totales',
                  hintText: 'Ej. 71.5',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  litersText = value;
                },
              ),
              const SizedBox(
                height: 16,
              ),
              TextField(
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Observaciones',
                  hintText: 'Opcional',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  observations = value;
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text(
                'Cancelar',
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text(
                'Finalizar',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    final double? totalLiters = double.tryParse(
      litersText.trim().replaceAll(',', '.'),
    );

    if (totalLiters == null || totalLiters <= 0) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Ingresa una cantidad válida de litros.',
          ),
        ),
      );

      return;
    }

    try {
      await _sessionRepository.finishSession(
        sessionId: session.id!,
        totalLiters: totalLiters,
        observations: observations,
      );

      if (!mounted) {
        return;
      }

      await _loadGroups();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Ordeña finalizada correctamente.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString(),
          ),
        ),
      );
    }
  }

  Future<void> _startJourney() async {
    try {
      final sessions = await _sessionRepository.startJourney();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Jornada iniciada correctamente con ${sessions.length} grupo(s).',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString(),
          ),
        ),
      );
    }
  }

  Future<void> _loadGroups() async {
    await _repository.syncPendingGroups();

    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final groups = await _repository.getActiveGroups();

      final sessions = await _sessionRepository.getTodaySessions();

      final Map<int, int> counts = {};

      for (final group in groups) {
        if (group.id == null) {
          continue;
        }

        counts[group.id!] = await _repository.getCattleCount(
          group.id!,
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _groups = groups;

        _todaySessions = sessions;

        _cattleCountByGroup
          ..clear()
          ..addAll(counts);

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

  Future<void> _createGroup() async {
    String groupName = '';

    final String? name = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Nuevo grupo de ordeña',
          ),
          content: TextField(
            decoration: const InputDecoration(
              labelText: 'Nombre del grupo',
              hintText: 'Ej. Grupo 1',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              groupName = value;
            },
            onSubmitted: (value) {
              final trimmedName = value.trim();

              if (trimmedName.isNotEmpty) {
                Navigator.of(dialogContext).pop(
                  trimmedName,
                );
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text(
                'Cancelar',
              ),
            ),
            FilledButton(
              onPressed: () {
                final trimmedName = groupName.trim();

                if (trimmedName.isEmpty) {
                  return;
                }

                Navigator.of(dialogContext).pop(
                  trimmedName,
                );
              },
              child: const Text(
                'Crear',
              ),
            ),
          ],
        );
      },
    );

    if (!mounted) {
      return;
    }

    if (name == null || name.trim().isEmpty) {
      return;
    }

    try {
      await _repository.createGroup(
        name: name.trim(),
      );

      if (!mounted) {
        return;
      }

      await _loadGroups();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Grupo creado correctamente.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString(),
          ),
        ),
      );
    }
  }

//***********MÉTODO DE ELIMINAR GRUPO */
  Future<void> _deleteGroup({
    required int groupId,
    required String groupName,
  }) async {
    final int cattleCount = _cattleCountByGroup[groupId] ?? 0;

    // No permitir eliminar si tiene ganado
    if (cattleCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se puede eliminar el grupo porque tiene ganado asignado.',
          ),
        ),
      );

      return;
    }

    // Confirmación
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Eliminar grupo',
          ),
          content: Text(
            '¿Deseas eliminar "$groupName"?\n\n'
            'Esta acción no se puede deshacer.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text(
                'Cancelar',
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text(
                'Eliminar',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _repository.deleteGroup(
        groupId: groupId,
      );

      if (!mounted) {
        return;
      }

      // Recargar los grupos después de eliminar
      await _loadGroups();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Grupo eliminado correctamente.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst(
                  'Exception: ',
                  '',
                ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Grupos de ordeña',
        ),
        actions: [
          IconButton(
            tooltip: 'Historial',
            icon: const Icon(
              Icons.history,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const MilkingHistoryScreen(),
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'start_journey',
            onPressed: _todaySessions.isEmpty ? _startJourney : null,
            icon: Icon(
              _todaySessions.isEmpty
                  ? Icons.play_arrow
                  : _todaySessions.every(
                      (session) => session.status == 'finalizado',
                    )
                      ? Icons.check
                      : Icons.timelapse,
            ),
            label: Text(
              _todaySessions.isEmpty
                  ? 'Iniciar jornada'
                  : _todaySessions.every(
                      (session) => session.status == 'finalizado',
                    )
                      ? 'Jornada finalizada'
                      : 'Jornada en curso',
            ),
          ),
          const SizedBox(
            height: 12,
          ),
          FloatingActionButton.extended(
            heroTag: 'new_group',
            onPressed: _createGroup,
            icon: const Icon(
              Icons.add,
            ),
            label: const Text(
              'Nuevo grupo',
            ),
          ),
        ],
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
                'No se pudieron cargar los grupos.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loadGroups,
                child: const Text(
                  'Reintentar',
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_groups.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadGroups,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 160),
            Icon(
              Icons.groups_outlined,
              size: 72,
            ),
            SizedBox(height: 16),
            Center(
              child: Text(
                'Todavía no hay grupos de ordeña.',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(height: 8),
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 32,
                ),
                child: Text(
                  'Crea el primer grupo para comenzar a organizar '
                  'las vacas de la jornada.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadGroups,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(
          16,
          16,
          16,
          100,
        ),
        itemCount: _groups.length,
        itemBuilder: (context, index) {
          final group = _groups[index];

          final int cattleCount =
              group.id == null ? 0 : _cattleCountByGroup[group.id!] ?? 0;

          final session = _getSessionForGroup(group.id!);

          return Card(
            margin: const EdgeInsets.only(
              bottom: 12,
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              leading: CircleAvatar(
                child: Text(
                  '${group.sortOrder}',
                ),
              ),
              title: Text(
                group.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(
                  top: 4,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cattleCount == 1
                          ? '1 vaca asignada'
                          : '$cattleCount vacas asignadas',
                    ),
                    if (session != null) ...[
                      const SizedBox(
                        height: 6,
                      ),
                      Text(
                        session.status == 'en_produccion'
                            ? 'EN PRODUCCIÓN'
                            : session.status == 'en_espera'
                                ? 'EN ESPERA'
                                : 'FINALIZADO',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (session.status == 'finalizado') ...[
                        const SizedBox(
                          height: 6,
                        ),
                        Text(
                          'Producción: ${session.totalLiters?.toStringAsFixed(1) ?? '0.0'} L',
                        ),
                        Text(
                          'Duración: ${session.durationMinutes ?? 0} min',
                        ),
                        Text(
                          'Promedio: ${session.cattleCount > 0 && session.totalLiters != null ? (session.totalLiters! / session.cattleCount).toStringAsFixed(1) : '0.0'} L/vaca',
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              trailing: session?.status == 'en_produccion'
                  ? FilledButton(
                      onPressed: () {
                        _finishSession(session!);
                      },
                      child: const Text(
                        'Finalizar',
                      ),
                    )
                  : (cattleCount == 0 && session == null)
                      ? IconButton(
                          tooltip: 'Eliminar grupo',
                          icon: const Icon(
                            Icons.delete_outline,
                          ),
                          onPressed: () {
                            _deleteGroup(
                              groupId: group.id!,
                              groupName: group.name,
                            );
                          },
                        )
                      : const Icon(
                          Icons.chevron_right,
                        ),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MilkingGroupDetailScreen(
                      group: group,
                    ),
                  ),
                );

                await _loadGroups();
              },
            ),
          );
        },
      ),
    );
  }
}
