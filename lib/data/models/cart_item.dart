class CartItem {
  final int id;
  final String name;
  final int price;
  int quantity;
  final String imageUrl;
  final double rating;

  CartItem({
    required this.id,
    required this.name,
    required this.price,
    required this.quantity,
    required this.imageUrl,
    required this.rating,
  });
}