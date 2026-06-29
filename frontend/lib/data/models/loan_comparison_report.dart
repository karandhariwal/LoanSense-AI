import 'package:flutter/foundation.dart';

enum LoanSide { loanA, loanB }

enum ComparisonSignal { positive, warning, negative, neutral }

@immutable
class LoanDocumentSummary {
  final String id;
  final String lenderLabel;
  final String fileName;

  const LoanDocumentSummary({
    required this.id,
    required this.lenderLabel,
    required this.fileName,
  });

  factory LoanDocumentSummary.fromJson(Map<String, dynamic> json) {
    return LoanDocumentSummary(
      id: json['id']?.toString() ?? 'doc-unknown',
      lenderLabel: json['lenderLabel']?.toString() ?? 'Unknown',
      fileName: json['fileName']?.toString() ?? 'loan.pdf',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'lenderLabel': lenderLabel,
        'fileName': fileName,
      };
}

@immutable
class ComparisonBadge {
  final String label;
  final ComparisonSignal signal;

  const ComparisonBadge({
    required this.label,
    required this.signal,
  });

  factory ComparisonBadge.fromJson(Map<String, dynamic> json) {
    final rawSignal = json['signal']?.toString() ?? 'neutral';
    return ComparisonBadge(
      label: json['label']?.toString() ?? '',
      signal: _signalFromString(rawSignal),
    );
  }

  Map<String, dynamic> toJson() => {
        'label': label,
        'signal': signal.name,
      };
}

@immutable
class ComparisonValue {
  final String value;
  final String? meta;
  final ComparisonBadge? badge;

  const ComparisonValue({
    required this.value,
    this.meta,
    this.badge,
  });

