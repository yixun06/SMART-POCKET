class AllocationResult {
  final bool success;
  final Map<String, double> allocation; // accountId -> amount to deduct
  final List<String> deductionOrder; // Display order of account deductions
  final List<String> fallbackWarnings; // Warnings about fallback usage
  final String? errorMessage;

  const AllocationResult({
    required this.success,
    required this.allocation,
    required this.deductionOrder,
    required this.fallbackWarnings,
    this.errorMessage,
  });
}
