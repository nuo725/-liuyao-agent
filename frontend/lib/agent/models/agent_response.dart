class AgentQuoteView {
  final String quoteId;
  final String text;
  final String source;

  const AgentQuoteView({
    required this.quoteId,
    required this.text,
    required this.source,
  });

  Map<String, dynamic> toJson() => {
    'quoteId': quoteId,
    'text': text,
    'source': source,
  };
}

class AgentResponseView {
  final String sessionId;
  final String directionId;
  final String stateName;
  final AgentQuoteView? quote;
  final String body;
  final List<String> followups;
  final Map<String, dynamic> meta;
  final Map<String, dynamic> debug;

  const AgentResponseView({
    required this.sessionId,
    required this.directionId,
    required this.stateName,
    required this.quote,
    required this.body,
    required this.followups,
    required this.meta,
    required this.debug,
  });

  Map<String, dynamic> toJson() => {
    'sessionId': sessionId,
    'directionId': directionId,
    'stateName': stateName,
    'quote': quote?.toJson(),
    'body': body,
    'followups': followups,
    'meta': meta,
    'debug': debug,
  };
}
