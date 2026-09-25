class Note {
  const Note({
    required this.id,
    required this.title,
    required this.content,
    this.folder = 'General',
    this.tags = const [],
    this.isPinned = false,
    this.isArchived = false,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String content; // Markdown text
  final String folder;
  final List<String> tags;
  final bool isPinned;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get previewSnippet {
    final lines = content.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return 'Empty note';
    final first = lines.first.replaceAll(RegExp(r'^[#*\->\s]+'), '');
    return first.length > 80 ? '${first.substring(0, 80)}...' : first;
  }

  Note copyWith({
    String? id,
    String? title,
    String? content,
    String? folder,
    List<String>? tags,
    bool? isPinned,
    bool? isArchived,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      folder: folder ?? this.folder,
      tags: tags ?? this.tags,
      isPinned: isPinned ?? this.isPinned,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'folder': folder,
        'tags': tags,
        'isPinned': isPinned,
        'isArchived': isArchived,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Untitled',
      content: json['content'] as String? ?? '',
      folder: json['folder'] as String? ?? 'General',
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          const [],
      isPinned: json['isPinned'] as bool? ?? false,
      isArchived: json['isArchived'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}