  factory ComparisonValue.fromJson(Map<String, dynamic> json) {
    return ComparisonValue(
      value: json['value']?.toString() ?? '',
      meta: json['meta']?.toString(),
      badge: json['badge'] is Map<String, dynamic>
          ? ComparisonBadge.fromJson(json['badge'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'value': value,
        if (meta != null) 'meta': meta,
        if (badge != null) 'badge': badge!.toJson(),
      };
}

@immutable
class LoanComparisonMetric {
  final String id;
  final String label;
  final ComparisonValue loanA;
  final ComparisonValue loanB;
  final LoanSide? winner;
  final String? insightTitle;
  final String? insightBody;

  const LoanComparisonMetric({
    required this.id,
    required this.label,
    required this.loanA,
    required this.loanB,
    required this.winner,
    this.insightTitle,
    this.insightBody,
  });

  factory LoanComparisonMetric.fromJson(Map<String, dynamic> json) {
    final winnerRaw = json['winner']?.toString();
    return LoanComparisonMetric(
      id: json['id']?.toString() ?? 'metric-unknown',
      label: json['label']?.toString() ?? '',
      loanA: ComparisonValue.fromJson(
        (json['loanA'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      loanB: ComparisonValue.fromJson(
        (json['loanB'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      winner: winnerRaw == null ? null : _sideFromString(winnerRaw),
      insightTitle: json['insightTitle']?.toString(),
      insightBody: json['insightBody']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'loanA': loanA.toJson(),
        'loanB': loanB.toJson(),
        if (winner != null) 'winner': winner!.name,
        if (insightTitle != null) 'insightTitle': insightTitle,
        if (insightBody != null) 'insightBody': insightBody,
      };
}

@immutable
class AiRecommendationReason {
  final String icon;
  final String title;
  final String body;

  const AiRecommendationReason({
    required this.icon,
    required this.title,
    required this.body,
  });

  factory AiRecommendationReason.fromJson(Map<String, dynamic> json) {
    return AiRecommendationReason(
      icon: json['icon']?.toString() ?? 'insights',
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'icon': icon,
        'title': title,
        'body': body,
      };
}

@immutable
class LoanComparisonVerdict {
  final double safetyIndex; // 0-10
  final String recommendedLabel;
  final double confidence; // 0-1
  final String confidenceLabel;

  const LoanComparisonVerdict({
    required this.safetyIndex,
    required this.recommendedLabel,
    required this.confidence,
    required this.confidenceLabel,
  });

  factory LoanComparisonVerdict.fromJson(Map<String, dynamic> json) {
    final confidence = (json['confidence'] as num?)?.toDouble() ?? 0.0;
    return LoanComparisonVerdict(
      safetyIndex: (json['safetyIndex'] as num?)?.toDouble() ?? 0.0,
      recommendedLabel: json['recommendedLabel']?.toString() ?? '',
      confidence: confidence.clamp(0.0, 1.0),
      confidenceLabel: json['confidenceLabel']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'safetyIndex': safetyIndex,
        'recommendedLabel': recommendedLabel,
        'confidence': confidence,
        'confidenceLabel': confidenceLabel,
      };
}

@immutable
class LoanComparisonRecommendation {
  final LoanSide recommended;
  final String headline;
  final String summary;
  final int clausesAnalyzed;
  final List<AiRecommendationReason> reasons;
  final String why;

  const LoanComparisonRecommendation({
    required this.recommended,
    required this.headline,
    required this.summary,
    required this.clausesAnalyzed,
    required this.reasons,
    required this.why,
  });

  factory LoanComparisonRecommendation.fromJson(Map<String, dynamic> json) {
    return LoanComparisonRecommendation(
      recommended: _sideFromString(json['recommended']?.toString() ?? 'loanB'),
      headline: json['headline']?.toString() ?? '',
      summary: json['summary']?.toString() ?? '',
      clausesAnalyzed: (json['clausesAnalyzed'] as num?)?.toInt() ?? 0,
      reasons: (json['reasons'] as List?)
              ?.whereType<Map>()
              .map((e) => AiRecommendationReason.fromJson(
                    e.cast<String, dynamic>(),
                  ))
              .toList() ??
          const [],
      why: json['why']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'recommended': recommended.name,
        'headline': headline,
        'summary': summary,
        'clausesAnalyzed': clausesAnalyzed,
        'reasons': reasons.map((e) => e.toJson()).toList(),
        'why': why,
      };
}

@immutable
class EmiComparisonPoint {
  final int month;
  final double loanAEmi;
  final double loanBEmi;

  const EmiComparisonPoint({
    required this.month,
    required this.loanAEmi,
    required this.loanBEmi,
  });

  factory EmiComparisonPoint.fromJson(Map<String, dynamic> json) {
    return EmiComparisonPoint(
      month: (json['month'] as num?)?.toInt() ?? 0,
      loanAEmi: (json['loanAEmi'] as num?)?.toDouble() ?? 0.0,
      loanBEmi: (json['loanBEmi'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'month': month,
        'loanAEmi': loanAEmi,
        'loanBEmi': loanBEmi,
      };
}

// ==========================================
// NEW COMPREHENSIVE DETAILED MODEL CLASSES
// ==========================================

@immutable
class RecommendedLoan {
  final String lenderName;
  final double recommendationScore;
  final String recommendationReason;
  final double confidenceScore;

  const RecommendedLoan({
    required this.lenderName,
    required this.recommendationScore,
    required this.recommendationReason,
    required this.confidenceScore,
  });

  factory RecommendedLoan.fromJson(Map<String, dynamic> json) {
    return RecommendedLoan(
      lenderName: json['lender_name']?.toString() ?? '',
      recommendationScore: (json['recommendation_score'] as num?)?.toDouble() ?? 0.0,
      recommendationReason: json['recommendation_reason']?.toString() ?? '',
      confidenceScore: (json['confidence_score'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

@immutable
class ExecutiveSummary {
  final String betterLoan;
  final String whyBetter;
  final String biggestDifferences;
  final String mainRisks;
  final String overallRecommendation;

  const ExecutiveSummary({
    required this.betterLoan,
    required this.whyBetter,
    required this.biggestDifferences,
    required this.mainRisks,
    required this.overallRecommendation,
  });

  factory ExecutiveSummary.fromJson(Map<String, dynamic> json) {
    return ExecutiveSummary(
      betterLoan: json['better_loan']?.toString() ?? '',
      whyBetter: json['why_better']?.toString() ?? '',
      biggestDifferences: json['biggest_differences']?.toString() ?? '',
      mainRisks: json['main_risks']?.toString() ?? '',
      overallRecommendation: json['overall_recommendation']?.toString() ?? '',
    );
  }
}

@immutable
class FinancialItem {
  final String valueA;
  final String valueB;
  final String betterSide; // "loan_a", "loan_b", "none"
  final String explanation;

  const FinancialItem({
    required this.valueA,
    required this.valueB,
    required this.betterSide,
    required this.explanation,
  });

  factory FinancialItem.fromJson(Map<String, dynamic> json) {
    return FinancialItem(
      valueA: json['value_a']?.toString() ?? '',
      valueB: json['value_b']?.toString() ?? '',
      betterSide: json['better_side']?.toString() ?? 'none',
      explanation: json['explanation']?.toString() ?? '',
    );
  }
}

@immutable
class FinancialBreakdown {
  final FinancialItem principalAmount;
  final FinancialItem interestRate;
  final FinancialItem interestType;
  final FinancialItem processingFee;
  final FinancialItem documentationFee;
  final FinancialItem insuranceCost;
  final FinancialItem tenure;
  final FinancialItem emi;
  final FinancialItem totalInterest;
  final FinancialItem totalRepayment;
  final FinancialItem effectiveApr;

  const FinancialBreakdown({
    required this.principalAmount,
    required this.interestRate,
    required this.interestType,
    required this.processingFee,
    required this.documentationFee,
    required this.insuranceCost,
    required this.tenure,
    required this.emi,
    required this.totalInterest,
    required this.totalRepayment,
    required this.effectiveApr,
  });

  factory FinancialBreakdown.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> safeMap(String key) {
      final val = json[key];
      return val is Map ? val.cast<String, dynamic>() : const <String, dynamic>{};
    }

    return FinancialBreakdown(
      principalAmount: FinancialItem.fromJson(safeMap('principal_amount')),
      interestRate: FinancialItem.fromJson(safeMap('interest_rate')),
      interestType: FinancialItem.fromJson(safeMap('interest_type')),
      processingFee: FinancialItem.fromJson(safeMap('processing_fee')),
      documentationFee: FinancialItem.fromJson(safeMap('documentation_fee')),
      insuranceCost: FinancialItem.fromJson(safeMap('insurance_cost')),
      tenure: FinancialItem.fromJson(safeMap('tenure')),
      emi: FinancialItem.fromJson(safeMap('emi')),
      totalInterest: FinancialItem.fromJson(safeMap('total_interest')),
      totalRepayment: FinancialItem.fromJson(safeMap('total_repayment')),
      effectiveApr: FinancialItem.fromJson(safeMap('effective_apr')),
    );
  }
}

@immutable
class RiskItem {
  final String valueA;
  final String valueB;
  final String betterSide; // "loan_a", "loan_b", "none"
  final String explanation;

  const RiskItem({
    required this.valueA,
    required this.valueB,
    required this.betterSide,
    required this.explanation,
  });

  factory RiskItem.fromJson(Map<String, dynamic> json) {
    return RiskItem(
      valueA: json['value_a']?.toString() ?? '',
      valueB: json['value_b']?.toString() ?? '',
      betterSide: json['better_side']?.toString() ?? 'none',
      explanation: json['explanation']?.toString() ?? '',
    );
  }
}

@immutable
class RiskComparison {
  final RiskItem hiddenCharges;
  final RiskItem foreclosurePenalties;
  final RiskItem prepaymentCharges;
  final RiskItem bounceCharges;
  final RiskItem latePaymentFees;
  final RiskItem floatingRateClauses;
  final RiskItem legalDiscretionClauses;
  final RiskItem mandatoryInsurance;

  const RiskComparison({
    required this.hiddenCharges,
    required this.foreclosurePenalties,
    required this.prepaymentCharges,
    required this.bounceCharges,
    required this.latePaymentFees,
    required this.floatingRateClauses,
    required this.legalDiscretionClauses,
    required this.mandatoryInsurance,
  });

  factory RiskComparison.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> safeMap(String key) {
      final val = json[key];
      return val is Map ? val.cast<String, dynamic>() : const <String, dynamic>{};
    }

    return RiskComparison(
      hiddenCharges: RiskItem.fromJson(safeMap('hidden_charges')),
      foreclosurePenalties: RiskItem.fromJson(safeMap('foreclosure_penalties')),
      prepaymentCharges: RiskItem.fromJson(safeMap('prepayment_charges')),
      bounceCharges: RiskItem.fromJson(safeMap('bounce_charges')),
      latePaymentFees: RiskItem.fromJson(safeMap('late_payment_fees')),
      floatingRateClauses: RiskItem.fromJson(safeMap('floating_rate_clauses')),
      legalDiscretionClauses: RiskItem.fromJson(safeMap('legal_discretion_clauses')),
      mandatoryInsurance: RiskItem.fromJson(safeMap('mandatory_insurance')),
    );
  }
}

@immutable
class LoanScoreInfo {
  final double score;
  final String rating; // "Low", "Medium", "High"
  final String explanation;

  const LoanScoreInfo({
    required this.score,
    required this.rating,
    required this.explanation,
  });

  factory LoanScoreInfo.fromJson(Map<String, dynamic> json) {
    return LoanScoreInfo(
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      rating: json['rating']?.toString() ?? 'Low',
      explanation: json['explanation']?.toString() ?? '',
    );
  }
}

@immutable
class LoanScores {
  final LoanScoreInfo loanA;
  final LoanScoreInfo loanB;

  const LoanScores({
    required this.loanA,
    required this.loanB,
  });

  factory LoanScores.fromJson(Map<String, dynamic> json) {
    final aVal = json['loan_a'];
    final bVal = json['loan_b'];
    return LoanScores(
      loanA: LoanScoreInfo.fromJson(aVal is Map ? aVal.cast<String, dynamic>() : const <String, dynamic>{}),
      loanB: LoanScoreInfo.fromJson(bVal is Map ? bVal.cast<String, dynamic>() : const <String, dynamic>{}),
    );
  }
}

@immutable
class AIRecommendationReasonItem {
  final String title;
  final String insight;
  final bool isExpandable;

  const AIRecommendationReasonItem({
    required this.title,
    required this.insight,
    required this.isExpandable,
  });

  factory AIRecommendationReasonItem.fromJson(Map<String, dynamic> json) {
    return AIRecommendationReasonItem(
      title: json['title']?.toString() ?? '',
      insight: json['insight']?.toString() ?? '',
      isExpandable: json['is_expandable'] as bool? ?? true,
    );
  }
}

@immutable
class ClauseComparisonItem {
  final String clauseATitle;
  final String clauseAText;
  final int? clauseAPage;
  final String clauseBTitle;
  final String clauseBText;
  final int? clauseBPage;
  final String aiExplanation;
  final String riskDifference;
  final String recommendation;
  final double confidenceScore;

  const ClauseComparisonItem({
    required this.clauseATitle,
    required this.clauseAText,
    required this.clauseAPage,
    required this.clauseBTitle,
    required this.clauseBText,
    required this.clauseBPage,
    required this.aiExplanation,
    required this.riskDifference,
    required this.recommendation,
    required this.confidenceScore,
  });

  factory ClauseComparisonItem.fromJson(Map<String, dynamic> json) {
    return ClauseComparisonItem(
      clauseATitle: json['clause_a_title']?.toString() ?? '',
      clauseAText: json['clause_a_text']?.toString() ?? '',
      clauseAPage: (json['clause_a_page'] as num?)?.toInt(),
      clauseBTitle: json['clause_b_title']?.toString() ?? '',
      clauseBText: json['clause_b_text']?.toString() ?? '',
      clauseBPage: (json['clause_b_page'] as num?)?.toInt(),
      aiExplanation: json['ai_explanation']?.toString() ?? '',
      riskDifference: json['risk_difference']?.toString() ?? '',
      recommendation: json['recommendation']?.toString() ?? '',
      confidenceScore: (json['confidence_score'] as num?)?.toDouble() ?? 0.9,
    );
  }
}

@immutable
class CostBreakdownPoint {
  final double principal;
  final double interest;
  final double fees;

  const CostBreakdownPoint({
    required this.principal,
    required this.interest,
    required this.fees,
  });

  factory CostBreakdownPoint.fromJson(Map<String, dynamic> json) {
    return CostBreakdownPoint(
      principal: (json['principal'] as num?)?.toDouble() ?? 0.0,
      interest: (json['interest'] as num?)?.toDouble() ?? 0.0,
      fees: (json['fees'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

@immutable
class RiskSeverityCount {
  final int high;
  final int medium;
  final int low;

  const RiskSeverityCount({
    required this.high,
    required this.medium,
    required this.low,
  });

  factory RiskSeverityCount.fromJson(Map<String, dynamic> json) {
    return RiskSeverityCount(
      high: (json['high'] as num?)?.toInt() ?? 0,
      medium: (json['medium'] as num?)?.toInt() ?? 0,
      low: (json['low'] as num?)?.toInt() ?? 0,
    );
  }
}

@immutable
class ChartsData {
  final List<EmiComparisonPoint> emiComparisonPoints;
  final double totalRepaymentA;
  final double totalRepaymentB;
  final double totalInterestA;
  final double totalInterestB;
  final CostBreakdownPoint costBreakdownA;
  final CostBreakdownPoint costBreakdownB;
  final RiskSeverityCount riskA;
  final RiskSeverityCount riskB;

  const ChartsData({
    required this.emiComparisonPoints,
    required this.totalRepaymentA,
    required this.totalRepaymentB,
    required this.totalInterestA,
    required this.totalInterestB,
    required this.costBreakdownA,
    required this.costBreakdownB,
    required this.riskA,
    required this.riskB,
  });

  factory ChartsData.fromJson(Map<String, dynamic> json) {
    final emiList = (json['emi_comparison']?['series'] as List?)
            ?.whereType<Map>()
            .map((e) => EmiComparisonPoint(
                  month: (e['month'] as num?)?.toInt() ?? 0,
                  loanAEmi: (e['loan_a_emi'] as num?)?.toDouble() ?? 0.0,
                  loanBEmi: (e['loan_b_emi'] as num?)?.toDouble() ?? 0.0,
                ))
            .toList() ??
        const [];

    return ChartsData(
      emiComparisonPoints: emiList,
      totalRepaymentA: (json['total_repayment_comparison']?['loan_a'] as num?)?.toDouble() ?? 0.0,
      totalRepaymentB: (json['total_repayment_comparison']?['loan_b'] as num?)?.toDouble() ?? 0.0,
      totalInterestA: (json['interest_comparison']?['loan_a'] as num?)?.toDouble() ?? 0.0,
      totalInterestB: (json['interest_comparison']?['loan_b'] as num?)?.toDouble() ?? 0.0,
      costBreakdownA: CostBreakdownPoint.fromJson(
        (json['cost_breakdown_loan_a'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      costBreakdownB: CostBreakdownPoint.fromJson(
        (json['cost_breakdown_loan_b'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      riskA: RiskSeverityCount.fromJson(
        (json['risk_distribution']?['loan_a'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      riskB: RiskSeverityCount.fromJson(
        (json['risk_distribution']?['loan_b'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
    );
  }
}

@immutable
class FinalDecisionCard {
  final String recommendedLoan;
  final double overallScore;
  final double confidence;
  final List<String> keyReasons;
  final List<String> potentialConcerns;
  final String actionRecommendation;

  const FinalDecisionCard({
    required this.recommendedLoan,
    required this.overallScore,
    required this.confidence,
    required this.keyReasons,
    required this.potentialConcerns,
    required this.actionRecommendation,
  });

  factory FinalDecisionCard.fromJson(Map<String, dynamic> json) {
    return FinalDecisionCard(
      recommendedLoan: json['recommended_loan']?.toString() ?? '',
      overallScore: (json['overall_score'] as num?)?.toDouble() ?? 0.0,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      keyReasons: (json['key_reasons'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      potentialConcerns: (json['potential_concerns'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      actionRecommendation: json['action_recommendation']?.toString() ?? '',
    );
  }
}

@immutable
class LoanComparisonReport {
  // Legacy fields for backward compatibility
  final LoanDocumentSummary loanA;
  final LoanDocumentSummary loanB;
  final List<LoanComparisonMetric> metrics;
  final LoanComparisonRecommendation recommendation;
  final LoanComparisonVerdict verdict;
  final List<EmiComparisonPoint> emiSeries;

  // New highly detailed fields for 9 sections
  final RecommendedLoan recommendedLoan;
  final ExecutiveSummary executiveSummary;
  final FinancialBreakdown financialBreakdown;
  final RiskComparison riskBreakdown;
  final LoanScores loanScores;
  final List<AIRecommendationReasonItem> recommendationReasonsList;
  final List<ClauseComparisonItem> clauseComparisonList;
  final ChartsData chartsData;
  final FinalDecisionCard finalDecision;
  final double confidenceScore;

  const LoanComparisonReport({
    required this.loanA,
    required this.loanB,
    required this.metrics,
    required this.recommendation,
    required this.verdict,
    required this.emiSeries,
    // New fields
    required this.recommendedLoan,
    required this.executiveSummary,
    required this.financialBreakdown,
    required this.riskBreakdown,
    required this.loanScores,
    required this.recommendationReasonsList,
    required this.clauseComparisonList,
    required this.chartsData,
    required this.finalDecision,
    required this.confidenceScore,
  });

  factory LoanComparisonReport.fromJson(Map<String, dynamic> json) {
    // Implement fallback parsing if needed, but in our end-to-end flow we parse properly.
    return LoanComparisonReport(
      loanA: LoanDocumentSummary.fromJson(
        (json['loanA'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      loanB: LoanDocumentSummary.fromJson(
        (json['loanB'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      metrics: (json['metrics'] as List?)
              ?.whereType<Map>()
              .map((e) =>
                  LoanComparisonMetric.fromJson(e.cast<String, dynamic>()))
              .toList() ??
          const [],
      recommendation: LoanComparisonRecommendation.fromJson(
        (json['recommendation'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      verdict: LoanComparisonVerdict.fromJson(
        (json['verdict'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      emiSeries: (json['emiSeries'] as List?)
              ?.whereType<Map>()
              .map((e) => EmiComparisonPoint.fromJson(e.cast<String, dynamic>()))
              .toList() ??
          const [],
      // New fields
      recommendedLoan: RecommendedLoan.fromJson(
        (json['recommended_loan'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      executiveSummary: ExecutiveSummary.fromJson(
        (json['comparison_summary'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      financialBreakdown: FinancialBreakdown.fromJson(
        (json['financial_breakdown'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      riskBreakdown: RiskComparison.fromJson(
        (json['risk_breakdown'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      loanScores: LoanScores.fromJson(
        (json['loan_scores'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      recommendationReasonsList: (json['recommendation_reasons'] as List?)
              ?.whereType<Map>()
              .map((e) => AIRecommendationReasonItem.fromJson(e.cast<String, dynamic>()))
              .toList() ??
          const [],
      clauseComparisonList: (json['clause_comparison'] as List?)
              ?.whereType<Map>()
              .map((e) => ClauseComparisonItem.fromJson(e.cast<String, dynamic>()))
              .toList() ??
          const [],
      chartsData: ChartsData.fromJson(
        (json['charts_data'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      finalDecision: FinalDecisionCard.fromJson(
        (json['final_decision'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      confidenceScore: (json['confidence_score'] as num?)?.toDouble() ?? 0.95,
    );
  }

  Map<String, dynamic> toJson() => {
        'loanA': loanA.toJson(),
        'loanB': loanB.toJson(),
        'metrics': metrics.map((e) => e.toJson()).toList(),
        'recommendation': recommendation.toJson(),
        'verdict': verdict.toJson(),
        'emiSeries': emiSeries.map((e) => e.toJson()).toList(),
      };
}

LoanSide _sideFromString(String raw) {
  switch (raw.toLowerCase()) {
    case 'loana':
    case 'a':
    case 'loan_a':
      return LoanSide.loanA;
    case 'loanb':
    case 'b':
    case 'loan_b':
    default:
      return LoanSide.loanB;
  }
}

ComparisonSignal _signalFromString(String raw) {
  switch (raw.toLowerCase()) {
    case 'positive':
    case 'good':
    case 'safe':
    case 'verified':
      return ComparisonSignal.positive;
    case 'warning':
    case 'medium':
      return ComparisonSignal.warning;
    case 'negative':
    case 'bad':
    case 'critical':
      return ComparisonSignal.negative;
    default:
      return ComparisonSignal.neutral;
  }
}
