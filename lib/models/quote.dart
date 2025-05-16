class Quote {
final String id;
final String text;
final String author;
final String image;
final String theme;

const Quote({
required this.id,
required this.text,
required this.author,
required this.image,
required this.theme,
});

factory Quote.fromJson(Map j) => Quote(
id: j['id'] as String,
text: j['text'] as String,
author: j['author'] as String,
image: j['image'] as String,
theme: j['theme'] as String,
);
}