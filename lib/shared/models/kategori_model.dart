// Kategori verisini temsil eden model.

class KategoriModel {
  final int id;
  final String isim;

  KategoriModel({required this.id, required this.isim});

  factory KategoriModel.fromJson(Map<String, dynamic> json) {
    return KategoriModel(
      id:   json['id'],
      isim: json['isim'],
    );
  }
}
