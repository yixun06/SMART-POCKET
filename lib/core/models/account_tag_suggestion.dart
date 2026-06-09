class AccountTagSuggestion {
  AccountTagSuggestion({
    required this.accountId,
    required this.accountName,
    required this.suggestedTag,
  });

  final String accountId;
  final String accountName;
  String suggestedTag;

  AccountTagSuggestion copy() {
    return AccountTagSuggestion(
      accountId: accountId,
      accountName: accountName,
      suggestedTag: suggestedTag,
    );
  }
}
