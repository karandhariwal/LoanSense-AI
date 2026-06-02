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

@immutable
class LoanComparisonReport {
  final LoanDocumentSummary loanA;
  final LoanDocumentSummary loanB;
  final List<LoanComparisonMetric> metrics;
  final LoanComparisonRecommendation recommendation;
  final LoanComparisonVerdict verdict;
  final List<EmiComparisonPoint> emiSeries;

  const LoanComparisonReport({
    required this.loanA,
    required this.loanB,
    required this.metrics,
    required this.recommendation,
    required this.verdict,
    required this.emiSeries,
  });

  factory LoanComparisonReport.fromJson(Map<String, dynamic> json) {
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

