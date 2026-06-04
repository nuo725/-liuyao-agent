class AgentResponsePayload {
  final String body;
  final AgentQuote? quote;
  final List<String> followups;
  final List<AgentVisualBlockPayload> blocks;
  final Map<String, dynamic> meta;

  const AgentResponsePayload({
    required this.body,
    this.quote,
    this.followups = const [],
    this.blocks = const [],
    this.meta = const {},
  });

  Map<String, dynamic> toJson() => {
    'body': body,
    'quote': quote?.toJson(),
    'followups': followups,
    'blocks': blocks.map((e) => e.toJson()).toList(),
    'meta': meta,
  };

  factory AgentResponsePayload.fromJson(Map<String, dynamic> json) {
    return AgentResponsePayload(
      body: (json['body'] as String? ?? '').trim(),
      quote: json['quote'] is Map
          ? AgentQuote.fromJson(Map<String, dynamic>.from(json['quote'] as Map))
          : null,
      followups:
          (json['followups'] as List?)
              ?.map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toList() ??
          const [],
      blocks:
          (json['blocks'] as List?)
              ?.whereType<Map>()
              .map(
                (e) => AgentVisualBlockPayload.fromJson(
                  Map<String, dynamic>.from(e),
                ),
              )
              .toList() ??
          const [],
      meta: json['meta'] is Map
          ? Map<String, dynamic>.from(json['meta'] as Map)
          : const {},
    );
  }
}

class AgentQuote {
  final String text;
  final String source;

  const AgentQuote({required this.text, required this.source});

  Map<String, dynamic> toJson() => {'text': text, 'source': source};

  factory AgentQuote.fromJson(Map<String, dynamic> json) => AgentQuote(
    text: (json['text'] as String? ?? '').trim(),
    source: (json['source'] as String? ?? '').trim(),
  );
}

class AgentVisualBlockPayload {
  final String icon;
  final String title;
  final String text;

  const AgentVisualBlockPayload({
    required this.icon,
    required this.title,
    required this.text,
  });

  Map<String, dynamic> toJson() => {'icon': icon, 'title': title, 'text': text};

  factory AgentVisualBlockPayload.fromJson(Map<String, dynamic> json) {
    return AgentVisualBlockPayload(
      icon: (json['icon'] as String? ?? 'insight').trim(),
      title: (json['title'] as String? ?? '').trim(),
      text: (json['text'] as String? ?? '').trim(),
    );
  }
}
