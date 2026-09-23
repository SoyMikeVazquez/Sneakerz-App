class CartItem {
  final String id;
  final String name;
  final double price;
  final int quantity;
  final String imageUrl;
  final String type; // 'product' or 'service'

  CartItem({
    required this.id,
    required this.name,
    required this.price,
    required this.quantity,
    required this.imageUrl,
    required this.type,
  });

  CartItem copyWith({
    String? id,
    String? name,
    double? price,
    int? quantity,
    String? imageUrl,
    String? type,
  }) {
    return CartItem(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      imageUrl: imageUrl ?? this.imageUrl,
      type: type ?? this.type,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'quantity': quantity,
      'imageUrl': imageUrl,
      'type': type,
    };
  }
}
