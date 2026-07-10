class ShoppingItem {
  final String text;
  final bool checked;

  ShoppingItem({required this.text, this.checked = false});

  Map<String, dynamic> toMap() => {'text': text, 'checked': checked};

  factory ShoppingItem.fromMap(Map<String, dynamic> map) => ShoppingItem(
        text: map['text']?.toString() ?? '',
        checked: map['checked'] == true,
      );

  ShoppingItem copyWith({String? text, bool? checked}) => ShoppingItem(
        text: text ?? this.text,
        checked: checked ?? this.checked,
      );
}
