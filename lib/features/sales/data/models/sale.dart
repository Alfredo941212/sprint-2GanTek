class Sale {
  final int? id;
  final int userId;
  final int cattleId;
  final String cattleCode;
  final String buyerName;
  final String buyerPhone;
  final DateTime saleDate;
  final double saleWeight;
  final double pricePerKg;
  final double total;
  final String paymentMethod;
  final String observations;
  final String status;
  final DateTime createdAt;

  const Sale({
    this.id,
    required this.userId,
    required this.cattleId,
    required this.cattleCode,
    required this.buyerName,
    required this.buyerPhone,
    required this.saleDate,
    required this.saleWeight,
    required this.pricePerKg,
    required this.total,
    required this.paymentMethod,
    required this.observations,
    required this.status,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'cattle_id': cattleId,
      'cattle_code': cattleCode,
      'buyer_name': buyerName,
      'buyer_phone': buyerPhone,
      'sale_date': saleDate.toIso8601String(),
      'sale_weight': saleWeight,
      'price_per_kg': pricePerKg,
      'total': total,
      'payment_method': paymentMethod,
      'observations': observations,
      'status': status,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Sale.fromMap(Map<String, dynamic> map) {
    return Sale(
      id: (map['id'] as num?)?.toInt(),
      userId: (map['user_id'] as num).toInt(),
      cattleId: (map['cattle_id'] as num).toInt(),
      cattleCode: map['cattle_code'] as String? ?? '',
      buyerName: map['buyer_name'] as String? ?? '',
      buyerPhone: map['buyer_phone'] as String? ?? '',
      saleDate: DateTime.parse(
        map['sale_date'] as String,
      ),
      saleWeight: (map['sale_weight'] as num).toDouble(),
      pricePerKg: (map['price_per_kg'] as num).toDouble(),
      total: (map['total'] as num).toDouble(),
      paymentMethod: map['payment_method'] as String? ?? 'Efectivo',
      observations: map['observations'] as String? ?? '',
      status: map['status'] as String? ?? 'completada',
      createdAt: DateTime.parse(
        map['created_at'] as String,
      ),
    );
  }
}
