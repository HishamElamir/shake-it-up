/// One image in the library.
///
/// [fileName] is deliberately *relative* — it is resolved against the pictures
/// directory at read time. Absolute paths would rot: the iOS app-container
/// path changes between installs and OS updates, so a path stored today points
/// nowhere after the next update.
class Picture {
  const Picture({
    required this.id,
    required this.fileName,
    required this.addedAt,
  });

  factory Picture.fromJson(Map<String, dynamic> json) => Picture(
    id: json['id'] as String,
    fileName: json['fileName'] as String,
    addedAt: DateTime.fromMillisecondsSinceEpoch(json['addedAt'] as int)
        .toUtc(),
  );

  final String id;
  final String fileName;
  final DateTime addedAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'fileName': fileName,
    'addedAt': addedAt.millisecondsSinceEpoch,
  };

  @override
  bool operator ==(Object other) => other is Picture && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Picture($id, $fileName)';
}
