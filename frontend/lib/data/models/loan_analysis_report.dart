import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class LoanAnalysisReport {
  final String loanId;
  final String lenderName;
  final String productName;
  final double healthScore;
  final String healthSummary;
  final String detailedSummary;
  final String simpleSummary;
  final String recommendedAction;
  final String contractClarity;
  final List<MetricData> metrics;
  final List<RiskAlertData> alerts;
  final List<SourceReference> sources;
  final List<CostSlice> costSlices;
  final List<EmiPoint> emiSeries;
  final List<ClauseChip> clauseChips;
  final List<LoanExtraction> extractions;

  const LoanAnalysisReport({
    required this.loanId,
    required this.lenderName,
    required this.productName,
    required this.healthScore,
    required this.healthSummary,
    required this.detailedSummary,
    required this.simpleSummary,
    required this.recommendedAction,
    required this.contractClarity,
    required this.metrics,
    required this.alerts,
    required this.sources,
    required this.costSlices,
    required this.emiSeries,
    required this.clauseChips,
    required this.extractions,
  });

  factory LoanAnalysisReport.fromJson(Map<String, dynamic> json) {
    return LoanAnalysisReport(
      loanId: json['loanId']?.toString() ?? 'loan-unknown',
      lenderName: json['lenderName']?.toString() ?? 'Unknown lender',
      productName: json['productName']?.toString() ?? 'Loan product',
      healthScore: (json['healthScore'] as num?)?.toDouble() ?? 0.0,
      healthSummary: json['healthSummary']?.toString() ?? '',
      detailedSummary: json['detailedSummary']?.toString() ?? '',
      simpleSummary: json['simpleSummary']?.toString() ?? '',
      recommendedAction: json['recommendedAction']?.toString() ?? '',
      contractClarity: json['contractClarity']?.toString() ?? '',
      metrics: (json['metrics'] as List?)
              ?.map((e) => MetricData.fromJson(e))
              .toList() ??
          const [],
      alerts: (json['alerts'] as List?)
              ?.map((e) => RiskAlertData.fromJson(e))
              .toList() ??
          const [],
      sources: (json['sources'] as List?)
              ?.map((e) => SourceReference.fromJson(e))
              .toList() ??
          const [],
      costSlices: (json['costSlices'] as List?)
              ?.map((e) => CostSlice.fromJson(e))
              .toList() ??
          const [],
      emiSeries: (json['emiSeries'] as List?)
              ?.map((e) => EmiPoint.fromJson(e))
              .toList() ??
          const [],
      clauseChips: (json['clauseChips'] as List?)
              ?.map((e) => ClauseChip.fromJson(e))
              .toList() ??
          const [],
      extractions: (json['extractions'] as List?)
              ?.map((e) => LoanExtraction.fromJson(e))
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'loanId': loanId,
      'lenderName': lenderName,
      'productName': productName,
      'healthScore': healthScore,
      'healthSummary': healthSummary,
      'detailedSummary': detailedSummary,
      'simpleSummary': simpleSummary,
      'recommendedAction': recommendedAction,
      'contractClarity': contractClarity,
      'metrics': metrics.map((e) => e.toJson()).toList(),
      'alerts': alerts.map((e) => e.toJson()).toList(),
      'sources': sources.map((e) => e.toJson()).toList(),
      'costSlices': costSlices.map((e) => e.toJson()).toList(),
      'emiSeries': emiSeries.map((e) => e.toJson()).toList(),
      'clauseChips': clauseChips.map((e) => e.toJson()).toList(),
      'extractions': extractions.map((e) => e.toJson()).toList(),
    };
  }

  /// ⚠️ DEPRECATED: Mock data factory - use real API data instead
  /// This method generates hardcoded synthetic data for testing only.
  /// REMOVED: Mock usage in UI screens has been replaced with proper API calls.
  /// See: [LoanRepository.fetchAnalysis] for the real API method.
  ///
  /// Usages of .mock() are resolved to fetch real data.
  @Deprecated('Use LoanRepository.fetchAnalysis() instead of .mock()')
  factory LoanAnalysisReport.mock({required String loanId}) {
    return LoanAnalysisReport.generateMockReport(
      fileName: "variable_term_loan_agreement.pdf",
      fileSizeMb: 2.4,
      loanId: loanId,
    );
  }

  /// ⚠️ DEPRECATED: Synthetic mock report generator
  /// This generates hardcoded deterministic data based on file hash.
  /// REAL DATA should come from [LoanRepository] and backend AI analysis.
  /// This exists only for development/demo when backend is not available.
  @Deprecated('Use LoanRepository.fetchAnalysis() to get real backend data')
  factory LoanAnalysisReport.generateMockReport({
    required String fileName,
    required double fileSizeMb,
    String? loanId,
  }) {
    if (kReleaseMode) {
      throw StateError('Mock loan reports are disabled in release builds.');
    }

    final cleanLoanId = loanId ?? "LNS-${(fileName.hashCode.abs() % 900000) + 100000}";
    final lowerName = fileName.toLowerCase();

    // Determine Lender Name based on uploaded file name
    String lenderName = "Northstar Finance";
    if (lowerName.contains("hdfc")) {
      lenderName = "HDFC Bank Ltd";
    } else if (lowerName.contains("sbi") || lowerName.contains("state bank")) {
      lenderName = "State Bank of India";
    } else if (lowerName.contains("icici")) {
      lenderName = "ICICI Bank Ltd";
    } else if (lowerName.contains("axis")) {
      lenderName = "Axis Bank Ltd";
    } else if (lowerName.contains("lic")) {
      lenderName = "LIC Housing Finance";
    } else if (lowerName.contains("bajaj")) {
      lenderName = "Bajaj Finserv Ltd";
    } else if (lowerName.contains("tata")) {
      lenderName = "Tata Capital Financials";
    } else {
      // Create a nice readable name from file name if possible, or fallback
      final baseName = fileName.split('.').first;
      if (baseName.length > 5 && baseName.length < 25) {
        lenderName = baseName
            .replaceAll(RegExp(r'[-_]'), ' ')
            .split(' ')
            .map((str) => str.isNotEmpty ? '${str[0].toUpperCase()}${str.substring(1)}' : '')
            .join(' ');
      }
    }

    // Deterministic attributes based on file hash
    final int seed = fileName.hashCode.abs();
    
    // Health score: let's range it between 4.5 and 9.2
    final double healthScore = 4.5 + (seed % 48) / 10.0;
    final int clarityPercent = 75 + (seed % 21); // 75% to 95%
    final double baseRate = 7.95 + (seed % 15) * 0.1; // 7.95% to 9.35%

    // Calculate dynamic values for total repayment
    final int principalVal = 100000 * ((seed % 9) + 5); // 500k to 1.3m (standard loan sizes in INR)
    final double interestRatio = 0.30 + ((10.0 - healthScore) * 0.05); // interest percentage scales with bad health
    final double hiddenRatio = 0.01 + ((10.0 - healthScore) * 0.008); 
    
    final int interestVal = (principalVal * interestRatio).round();
    final int hiddenVal = (principalVal * hiddenRatio).round();
    final int totalRepaymentVal = principalVal + interestVal + hiddenVal;

    // Format currency to match Indian Rupee formatting nicely
    String formatRupee(num val) {
      if (val >= 10000000) {
        return "₹${(val / 10000000).toStringAsFixed(2)} Cr";
      } else if (val >= 100000) {
        return "₹${(val / 100000).toStringAsFixed(2)} Lakh";
      } else {
        return "₹${val.toString()}";
      }
    }

    // Health Summary & Details based on health category
    String healthSummary;
    String detailedSummary;
    String simpleSummary;
    String recommendedAction;
    List<RiskAlertData> alerts = [];

    if (healthScore >= 8.0) {
      healthSummary = "Excellent structural health. Very favorable terms with standard benchmark index rules.";
      detailedSummary = "The loan documentation is highly transparent with standard amortization structures. "
          "The exit penalties are completely waived after month 12, and the interest reset is locked to the official bank benchmark "
          "with a minimal margin overlay. Hidden charges represent less than 1.5% of total value.";
      simpleSummary = "This is a great loan with safe terms. There are no sneaky penalties, and prepayment is free after one year. "
          "You can sign this with confidence.";
      recommendedAction = "Safe to sign. Proceed with closure.";

      alerts = const [
        RiskAlertData(
          id: "prepay-waive",
          title: "Pre-payment Waiver Active",
          body: "Pre-payment penalties are completely waived after month 12. You have freedom to refinance early.",
          severity: "Verified",
          accent: Color(0xFFC3C6D7), // Primary / verified color
          page: "Page 4",
          clause: "Clause 6.2",
          explanation: "Allows risk-free refinancing if market rates drop, saving exit penalty charges.",
        ),
        RiskAlertData(
          id: "interest-cap",
          title: "Fixed Interest Protection",
          body: "Interest cap protection limits variable hikes to a maximum 1.5% above base index.",
          severity: "Verified",
          accent: Color(0xFFC3C6D7),
          page: "Page 8",
          clause: "Clause 9.1",
          explanation: "Protects monthly installments from high volatility during inflationary cycles.",
        ),
      ];
    } else if (healthScore >= 6.0) {
      healthSummary = "Moderate structural health. Specific rate buffers and moderate pre-payment exit penalties apply.";
      detailedSummary = "Your loan exhibits fair market terms but includes a variable interest reset in Year 5 and exit costs. "
          "The pre-payment penalty is 2.0% within the first 24 months. Total hidden charges sum to ₹${hiddenVal.toString()} which "
          "is slightly elevated due to processing and documentation layers.";
      simpleSummary = "The loan is standard, but check the prepayment fee. You pay 2% if you exit in the first two years. "
          "Also, the interest rate will adjust in Year 5 based on a bank index, which might increase your monthly payments.";
      recommendedAction = "Refinance in 24 months to optimize cost.";

      alerts = const [
        RiskAlertData(
          id: "penalty-mid",
          title: "Standard Exit Penalty",
          body: "A 2.0% pre-payment penalty applies if closed before month 24. Standard but restrictive.",
          severity: "Medium",
          accent: Color(0xFFDBC3A8), // Tertiary / yellow accent
          page: "Page 11",
          clause: "Clause 8.4",
          explanation: "This clause creates exit costs if you choose to refinance or pre-pay the loan early.",
        ),
        RiskAlertData(
          id: "reset-mid",
          title: "Variable Rate Reset Clause",
          body: "Year 5 interest rate resets to the bench index with a standard 180 bps margin.",
          severity: "Medium",
          accent: Color(0xFFDBC3A8),
          page: "Page 15",
          clause: "Clause 14.1",
          explanation: "Allows the bank to adjust rates after year 5, which could raise monthly payouts if interest rates are high.",
        ),
        RiskAlertData(
          id: "doc-waiver",
          title: "Waived Processing Charges",
          body: "Processing charges are fully waived under tier 1 credit benefits. Savings: ₹6,500.",
          severity: "Verified",
          accent: Color(0xFFC3C6D7),
          page: "Page 2",
          clause: "Schedule A",
          explanation: "A positive term saving you immediate cash on loan initialization.",
        ),
      ];
    } else {
      healthSummary = "High Risk profile. Predatory pre-payment clauses and aggressive interest rate escalations detected.";
      detailedSummary = "This agreement contains high financial risk terms. Foreclosure exit penalties are set at 4.0% for 36 months, "
          "which is significantly above the market average. Additionally, the variable rate reset in Year 3 allows the lender to increase "
          "the rate with a 320 bps margin, exposing you to severe amortization increases. Service layers are high.";
      simpleSummary = "Warning: This loan has highly unfavorable terms. The bank will charge a massive 4% fee if you pay it off early "
          "in the first 3 years. They also have the right to jump your interest rate aggressively starting from Year 3.";
      recommendedAction = "Avoid signing. Negotiate critical terms.";

      alerts = const [
        RiskAlertData(
          id: "penalty-high",
          title: "Predatory Pre-payment Clause",
          body: "A heavy 4.0% penalty applies if closed before month 36. This is double the current market benchmark.",
          severity: "High",
          accent: Color(0xFFFFB4AB), // Error / red accent
          page: "Page 14",
          clause: "Clause 7.2",
          explanation: "Effectively traps you in this high interest rate loan and prevents cheaper refinancing options.",
        ),
        RiskAlertData(
          id: "reset-high",
          title: "Aggressive Variable Rate Reset",
          body: "Year 3 variable interest reset permits rate escalation with an elevated 320 bps margin.",
          severity: "High",
          accent: Color(0xFFFFB4AB),
          page: "Page 19",
          clause: "Clause 11.2",
          explanation: "Exposes the borrower to large installment hikes without proper shielding caps.",
        ),
        RiskAlertData(
          id: "fees-high",
          title: "Hidden Administration Fees",
          body: "Compounded quarterly service charges of 0.5% are quietly slipped into the premium schedule.",
          severity: "High",
          accent: Color(0xFFFFB4AB),
          page: "Page 7",
          clause: "Clause 3.8",
          explanation: "Raises the effective interest rate (APR) quietly behind the scenes.",
        ),
      ];
    }

    // Dynamic metrics
    final metrics = [
      MetricData(
        id: "rate",
        label: "Interest Rate",
        value: "${baseRate.toStringAsFixed(2)}%",
        valueSuffix: healthScore >= 8.0 ? "Stable" : "Variable",
        accent: const Color(0xFFC3C6D7),
        icon: Icons.percent_rounded,
        secondaryLabel: healthScore >= 8.0 ? "Highly competitive fixed buffer." : "Rate increases after reset period.",
        detailTitle: "Interest Rate Exposure",
        detailBody: "The base rate starts competitive at ${baseRate.toStringAsFixed(2)}%, but variable terms enable periodic adjustment based on lender benchmarks.",
      ),
      MetricData(
        id: "hidden",
        label: "Hidden Charges",
        value: formatRupee(hiddenVal),
        valueSuffix: healthScore >= 8.0 ? "Waived" : "Critical",
        accent: healthScore >= 8.0 ? const Color(0xFFC3C6D7) : const Color(0xFFDBC3A8),
        icon: Icons.payments_outlined,
        secondaryLabel: "Processing, tech audits, and administrative fees.",
        detailTitle: "Hidden Fees Breakdown",
        detailBody: "Our model detected a total of ₹${hiddenVal.toString()} in non-disclosed charges layered across file processing, verification, and legal terms.",
      ),
      MetricData(
        id: "total",
        label: "Total Repayment",
        value: formatRupee(totalRepaymentVal),
        valueSuffix: "Full Term",
        accent: const Color(0xFFC3C6D7),
        icon: Icons.account_balance_wallet_outlined,
        secondaryLabel: "Principal plus amortization interest over full term.",
        detailTitle: "Repayment Forecast",
        detailBody: "Assuming standard payments without early foreclosure, you will pay a total of ${formatRupee(totalRepaymentVal)} across the loan tenure.",
      ),
      MetricData(
        id: "risk",
        label: "Foreclosure Risk",
        value: healthScore >= 8.0 ? "Low" : (healthScore >= 6.0 ? "Medium" : "High"),
        valueSuffix: "Exit Cost",
        accent: healthScore >= 8.0
            ? const Color(0xFFC3C6D7)
            : (healthScore >= 6.0 ? const Color(0xFFDBC3A8) : const Color(0xFFFFB4AB)),
        icon: Icons.warning_amber_rounded,
        secondaryLabel: healthScore >= 8.0 ? "Minimal prepayment exit cost." : "Elevated penalties block refinance.",
        detailTitle: "Foreclosure and Prepayment Penalty",
        detailBody: "Pre-payment charges restrict your financial flexibility to clear debt earlier. The parser flagged exit charges of ${healthScore >= 8.0 ? '0%' : (healthScore >= 6.0 ? '2%' : '4%')}.",
        isRisk: healthScore < 7.0,
      ),
    ];

    // Source references
    final sources = [
      const SourceReference(page: "Page 2", title: "Amortization & Schedule", note: "Interest recalculation details."),
      const SourceReference(page: "Page 4", title: "Prepayment Conditions", note: "Foreclosure penalties & waivers."),
      const SourceReference(page: "Page 8", title: "Rate Adjustments", note: "Base benchmarks, caps and indexes."),
      const SourceReference(page: "Page 14", title: "Administration Costs", note: "Quarterly processing schedule & layers."),
    ];

    // Cost Slices for pie chart
    final double totalSlicesVal = (principalVal + interestVal + hiddenVal).toDouble();
    final costSlices = [
      CostSlice(label: "Principal", value: principalVal.toDouble(), ratio: principalVal / totalSlicesVal, accent: const Color(0xFFC3C6D7)),
      CostSlice(label: "Interest", value: interestVal.toDouble(), ratio: interestVal / totalSlicesVal, accent: const Color(0xFF909096)),
      CostSlice(label: "Hidden Charges", value: hiddenVal.toDouble(), ratio: hiddenVal / totalSlicesVal, accent: const Color(0xFFFFB4AB)),
    ];

    // EMI points (Amortization curve mockup over 12 months for visualization)
    final double monthlyInst = totalRepaymentVal / 120; // assumed 10 year term monthly inst
    final List<EmiPoint> emiSeries = [];
    for (int m = 1; m <= 12; m++) {
      // Principal repayment increases, interest payment decreases over time
      final pRatio = 0.5 + (m * 0.02);
      final pAmount = monthlyInst * pRatio;
      final iAmount = monthlyInst * (1 - pRatio);
      emiSeries.add(EmiPoint(
        month: m,
        principal: double.parse(pAmount.toStringAsFixed(0)),
        interest: double.parse(iAmount.toStringAsFixed(0)),
      ));
    }

    // Clause chips
    final clauseChips = [
      ClauseChip(label: "Rate Reset Clause", accent: healthScore >= 8.0 ? const Color(0xFFC3C6D7) : const Color(0xFFFFB4AB)),
      ClauseChip(label: "Exit Penalty ${healthScore >= 8.0 ? '0%' : (healthScore >= 6.0 ? '2%' : '4%')}", accent: healthScore >= 7.0 ? const Color(0xFFC3C6D7) : const Color(0xFFFFB4AB)),
      ClauseChip(label: "Transparency $clarityPercent%", accent: const Color(0xFFC3C6D7)),
    ];

    // Extractions list
    final extractions = [
      LoanExtraction(label: "Lender Entity", value: lenderName),
      LoanExtraction(label: "Sanctioned Amount", value: formatRupee(principalVal)),
      LoanExtraction(label: "Contract Clarity", value: "$clarityPercent% Transparent"),
      LoanExtraction(label: "Recommended Move", value: recommendedAction),
    ];

    return LoanAnalysisReport(
      loanId: cleanLoanId,
      lenderName: lenderName,
      productName: healthScore >= 8.0 ? "Secure Home Prime" : (healthScore >= 6.0 ? "Flexi Term FinCo" : "Predatory Variable Term"),
      healthScore: double.parse(healthScore.toStringAsFixed(1)),
      healthSummary: healthSummary,
      detailedSummary: detailedSummary,
      simpleSummary: simpleSummary,
      recommendedAction: recommendedAction,
      contractClarity: "$clarityPercent% Transparent",
      metrics: metrics,
      alerts: alerts,
      sources: sources,
      costSlices: costSlices,
      emiSeries: emiSeries,
      clauseChips: clauseChips,
      extractions: extractions,
    );
  }
}

