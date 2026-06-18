class LoanHistoryItem {
  final String loanId;
  final String lenderName;
  final DateTime uploadDate;
  final String status;
  final double? riskScore;

  const LoanHistoryItem({
    required this.loanId,
    required this.lenderName,
    required this.uploadDate,
    required this.status,
    required this.riskScore,
  });

  factory LoanHistoryItem.fromJson(Map<String, dynamic> json) {
    return LoanHistoryItem(
      loanId: json['loan_id']?.toString() ?? '',
      lenderName: json['lender_name']?.toString() ?? 'Unknown lender',
      uploadDate: DateTime.tryParse(json['upload_date']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      status: json['status']?.toString() ?? 'UNKNOWN',
      riskScore: (json['risk_score'] as num?)?.toDouble(),
    );
  }

  bool get isCompleted => status.toUpperCase() == 'COMPLETED';
}
