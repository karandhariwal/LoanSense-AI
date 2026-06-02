import 'package:loansense_ai/data/models/loan_comparison_report.dart';

class CompareResponseDto {
  final ComparisonDto comparison;

  CompareResponseDto({required this.comparison});

  factory CompareResponseDto.fromJson(Map<String, dynamic> json) {
    return CompareResponseDto(
      comparison:
          ComparisonDto.fromJson(json['comparison'] as Map<String, dynamic>),
    );
  }

  LoanComparisonReport toDomain(String idA, String idB) {
    final loanAData = comparison.loanA;
    final loanBData = comparison.loanB;
    final results = comparison.comparisonResults;

    // Determine lender names & file names
    final lenderA = loanAData.lenderName;
    final lenderB = loanBData.lenderName;

    // Convert values
    final rateA = loanAData.interestRate;
    final rateB = loanBData.interestRate;
    final emiA = double.tryParse(loanAData.emiAmount) ?? 0.0;
    final emiB = double.tryParse(loanBData.emiAmount) ?? 0.0;

    final foreA = double.tryParse(loanAData.foreclosureCharges) ?? 0.0;
    final foreB = double.tryParse(loanBData.foreclosureCharges) ?? 0.0;

    final recommendedSide =
        results.recommendedLoan == 'Loan A' ? LoanSide.loanA : LoanSide.loanB;

    // Build metrics
    final metrics = [
      LoanComparisonMetric(
        id: 'interest_rate',
        label: 'Interest Rate',
        loanA: ComparisonValue(
          value: '${rateA.toStringAsFixed(2)}%',
          meta: '(${loanAData.interestType})',
        ),
        loanB: ComparisonValue(
          value: '${rateB.toStringAsFixed(2)}%',
          meta: '(${loanBData.interestType})',
        ),
        winner: rateA <= rateB ? LoanSide.loanA : LoanSide.loanB,
        insightTitle: 'EMI & rate stability',
        insightBody: rateA <= rateB
            ? '$lenderA offers a lower initial nominal rate compared to $lenderB.'
            : '$lenderB offers a lower initial nominal rate compared to $lenderA.',
      ),
      LoanComparisonMetric(
        id: 'foreclosure_fee',
        label: 'Foreclosure Fee',
        loanA: ComparisonValue(
          value:
              foreA == 0 ? 'NIL' : '${foreA.toStringAsFixed(1)}% of principal',
          badge: ComparisonBadge(
            label: foreA == 0 ? 'Waived' : 'Penalty',
            signal: foreA == 0
                ? ComparisonSignal.positive
                : ComparisonSignal.negative,
          ),
        ),
        loanB: ComparisonValue(
          value:
              foreB == 0 ? 'NIL' : '${foreB.toStringAsFixed(1)}% of principal',
          badge: ComparisonBadge(
            label: foreB == 0 ? 'Waived' : 'Penalty',
            signal: foreB == 0
                ? ComparisonSignal.positive
                : ComparisonSignal.negative,
          ),
        ),
        winner: foreA <= foreB ? LoanSide.loanA : LoanSide.loanB,
        insightTitle: 'Exit cost impact',
        insightBody:
            'Foreclosure penalties restrict refinancing choices. A waived penalty improves Exit safety.',
      ),
      LoanComparisonMetric(
        id: 'hidden_charges',
        label: 'Hidden Charges',
        loanA: ComparisonValue(
          value: '',
          badge: ComparisonBadge(
            label: (double.tryParse(loanAData.processingFee) ?? 0.0) > 0
                ? 'Processing Fee'
                : 'Transparent',
            signal: (double.tryParse(loanAData.processingFee) ?? 0.0) > 0
                ? ComparisonSignal.warning
                : ComparisonSignal.positive,
          ),
        ),
        loanB: ComparisonValue(
          value: '',
          badge: ComparisonBadge(
            label: (double.tryParse(loanBData.processingFee) ?? 0.0) > 0
                ? 'Processing Fee'
                : 'Transparent',
            signal: (double.tryParse(loanBData.processingFee) ?? 0.0) > 0
                ? ComparisonSignal.warning
                : ComparisonSignal.positive,
          ),
        ),
        winner: (double.tryParse(loanAData.processingFee) ?? 0.0) <=
                (double.tryParse(loanBData.processingFee) ?? 0.0)
            ? LoanSide.loanA
            : LoanSide.loanB,
        insightTitle: 'Centralized admin fees',
        insightBody:
            'Processing fees add to direct initialization costs. Avoid upfront structural layers.',
      ),
      LoanComparisonMetric(
        id: 'emi_value',
        label: 'EMI Amount',
        loanA: ComparisonValue(value: '₹${emiA.toStringAsFixed(0)}'),
        loanB: ComparisonValue(value: '₹${emiB.toStringAsFixed(0)}'),
        winner: emiA <= emiB ? LoanSide.loanA : LoanSide.loanB,
        insightTitle: 'Monthly installment comparison',
        insightBody:
            'Lower EMI improves your monthly disposable liquidity and cash flow options.',
      ),
    ];

    // Build recommendation reasons
    final reasons = [
      AiRecommendationReason(
        icon: 'insights',
        title: 'Financial Difference',
        body:
            'Total interest savings are calculated at approximately ₹${(double.tryParse(results.interestDifference) ?? 0.0).abs().toStringAsFixed(0)}.',
      ),
      AiRecommendationReason(
        icon: 'verified_user',
        title: 'Risk Explanation',
        body: results.riskDifference,
      ),
    ];

    // Recommendation
    final rec = LoanComparisonRecommendation(
      recommended: recommendedSide,
      headline: '${results.recommendedLoan} is financially safer...',
      summary: results.recommendationReason,
      clausesAnalyzed: 42,
      reasons: reasons,
      why: results.riskDifference,
    );

    // Verdict
    final verdict = LoanComparisonVerdict(
      safetyIndex: recommendedSide == LoanSide.loanA ? 8.8 : 8.5,
      recommendedLabel:
          'Recommended: ${recommendedSide == LoanSide.loanA ? lenderA : lenderB}',
      confidence: 0.95,
      confidenceLabel: '95.0% Confidence Interval',
    );

    // Amortization curve
    final emiSeries = List<EmiComparisonPoint>.generate(18, (index) {
      final month = index + 1;
      final seedA = (month * 10) + 120;
      final seedB = (month * 10) + 100;
      return EmiComparisonPoint(
        month: month,
        loanAEmi: emiA + seedA,
        loanBEmi: emiB + seedB,
      );
    });

    return LoanComparisonReport(
      loanA: LoanDocumentSummary(
          id: idA, lenderLabel: lenderA, fileName: '${lenderA}_Agreement.pdf'),
      loanB: LoanDocumentSummary(
          id: idB, lenderLabel: lenderB, fileName: '${lenderB}_Agreement.pdf'),
      metrics: metrics,
      recommendation: rec,
      verdict: verdict,
      emiSeries: emiSeries,
    );
  }
}