class MetricData {
  final String id;
  final String label;
  final String value;
  final String valueSuffix;
  final Color accent;
  final IconData icon;
  final String secondaryLabel;
  final String detailTitle;
  final String detailBody;
  final bool isRisk;

  const MetricData({
    required this.id,
    required this.label,
    required this.value,
    required this.valueSuffix,
    required this.accent,
    required this.icon,
    required this.secondaryLabel,
    required this.detailTitle,
    required this.detailBody,
    this.isRisk = false,
  });

  factory MetricData.fromJson(Map<String, dynamic> json) {
    final int codePoint = json['icon'] as int? ?? 0xe897;
    IconData resolvedIcon;
    if (codePoint == Icons.percent_rounded.codePoint) {
      resolvedIcon = Icons.percent_rounded;
    } else if (codePoint == Icons.payments_outlined.codePoint) {
      resolvedIcon = Icons.payments_outlined;
    } else if (codePoint == Icons.account_balance_wallet_outlined.codePoint) {
      resolvedIcon = Icons.account_balance_wallet_outlined;
    } else if (codePoint == Icons.warning_amber_rounded.codePoint) {
      resolvedIcon = Icons.warning_amber_rounded;
    } else {
      resolvedIcon = Icons.help_outline;
    }

    return MetricData(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      value: json['value']?.toString() ?? '',
      valueSuffix: json['valueSuffix']?.toString() ?? '',
      accent: Color(json['accent'] as int? ?? 0xFFC3C6D7),
      icon: resolvedIcon,
      secondaryLabel: json['secondaryLabel']?.toString() ?? '',
      detailTitle: json['detailTitle']?.toString() ?? '',
      detailBody: json['detailBody']?.toString() ?? '',
      isRisk: json['isRisk'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'value': value,
      'valueSuffix': valueSuffix,
      'accent': accent.toARGB32(),
      'icon': icon.codePoint,
      'secondaryLabel': secondaryLabel,
      'detailTitle': detailTitle,
      'detailBody': detailBody,
      'isRisk': isRisk,
    };
  }
}

class RiskAlertData {
  final String id;
  final String title;
  final String body;
  final String severity;
  final Color accent;
  final String page;
  final String clause;
  final String explanation;

