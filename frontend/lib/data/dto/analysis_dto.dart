import 'package:flutter/material.dart';
import 'package:loansense_ai/data/models/loan_analysis_report.dart';

class AnalysisResponseDto {
  final String loanId;
  final String status;
  final AnalysisDetailsDto? analysis;

  AnalysisResponseDto({
    required this.loanId,
    required this.status,
    required this.analysis,
  });

  factory AnalysisResponseDto.fromJson(Map<String, dynamic> json) {
    final rawAnalysis = json['analysis'];
    return AnalysisResponseDto(
      loanId: json['loan_id']?.toString() ?? 'unknown-loan',
      status: json['status']?.toString() ?? 'unknown',
      analysis: rawAnalysis is Map<String, dynamic>
          ? AnalysisDetailsDto.fromJson(rawAnalysis)
          : null,
    );
  }

  LoanAnalysisReport toDomain() {
    if (analysis == null) {
      throw StateError(
          'Cannot call toDomain() on a response with status="$status". '
          'Analysis data is only available when status is "completed".');
    }
    // 1. Map Lender details
    final lenderName = analysis!.metadata.lenderName;
    final loanType = analysis!.metadata.loanType;

    final productName = '$loanType Prime';

    // 2. Parse basic metrics
    final principal = double.tryParse(analysis!.metadata.principalAmount) ?? 0.0;
    final interestRate = analysis!.metadata.interestRate;
    final totalInterest = double.tryParse(analysis!.totalInterest) ?? 0.0;
    final totalPayment = double.tryParse(analysis!.totalPayment) ?? 0.0;
    final emiAmount = double.tryParse(analysis!.metadata.emiAmount) ?? 0.0;
    
    // Fees sum
    final procFee = double.tryParse(analysis!.metadata.processingFee) ?? 0.0;
    final docFee = double.tryParse(analysis!.metadata.documentationFee) ?? 0.0;
    final insFee = double.tryParse(analysis!.metadata.insuranceFee) ?? 0.0;
    final totalFees = procFee + docFee + insFee;

    // Exit penalty details
    final foreclosureCharges = analysis!.metadata.foreclosureCharges;
    final prepaymentCharges = analysis!.metadata.prepaymentCharges;
    final exitPenaltyLabel = foreclosureCharges.isNotEmpty ? '$foreclosureCharges%' : '$prepaymentCharges%';

    // Helper to format currency
    String formatRupee(num val) {
      if (val >= 10000000) {
        return "₹${(val / 10000000).toStringAsFixed(2)} Cr";
      } else if (val >= 100000) {
        return "₹${(val / 100000).toStringAsFixed(2)} Lakh";
      } else {
        return "₹${val.toStringAsFixed(0)}";
      }
    }

    // 3. Create domain Metrics
    final metrics = [
      MetricData(
        id: 'rate',
        label: 'Interest Rate',
        value: '${interestRate.toStringAsFixed(2)}%',
        valueSuffix: analysis!.metadata.interestType,
        accent: const Color(0xFFC3C6D7),
        icon: Icons.percent_rounded,
        secondaryLabel: 'Nominal rate in the agreement.',
        detailTitle: 'Interest Rate Configuration',
        detailBody: 'The loan is structured under a ${analysis!.metadata.interestType} interest rate at a nominal rate of ${interestRate.toStringAsFixed(2)}%.',
      ),
      MetricData(
        id: 'hidden',
        label: 'Hidden Charges',
        value: formatRupee(totalFees),
        valueSuffix: totalFees > 0 ? 'Verified' : 'Waived',
        accent: totalFees > 0 ? const Color(0xFFDBC3A8) : const Color(0xFFC3C6D7),
        icon: Icons.payments_outlined,
        secondaryLabel: 'Sum of administrative processing & insurance fees.',
        detailTitle: 'Fees & Admin Charges',
        detailBody: 'Identified fees: Processing (₹$procFee), Documentation (₹$docFee), Insurance (₹$insFee).',
      ),
      MetricData(
        id: 'total',
        label: 'Total Repayment',
        value: formatRupee(totalPayment),
        valueSuffix: 'Full Term',
        accent: const Color(0xFFC3C6D7),
        icon: Icons.account_balance_wallet_outlined,
        secondaryLabel: 'Principal plus all interest payable over the term.',
        detailTitle: 'Cost Breakdown',
        detailBody: 'Total payment of ${formatRupee(totalPayment)} comprises Principal (${formatRupee(principal)}) + Amortized Interest (${formatRupee(totalInterest)}) + Fees (${formatRupee(totalFees)}).',
      ),
      MetricData(
        id: 'risk',
        label: 'Foreclosure Risk',
        value: exitPenaltyLabel.isEmpty || exitPenaltyLabel == '0%' ? 'Low' : 'Medium',
        valueSuffix: 'Exit Cost',
        accent: exitPenaltyLabel.isEmpty || exitPenaltyLabel == '0%' ? const Color(0xFFC3C6D7) : const Color(0xFFDBC3A8),
        icon: Icons.warning_amber_rounded,
        secondaryLabel: 'Foreclosure penalty is $exitPenaltyLabel.',
        detailTitle: 'Early Repayment Penalty',
        detailBody: 'The exit clause charges $exitPenaltyLabel penalty on prepayment / foreclosure, affecting early refinancing strategies.',
      ),
    ];

    // 4. Map Risk Alerts
    final alerts = analysis!.risks.map((risk) {
      Color accentColor = const Color(0xFFC3C6D7);
      if (risk.riskLevel.toUpperCase() == 'HIGH') {
        accentColor = const Color(0xFFFFB4AB);
      } else if (risk.riskLevel.toUpperCase() == 'MEDIUM') {
        accentColor = const Color(0xFFDBC3A8);
      }
      
      return RiskAlertData(
        id: risk.clauseId,
        title: risk.clauseTitle,
        body: risk.explanation,
        severity: risk.riskLevel,
        accent: accentColor,
        page: 'Page ${risk.pageNumber}',
        clause: risk.clauseText.length > 50 ? '${risk.clauseText.substring(0, 47)}...' : risk.clauseText,
        explanation: risk.recommendation,
      );
    }).toList();

    // 5. Generate source references
    final sources = analysis!.risks.map((e) {
      return SourceReference(
        page: 'Page ${e.pageNumber}',
        title: e.clauseTitle,
        note: e.category,
      );
    }).toList();

    // 6. Generate cost slices for chart
    final double totalSlicesVal = totalPayment > 0 ? totalPayment : (principal + totalInterest + totalFees);
    final costSlices = [
      CostSlice(label: 'Principal', value: principal, ratio: totalSlicesVal > 0 ? principal / totalSlicesVal : 0.4, accent: const Color(0xFFC3C6D7)),
      CostSlice(label: 'Interest', value: totalInterest, ratio: totalSlicesVal > 0 ? totalInterest / totalSlicesVal : 0.5, accent: const Color(0xFF909096)),
      CostSlice(label: 'Charges & Fees', value: totalFees, ratio: totalSlicesVal > 0 ? totalFees / totalSlicesVal : 0.1, accent: const Color(0xFFFFB4AB)),
    ];

    // 7. Amortization curve points
    final emiSeries = List<EmiPoint>.generate(12, (index) {
      final month = index + 1;
      // Simulate amortization ratio changing over time (higher interest first)
      final interestPercent = 0.6 - (index * 0.02);
      final monthlyInterest = emiAmount * interestPercent;
      final monthlyPrincipal = emiAmount * (1 - interestPercent);
      return EmiPoint(
        month: month,
        principal: double.parse(monthlyPrincipal.toStringAsFixed(0)),
        interest: double.parse(monthlyInterest.toStringAsFixed(0)),
      );
    });

    // 8. Clause chips
    final clauseChips = [
      ClauseChip(
        label: 'Exit Penalty: $exitPenaltyLabel',
        accent: foreclosureCharges == '0.0' || foreclosureCharges == '0' || foreclosureCharges.isEmpty
            ? const Color(0xFFC3C6D7)
            : const Color(0xFFFFB4AB),
      ),
      ClauseChip(
        label: 'Benchmark: ${analysis!.metadata.interestType}',
        accent: const Color(0xFFC3C6D7),
      ),
      ClauseChip(
        label: 'Transparency: ${(analysis!.confidenceScore * 100).toInt()}%',
        accent: const Color(0xFFC3C6D7),
      ),
    ];

    // 9. Extractions
    final extractions = [
      LoanExtraction(label: 'Lender Entity', value: lenderName),
      LoanExtraction(label: 'Sanctioned Amount', value: formatRupee(principal)),
      LoanExtraction(label: 'Contract Clarity', value: '${(analysis!.confidenceScore * 100).toInt()}% Transparent'),
      LoanExtraction(label: 'Recommended Move', value: analysis!.recommendations.isNotEmpty ? analysis!.recommendations.first : 'Safe exit'),
    ];

    return LoanAnalysisReport(
      loanId: loanId,
      lenderName: lenderName,
      productName: productName,
      healthScore: analysis!.loanScore.score,
      healthSummary: analysis!.loanScore.rating,
      detailedSummary: analysis!.aiSummary,
      simpleSummary: analysis!.loanScore.explanation,
      recommendedAction: analysis!.recommendations.isNotEmpty ? analysis!.recommendations.first : 'No immediate action.',
      contractClarity: '${(analysis!.confidenceScore * 100).toInt()}% Transparent',
      metrics: metrics,
      alerts: alerts,
      sources: sources.isEmpty ? const [SourceReference(page: 'Page 1', title: 'Sanction Details', note: 'Overview')] : sources,
      costSlices: costSlices,
      emiSeries: emiSeries,
      clauseChips: clauseChips,
      extractions: extractions,
    );
  }
}

