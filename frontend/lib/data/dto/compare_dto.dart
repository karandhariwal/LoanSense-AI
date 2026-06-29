import 'package:loansense_ai/data/models/loan_comparison_report.dart';

class CompareResponseDto {
  final Map<String, dynamic> comparisonJson;

  CompareResponseDto({required this.comparisonJson});

  factory CompareResponseDto.fromJson(Map<String, dynamic> json) {
    return CompareResponseDto(
      comparisonJson: json['comparison'] as Map<String, dynamic>? ?? const {},
    );
  }

  LoanComparisonReport toDomain(String idA, String idB) {
    // Extract top-level lender names
    final lenderA = comparisonJson['loan_a_lender']?.toString() ??
        comparisonJson['loan_a']?['lender_name']?.toString() ??
        'Loan A';
    final lenderB = comparisonJson['loan_b_lender']?.toString() ??
        comparisonJson['loan_b']?['lender_name']?.toString() ??
        'Loan B';

    // Parse the new model instances
    final recVal = comparisonJson['recommended_loan'];
    final recommended = RecommendedLoan.fromJson(
      recVal is Map ? recVal.cast<String, dynamic>() : {'lender_name': recVal?.toString() ?? '', 'recommendation_score': 0.0, 'recommendation_reason': '', 'confidence_score': 0.0},
    );
    final summaryVal = comparisonJson['comparison_summary'];
    final summary = ExecutiveSummary.fromJson(
      summaryVal is Map ? summaryVal.cast<String, dynamic>() : const <String, dynamic>{},
    );
    final financialsVal = comparisonJson['financial_breakdown'];
    final financials = FinancialBreakdown.fromJson(
      financialsVal is Map ? financialsVal.cast<String, dynamic>() : const <String, dynamic>{},
    );
    final risksVal = comparisonJson['risk_breakdown'];
    final risks = RiskComparison.fromJson(
      risksVal is Map ? risksVal.cast<String, dynamic>() : const <String, dynamic>{},
    );
    final scoresVal = comparisonJson['loan_scores'];
    final scores = LoanScores.fromJson(
      scoresVal is Map ? scoresVal.cast<String, dynamic>() : const <String, dynamic>{},
    );
    final reasonsList = (comparisonJson['recommendation_reasons'] as List?)
            ?.whereType<Map>()
            .map((e) => AIRecommendationReasonItem.fromJson(e.cast<String, dynamic>()))
            .toList() ??
        const [];
    final clausesList = (comparisonJson['clause_comparison'] as List?)
            ?.whereType<Map>()
            .map((e) => ClauseComparisonItem.fromJson(e.cast<String, dynamic>()))
            .toList() ??
        const [];
    final chartsVal = comparisonJson['charts_data'];
    final charts = ChartsData.fromJson(
      chartsVal is Map ? chartsVal.cast<String, dynamic>() : const <String, dynamic>{},
    );
    final finalDecVal = comparisonJson['final_decision'];
    final finalDec = FinalDecisionCard.fromJson(
      finalDecVal is Map ? finalDecVal.cast<String, dynamic>() : const <String, dynamic>{},
    );
    final confScore = (comparisonJson['confidence_score'] as num?)?.toDouble() ?? 0.95;

    // --- CONSTRUCT LEGACY COMPATIBILITY FIELDS ---
    final docA = LoanDocumentSummary(id: idA, lenderLabel: lenderA, fileName: '${lenderA.replaceAll(' ', '_')}_Agreement.pdf');
    final docB = LoanDocumentSummary(id: idB, lenderLabel: lenderB, fileName: '${lenderB.replaceAll(' ', '_')}_Agreement.pdf');

    final legacyResults = comparisonJson['comparison_results'] as Map?;
    final legacyRecommended = legacyResults?['recommended_loan']?.toString();
    final legacyReason = legacyResults?['recommendation_reason']?.toString();
    final legacyWhy = legacyResults?['risk_difference']?.toString();

    final recommendedSide = finalDec.recommendedLoan.isNotEmpty
        ? (finalDec.recommendedLoan.toLowerCase().contains('loan a') || finalDec.recommendedLoan.toLowerCase().contains(lenderA.toLowerCase())
            ? LoanSide.loanA
            : LoanSide.loanB)
        : (legacyRecommended?.toLowerCase().contains('loan a') == true ? LoanSide.loanA : LoanSide.loanB);

    // Map metrics for compatibility (matrix card)
    final metrics = [
      LoanComparisonMetric(
        id: 'principal',
        label: 'Principal Amount',
        loanA: ComparisonValue(value: financials.principalAmount.valueA.isNotEmpty ? financials.principalAmount.valueA : (comparisonJson['loan_a']?['principal_amount']?.toString() ?? '0')),
        loanB: ComparisonValue(value: financials.principalAmount.valueB.isNotEmpty ? financials.principalAmount.valueB : (comparisonJson['loan_b']?['principal_amount']?.toString() ?? '0')),
        winner: financials.principalAmount.betterSide == 'loan_a'
            ? LoanSide.loanA
            : (financials.principalAmount.betterSide == 'loan_b' ? LoanSide.loanB : null),
        insightTitle: 'Principal Comparison',
        insightBody: financials.principalAmount.explanation,
      ),
      LoanComparisonMetric(
        id: 'interest_rate',
        label: 'Interest Rate',
        loanA: ComparisonValue(
          value: financials.interestRate.valueA.isNotEmpty ? financials.interestRate.valueA : '${comparisonJson['loan_a']?['interest_rate']}%',
          meta: '(${financials.interestType.valueA.isNotEmpty ? financials.interestType.valueA : (comparisonJson['loan_a']?['interest_type'] ?? 'floating')})',
        ),
        loanB: ComparisonValue(
          value: financials.interestRate.valueB.isNotEmpty ? financials.interestRate.valueB : '${comparisonJson['loan_b']?['interest_rate']}%',
          meta: '(${financials.interestType.valueB.isNotEmpty ? financials.interestType.valueB : (comparisonJson['loan_b']?['interest_type'] ?? 'fixed')})',
        ),
        winner: financials.interestRate.betterSide == 'loan_a'
            ? LoanSide.loanA
            : (financials.interestRate.betterSide == 'loan_b' ? LoanSide.loanB : null),
        insightTitle: 'Rate comparison',
        insightBody: financials.interestRate.explanation,
      ),
      LoanComparisonMetric(
        id: 'processing_fee',
        label: 'Processing Fee',
        loanA: ComparisonValue(value: financials.processingFee.valueA.isNotEmpty ? financials.processingFee.valueA : (comparisonJson['loan_a']?['processing_fee']?.toString() ?? '0')),
        loanB: ComparisonValue(value: financials.processingFee.valueB.isNotEmpty ? financials.processingFee.valueB : (comparisonJson['loan_b']?['processing_fee']?.toString() ?? '0')),
        winner: financials.processingFee.betterSide == 'loan_a'
            ? LoanSide.loanA
            : (financials.processingFee.betterSide == 'loan_b' ? LoanSide.loanB : null),
        insightTitle: 'Processing charges',
        insightBody: financials.processingFee.explanation,
      ),
      LoanComparisonMetric(
        id: 'emi_value',
        label: 'EMI Amount',
        loanA: ComparisonValue(value: financials.emi.valueA.isNotEmpty ? financials.emi.valueA : (comparisonJson['loan_a']?['emi_amount']?.toString() ?? '0')),
        loanB: ComparisonValue(value: financials.emi.valueB.isNotEmpty ? financials.emi.valueB : (comparisonJson['loan_b']?['emi_amount']?.toString() ?? '0')),
        winner: financials.emi.betterSide == 'loan_a'
            ? LoanSide.loanA
            : (financials.emi.betterSide == 'loan_b' ? LoanSide.loanB : null),
        insightTitle: 'Monthly payment burden',
        insightBody: financials.emi.explanation,
      ),
      LoanComparisonMetric(
        id: 'total_repayment',
        label: 'Total Cost',
        loanA: ComparisonValue(value: financials.totalRepayment.valueA.isNotEmpty ? financials.totalRepayment.valueA : ''),
        loanB: ComparisonValue(value: financials.totalRepayment.valueB.isNotEmpty ? financials.totalRepayment.valueB : ''),
        winner: financials.totalRepayment.betterSide == 'loan_a'
            ? LoanSide.loanA
            : (financials.totalRepayment.betterSide == 'loan_b' ? LoanSide.loanB : null),
        insightTitle: 'Total repayment cost',
        insightBody: financials.totalRepayment.explanation,
      ),
    ];

    final reasons = reasonsList.isNotEmpty
        ? reasonsList.map((r) => AiRecommendationReason(
            icon: 'verified_user',
            title: r.title,
            body: r.insight,
          )).toList()
        : [
            AiRecommendationReason(
              icon: 'insights',
              title: 'Financial Difference',
              body: 'Total interest savings: ${legacyResults?['interest_difference']?.toString() ?? '0.00'}.',
            ),
            AiRecommendationReason(
              icon: 'verified_user',
              title: 'Risk Explanation',
              body: legacyWhy ?? '',
            ),
          ];

    final recHeadline = finalDec.recommendedLoan.isNotEmpty
        ? '${finalDec.recommendedLoan} is recommended by AI'
        : (legacyRecommended != null ? '$legacyRecommended is financially safer...' : 'No recommendation');

    final recSummary = recommended.recommendationReason.isNotEmpty
        ? recommended.recommendationReason
        : (legacyReason ?? '');

    final recWhy = summary.whyBetter.isNotEmpty
        ? summary.whyBetter
        : (legacyWhy ?? '');

    final rec = LoanComparisonRecommendation(
      recommended: recommendedSide,
      headline: recHeadline,
      summary: recSummary,
      clausesAnalyzed: clausesList.isNotEmpty ? clausesList.length : 42,
      reasons: reasons,
      why: recWhy,
    );

    final safetyIndex = (scores.loanA.score > 0 || scores.loanB.score > 0)
        ? (recommendedSide == LoanSide.loanA ? scores.loanA.score : scores.loanB.score)
        : (recommendedSide == LoanSide.loanA ? 8.8 : 8.5);

    final confidence = recommended.confidenceScore > 0 ? recommended.confidenceScore : 0.95;

    final verdict = LoanComparisonVerdict(
      safetyIndex: safetyIndex,
      recommendedLabel: 'Recommended: ${recommendedSide == LoanSide.loanA ? lenderA : lenderB}',
      confidence: confidence,
      confidenceLabel: '${(confidence * 100).toStringAsFixed(1)}% Confidence Score',
    );

    return LoanComparisonReport(
      loanA: docA,
      loanB: docB,
      metrics: metrics,
      recommendation: rec,
      verdict: verdict,
      emiSeries: charts.emiComparisonPoints,
      recommendedLoan: recommended,
      executiveSummary: summary,
      financialBreakdown: financials,
      riskBreakdown: risks,
      loanScores: scores,
      recommendationReasonsList: reasonsList,
      clauseComparisonList: clausesList,
      chartsData: charts,
      finalDecision: finalDec,
      confidenceScore: confScore,
    );
  }
}
