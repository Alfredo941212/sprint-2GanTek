import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

enum CattleStatus {
  active,
  inactive,
  deceased,
  removed,
}

class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.status,
  });

  final CattleStatus status;

  String get label {
    switch (status) {
      case CattleStatus.active:
        return 'Activo';

      case CattleStatus.inactive:
        return 'Inactivo';

      case CattleStatus.deceased:
        return 'Fallecido';

      case CattleStatus.removed:
        return 'Baja';
    }
  }

  Color get backgroundColor {
    switch (status) {
      case CattleStatus.active:
        return AppColors.successSoft;

      case CattleStatus.inactive:
        return AppColors.warningSoft;

      case CattleStatus.deceased:
        return AppColors.surfaceSoft;

      case CattleStatus.removed:
        return AppColors.infoSoft;
    }
  }

  Color get foregroundColor {
    switch (status) {
      case CattleStatus.active:
        return AppColors.success;

      case CattleStatus.inactive:
        return AppColors.warning;

      case CattleStatus.deceased:
        return AppColors.textSecondary;

      case CattleStatus.removed:
        return AppColors.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foregroundColor,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