class AnalysisDetailsDto {
  final MetadataDto metadata;
  final List<RiskDto> risks;
  final String aiSummary;
  final LoanScoreDto loanScore;
  final double confidenceScore;
  final String totalInterest;
  final String totalPayment;
  final double effectiveApr;
  final List<String> recommendations;

  AnalysisDetailsDto({
    required this.metadata,
    required this.risks,
    required this.aiSummary,
    required this.loanScore,
    required this.confidenceScore,
    required this.totalInterest,
    required this.totalPayment,
    required this.effectiveApr,
    required this.recommendations,
  });

  factory AnalysisDetailsDto.fromJson(Map<String, dynamic> json) {
    return AnalysisDetailsDto(
      metadata: MetadataDto.fromJson(json['metadata'] as Map<String, dynamic>),
      risks: (json['risks'] as List?)
              ?.map((e) => RiskDto.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      aiSummary: json['ai_summary']?.toString() ?? '',
      loanScore: LoanScoreDto.fromJson(json['loan_score'] as Map<String, dynamic>),
      confidenceScore: (json['confidence_score'] as num?)?.toDouble() ?? 0.0,
      totalInterest: json['total_interest']?.toString() ?? '0',
      totalPayment: json['total_payment']?.toString() ?? '0',
      effectiveApr: (json['effective_apr'] as num?)?.toDouble() ?? 0.0,
      recommendations: (json['recommendations'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }
}

class MetadataDto {
  final String lenderName;
  final String loanType;
  final String principalAmount;
  final String interestType;
  final double interestRate;
  final String emiAmount;
  final String processingFee;
  final String documentationFee;
  final String insuranceFee;
  final String foreclosureCharges;
  final String prepaymentCharges;

  MetadataDto({
    required this.lenderName,
    required this.loanType,
    required this.principalAmount,
    required this.interestType,
    required this.interestRate,
    required this.emiAmount,
    required this.processingFee,
    required this.documentationFee,
    required this.insuranceFee,
    required this.foreclosureCharges,
    required this.prepaymentCharges,
  });

  factory MetadataDto.fromJson(Map<String, dynamic> json) {
    return MetadataDto(
      lenderName: json['lender_name']?.toString() ?? 'Unknown Lender',
      loanType: json['loan_type']?.toString() ?? 'Personal Loan',
      principalAmount: json['principal_amount']?.toString() ?? '0',
      interestType: json['interest_type']?.toString() ?? 'floating',
      interestRate: (json['interest_rate'] as num?)?.toDouble() ?? 0.0,
      emiAmount: json['emi_amount']?.toString() ?? '0',
      processingFee: json['processing_fee']?.toString() ?? '0',
      documentationFee: json['documentation_fee']?.toString() ?? '0',
      insuranceFee: json['insurance_fee']?.toString() ?? '0',
      foreclosureCharges: json['foreclosure_charges']?.toString() ?? '0',
      prepaymentCharges: json['prepayment_charges']?.toString() ?? '0',
    );
  }
}

class RiskDto {
  final String clauseId;
  final String clauseTitle;
  final String clauseText;
  final String riskLevel;
  final String category;
  final String explanation;
  final int pageNumber;
  final String recommendation;

  RiskDto({
    required this.clauseId,
    required this.clauseTitle,
    required this.clauseText,
    required this.riskLevel,
    required this.category,
    required this.explanation,
    required this.pageNumber,
    required this.recommendation,
  });

  factory RiskDto.fromJson(Map<String, dynamic> json) {
    return RiskDto(
      clauseId: json['clause_id']?.toString() ?? '',
      clauseTitle: json['clause_title']?.toString() ?? '',
      clauseText: json['clause_text']?.toString() ?? '',
      riskLevel: json['risk_level']?.toString() ?? 'LOW',
      category: json['category']?.toString() ?? 'General',
      explanation: json['explanation']?.toString() ?? '',
      pageNumber: (json['page_number'] as num?)?.toInt() ?? 1,
      recommendation: json['recommendation']?.toString() ?? '',
    );
  }
}

class LoanScoreDto {
  final double score;
  final String rating;
  final List<String> strengths;
  final List<String> weaknesses;
  final String explanation;

  LoanScoreDto({
    required this.score,
    required this.rating,
    required this.strengths,
    required this.weaknesses,
    required this.explanation,
  });

  factory LoanScoreDto.fromJson(Map<String, dynamic> json) {
    return LoanScoreDto(
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      rating: json['rating']?.toString() ?? 'Medium',
      strengths: (json['strengths'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      weaknesses: (json['weaknesses'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      explanation: json['explanation']?.toString() ?? '',
    );
  }
}