  const RiskAlertData({
    required this.id,
    required this.title,
    required this.body,
    required this.severity,
    required this.accent,
    required this.page,
    required this.clause,
    required this.explanation,
  });

  factory RiskAlertData.fromJson(Map<String, dynamic> json) {
    return RiskAlertData(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      severity: json['severity']?.toString() ?? '',
      accent: Color(json['accent'] as int? ?? 0xFFFFB4AB),
      page: json['page']?.toString() ?? '',
      clause: json['clause']?.toString() ?? '',
      explanation: json['explanation']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'severity': severity,
      'accent': accent.toARGB32(),
      'page': page,
      'clause': clause,
      'explanation': explanation,
    };
  }
}

class SourceReference {
  final String page;
  final String title;
  final String note;

  const SourceReference({
    required this.page,
    required this.title,
    required this.note,
  });

  factory SourceReference.fromJson(Map<String, dynamic> json) {
    return SourceReference(
      page: json['page']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      note: json['note']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'page': page,
      'title': title,
      'note': note,
    };
  }
}

class CostSlice {
  final String label;
  final double value;
  final double ratio;
  final Color accent;

  const CostSlice({
    required this.label,
    required this.value,
    required this.ratio,
    required this.accent,
  });

  factory CostSlice.fromJson(Map<String, dynamic> json) {
    return CostSlice(
      label: json['label']?.toString() ?? '',
      value: (json['value'] as num?)?.toDouble() ?? 0.0,
      ratio: (json['ratio'] as num?)?.toDouble() ?? 0.0,
      accent: Color(json['accent'] as int? ?? 0xFFC3C6D7),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'value': value,
      'ratio': ratio,
      'accent': accent.toARGB32(),
    };
  }
}

class EmiPoint {
  final int month;
  final double principal;
  final double interest;

  const EmiPoint({
    required this.month,
    required this.principal,
    required this.interest,
  });

  factory EmiPoint.fromJson(Map<String, dynamic> json) {
    return EmiPoint(
      month: json['month'] as int? ?? 0,
      principal: (json['principal'] as num?)?.toDouble() ?? 0.0,
      interest: (json['interest'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'month': month,
      'principal': principal,
      'interest': interest,
    };
  }
}

class ClauseChip {
  final String label;
  final Color accent;

  const ClauseChip({
    required this.label,
    required this.accent,
  });

  factory ClauseChip.fromJson(Map<String, dynamic> json) {
    return ClauseChip(
      label: json['label']?.toString() ?? '',
      accent: Color(json['accent'] as int? ?? 0xFFC3C6D7),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'accent': accent.toARGB32(),
    };
  }
}

class LoanExtraction {
  final String label;
  final String value;

  const LoanExtraction({
    required this.label,
    required this.value,
  });

  factory LoanExtraction.fromJson(Map<String, dynamic> json) {
    return LoanExtraction(
      label: json['label']?.toString() ?? '',
      value: json['value']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'value': value,
    };
  }
}