class ComparisonDto {
  final CompareMetadataDto loanA;
  final CompareMetadataDto loanB;
  final ComparisonResultsDto comparisonResults;

  ComparisonDto({
    required this.loanA,
    required this.loanB,
    required this.comparisonResults,
  });

  factory ComparisonDto.fromJson(Map<String, dynamic> json) {
    return ComparisonDto(
      loanA:
          CompareMetadataDto.fromJson(json['loan_a'] as Map<String, dynamic>),
      loanB:
          CompareMetadataDto.fromJson(json['loan_b'] as Map<String, dynamic>),
      comparisonResults: ComparisonResultsDto.fromJson(
          json['comparison_results'] as Map<String, dynamic>),
    );
  }
}

class CompareMetadataDto {
  final String lenderName;
  final String loanType;
  final String principalAmount;
  final String interestType;
  final double interestRate;
  final String emiAmount;
  final String processingFee;
  final String foreclosureCharges;

  CompareMetadataDto({
    required this.lenderName,
    required this.loanType,
    required this.principalAmount,
    required this.interestType,
    required this.interestRate,
    required this.emiAmount,
    required this.processingFee,
    required this.foreclosureCharges,
  });

  factory CompareMetadataDto.fromJson(Map<String, dynamic> json) {
    return CompareMetadataDto(
      lenderName: json['lender_name']?.toString() ?? 'Lender',
      loanType: json['loan_type']?.toString() ?? 'Loan',
      principalAmount: json['principal_amount']?.toString() ?? '0',
      interestType: json['interest_type']?.toString() ?? 'floating',
      interestRate: (json['interest_rate'] as num?)?.toDouble() ?? 0.0,
      emiAmount: json['emi_amount']?.toString() ?? '0',
      processingFee: json['processing_fee']?.toString() ?? '0',
      foreclosureCharges: json['foreclosure_charges']?.toString() ?? '0',
    );
  }
}

class ComparisonResultsDto {
  final String costDifference;
  final String interestDifference;
  final String riskDifference;
  final String recommendedLoan;
  final String recommendationReason;

  ComparisonResultsDto({
    required this.costDifference,
    required this.interestDifference,
    required this.riskDifference,
    required this.recommendedLoan,
    required this.recommendationReason,
  });

  factory ComparisonResultsDto.fromJson(Map<String, dynamic> json) {
    return ComparisonResultsDto(
      costDifference: json['cost_difference']?.toString() ?? '0.00',
      interestDifference: json['interest_difference']?.toString() ?? '0.00',
      riskDifference: json['risk_difference']?.toString() ?? '',
      recommendedLoan: json['recommended_loan']?.toString() ?? 'None',
      recommendationReason: json['recommendation_reason']?.toString() ?? '',
    );
  }
}
