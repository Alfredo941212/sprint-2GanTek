import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

enum CattleStatus {
  available,
  published,
  growing,
  sold,
  reserved,
}

class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.status,
  });

  final CattleStatus status;

  String get label {
    switch (status) {
      case CattleStatus.available:
        return 'Listo para venta';
      case CattleStatus.published:
        return 'Publicado';
      case CattleStatus.growing:
        return 'En crecimiento';
      case CattleStatus.sold:
        return 'Vendido';
      case CattleStatus.reserved:
        return 'Reservado';
    }
  }

  Color get backgroundColor {
    switch (status) {
      case CattleStatus.available:
        return AppColors.successSoft;
      case CattleStatus.published:
        return AppColors.infoSoft;
      case CattleStatus.growing:
        return AppColors.warningSoft;
      case CattleStatus.sold:
        return AppColors.surfaceSoft;
      case CattleStatus.reserved:
        return AppColors.goldSoft;
    }
  }

  Color get foregroundColor {
    switch (status) {
      case CattleStatus.available:
        return AppColors.success;
      case CattleStatus.published:
        return AppColors.info;
      case CattleStatus.growing:
        return AppColors.warning;
      case CattleStatus.sold:
        return AppColors.textSecondary;
      case CattleStatus.reserved:
        return AppColors.gold;
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
