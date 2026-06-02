import 'dart:math';

import 'package:flutter/material.dart';
import 'package:loansense_ai/data/models/loan_analysis_report.dart';
import 'package:loansense_ai/data/models/loan_assistant_models.dart';

abstract class LoanAssistantRepository {
  LoanAssistantConversationSeed bootstrap(LoanAnalysisReport report);

  Future<LoanAssistantReply> reply({
    required LoanAssistantConversationContext context,
    required String query,
  });
}

class MockLoanAssistantRepository implements LoanAssistantRepository {
  @override
  LoanAssistantConversationSeed bootstrap(LoanAnalysisReport report) {
    final initialReply = _buildResponse(
      context: LoanAssistantConversationContext(report: report, history: const []),
      query: 'Can I close this loan early?',
    );

    return LoanAssistantConversationSeed(
      messages: [
        LoanAssistantMessage(
          id: _id('user'),
          role: LoanAssistantRole.user,
          content: 'Can I close this loan early?',
          timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
          state: LoanAssistantMessageState.complete,
          isFresh: false,
        ),
        initialReply.assistantMessage.copyWith(
          id: _id('assistant'),
          timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
          isFresh: false,
        ),
      ],
      suggestions: initialReply.suggestions,
      documentLabel: _documentLabel(report),
      pageLabel: _pageLabel(report),
      contextLabel: _contextLabel(initialReply.contextLabel, report),
    );
  }

  @override
  Future<LoanAssistantReply> reply({
    required LoanAssistantConversationContext context,
    required String query,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 1150));
    return _buildResponse(context: context, query: query);
  }

  LoanAssistantReply _buildResponse({
    required LoanAssistantConversationContext context,
    required String query,
  }) {
    final lower = query.toLowerCase();
    final report = context.report;
    RiskAlertData? targetedAlert;
    if (context.targetClauseId != null) {
      for (final candidate in report.alerts) {
        if (candidate.id == context.targetClauseId) {
          targetedAlert = candidate;
          break;
        }
      }
    }
    final alert = targetedAlert ?? _pickAlert(report, lower);
    final simpleSummary = _simpleSummary(report, alert, lower);
    final isForeclosureQuery = _containsAny(lower, [
      'close early',
      'foreclosure',
      'prepay',
      'pre-payment',
      'prepayment',
      'refinance',
    ]);
    final isFeeQuery = _containsAny(lower, [
      'hidden fee',
      'hidden charges',
      'fees',
      'penalty',
      'charge',
    ]);
    final isRateQuery = _containsAny(lower, [
      'emi',
      'interest',
      'rate',
      'reset',
    ]);
    final isTaxQuery = _containsAny(lower, ['tax', 'benefit', 'section 80c']);
    final isInsuranceQuery = _containsAny(lower, ['insurance', 'cover', 'beneficiary']);
    final isSimpleQuery = _containsAny(lower, ['simpler', 'simple', 'plain english', 'plain language']);

    final answer = isForeclosureQuery
        ? _foreclosureAnswer(report, alert)
        : isFeeQuery
            ? _feeAnswer(report, alert)
            : isRateQuery
                ? _rateAnswer(report, alert)
                : isInsuranceQuery
                    ? _insuranceAnswer(report, alert)
                    : isTaxQuery
                        ? _taxAnswer(report)
                        : _generalAnswer(report, alert, query);

    final card = LoanAssistantCardData(
      engineLabel: 'PROCESSING ENGINE 2.4B',
      answerLabel: 'Answer',
      answer: answer,
      simplifiedAnswer: isSimpleQuery
          ? simpleSummary
          : _simplifyForResponse(answer, report, alert),
      sourceClause: alert?.clause ?? _sourceClause(report),
      pageReference: _pageLabel(report),
      riskContext: _riskContext(report, alert, lower),
      highlightTerms: _highlightTerms(answer, report, alert, lower),
      insightChips: _insightChips(report, alert, lower),
      references: _references(report, alert),
    );

    final assistantMessage = LoanAssistantMessage(
      id: _id('assistant'),
      role: LoanAssistantRole.assistant,
      content: answer,
      timestamp: DateTime.now(),
      state: LoanAssistantMessageState.complete,
      card: card,
      showSimpleAnswer: isSimpleQuery,
      isFresh: true,
    );

    return LoanAssistantReply(
      assistantMessage: assistantMessage,
      suggestions: _followUpSuggestions(report, alert, lower),
      contextLabel: alert?.title ?? report.recommendedAction,
    );
  }

  LoanAssistantSuggestion _suggestion(String label, String prompt, Color accent) {
    return LoanAssistantSuggestion(label: label, prompt: prompt, accent: accent);
  }

  List<LoanAssistantSuggestion> _followUpSuggestions(
    LoanAnalysisReport report,
    RiskAlertData? alert,
    String query,
  ) {
    const tertiary = Color(0xFFDBC3A8);
    const primary = Color(0xFFC3C6D7);
    const error = Color(0xFFFFB4AB);

    if (_containsAny(query, ['foreclosure', 'close early', 'prepayment', 'refinance'])) {
      return [
        _suggestion('What are the hidden fees?', 'What hidden fees should I check in this agreement?', tertiary),
        _suggestion('Late EMI penalties?', 'What happens if I miss an EMI?', error),
        _suggestion('Tax benefits section?', 'Where are the tax benefits mentioned in the loan?', primary),
      ];
    }

    if (_containsAny(query, ['fee', 'charge', 'penalty'])) {
      return [
        _suggestion('Explain simply', 'Can you explain this in simpler words?', primary),
        _suggestion('Can I negotiate?', 'Which fee can be negotiated first?', tertiary),
        _suggestion('Show source clause', 'Show me the exact clause and page reference.', error),
      ];
    }

    if (_containsAny(query, ['interest', 'rate', 'emi'])) {
      return [
        _suggestion('Forecast EMI impact', 'How does this affect my EMI over 12 months?', primary),
        _suggestion('Rate reset risk?', 'How risky is the rate reset clause?', error),
        _suggestion('Explain simply', 'Explain this rate clause in plain English.', tertiary),
      ];
    }

    return [
      _suggestion('Loan closure', 'Can I close this loan early?', primary),
      _suggestion('Penalty context', 'What risk does the penalty clause create?', tertiary),
      _suggestion('Source trace', 'Show the source clause and page reference.', error),
    ];
  }

  List<LoanAssistantInsightChip> _insightChips(
    LoanAnalysisReport report,
    RiskAlertData? alert,
    String query,
  ) {
    final chips = <LoanAssistantInsightChip>[];

    if (_containsAny(query, ['foreclosure', 'close early', 'prepayment'])) {
      chips.add(const LoanAssistantInsightChip(
        label: 'Optimized Path Found',
        accent: Color(0xFFC3C6D7),
        icon: Icons.bolt_rounded,
      ));
      chips.add(const LoanAssistantInsightChip(
        label: 'Penalty Advisory',
        accent: Color(0xFFDBC3A8),
      ));
    }

    if (alert != null && alert.severity.toLowerCase() != 'verified') {
      chips.add(LoanAssistantInsightChip(
        label: '${alert.severity.toUpperCase()} RISK',
        accent: alert.accent,
        icon: Icons.warning_amber_rounded,
      ));
    }

    chips.add(LoanAssistantInsightChip(
      label: report.contractClarity,
      accent: const Color(0xFFC3C6D7),
      icon: Icons.security_rounded,
    ));

    return chips.take(3).toList();
  }

  List<LoanAssistantReference> _references(
    LoanAnalysisReport report,
    RiskAlertData? alert,
  ) {
    final refs = <LoanAssistantReference>[
      LoanAssistantReference(
        label: 'Source Clause',
        value: alert?.clause ?? _sourceClause(report),
        accent: const Color(0xFFC3C6D7),
        icon: Icons.description_outlined,
      ),
      LoanAssistantReference(
        label: 'Page Reference',
        value: '${_documentLabel(report)} - ${alert?.page ?? _pageLabel(report)}',
        accent: const Color(0xFFC3C6D7),
        icon: Icons.article_outlined,
      ),
    ];

    if (report.sources.isNotEmpty) {
      refs.add(
        LoanAssistantReference(
          label: 'Document Source',
          value: report.sources.first.title,
          accent: const Color(0xFFDBC3A8),
          icon: Icons.folder_copy_outlined,
        ),
      );
    }

    return refs;
  }

  String _foreclosureAnswer(LoanAnalysisReport report, RiskAlertData? alert) {
    final penalty = _extractPenalty(report, alert);
    final wait = _waitPeriod(report, alert);

    return 'Yes, you can initiate full foreclosure after $wait successful EMIs. However, a $penalty penalty applies to the outstanding principal if you close within the first 24 months. The clause is structured to keep early exits expensive, so timing the closure after the penalty window materially improves your cost profile.';
  }

  String _feeAnswer(LoanAnalysisReport report, RiskAlertData? alert) {
    final clause = alert?.clause ?? _sourceClause(report);
    return 'I found the fee structure in $clause. The agreement layers processing, prepayment, and administrative charges in a way that raises your effective cost if you move early. The key risk is not the visible EMI, but the stacked exit cost hidden in the clause wording.';
  }

  String _rateAnswer(LoanAnalysisReport report, RiskAlertData? alert) {
    final rate = report.metrics.isNotEmpty ? report.metrics.first.value : 'a variable rate';
    return 'Your interest profile is tied to $rate and can move with the lender benchmark. That means the EMI may drift even if your principal stays unchanged. If you are budgeting tightly, the reset clause is the part to monitor first.';
  }

  String _insuranceAnswer(LoanAnalysisReport report, RiskAlertData? alert) {
    return 'This is a standard protective clause, not a hidden trap. It typically requires insurance coverage or beneficiary alignment so the lender can recover the balance if a major event occurs. The cost impact is usually indirect, through the premium you pay to keep the policy active.';
  }

  String _taxAnswer(LoanAnalysisReport report) {
    return 'Tax treatment usually sits outside the loan clauses themselves, but your agreement can still reference deduction-eligible interest sections. I would review the tax appendix and sanction letter together, because the benefit often depends on loan purpose, tenure, and occupancy type.';
  }

  String _generalAnswer(LoanAnalysisReport report, RiskAlertData? alert, String query) {
    final topic = alert?.title ?? report.healthSummary;
    return 'I reviewed the latest context around $topic. The agreement is actionable, but the language around penalties, resets, or administrative charges should be read carefully before you commit. Ask me for the source clause if you want the exact line by line interpretation.';
  }

  String _simplifyForResponse(String answer, LoanAnalysisReport report, RiskAlertData? alert) {
    if (alert != null && alert.title.toLowerCase().contains('foreclosure')) {
      return 'If you pay off the loan early, the bank allows it after a minimum period, but you will still pay a penalty if you close it too soon. Waiting longer reduces that penalty.';
    }
    if (alert != null && alert.severity.toLowerCase() == 'high') {
      return 'This clause is risky. It can make the loan more expensive if you try to exit early or if the bank changes the terms later.';
    }
    return report.simpleSummary.isNotEmpty
        ? report.simpleSummary
        : 'This part explains the fee or rule in simpler words so you can see the actual cost impact quickly.';
  }

  String _simpleSummary(
    LoanAnalysisReport report,
    RiskAlertData? alert,
    String query,
  ) {
    if (_containsAny(query, ['foreclosure', 'close early', 'prepayment'])) {
      return 'You can usually close the loan early after the minimum EMI period, but closing too soon triggers a penalty fee.';
    }
    return report.simpleSummary.isNotEmpty
        ? report.simpleSummary
        : 'The clause is probably okay, but I need the exact section to explain the risk more precisely.';
  }

  List<String> _highlightTerms(
    String answer,
    LoanAnalysisReport report,
    RiskAlertData? alert,
    String query,
  ) {
    final terms = <String>[
      'foreclosure',
      'penalty',
      'prepayment',
      'EMI',
      'interest rate',
      'variable',
      'reset',
    ];

    if (alert != null) {
      terms.addAll([
        alert.title,
        alert.clause,
      ]);
    }

    if (_containsAny(query, ['tax'])) {
      terms.add('tax');
    }

    return terms.where((term) => answer.toLowerCase().contains(term.toLowerCase())).toSet().toList();
  }

  String _riskContext(LoanAnalysisReport report, RiskAlertData? alert, String query) {
    if (_containsAny(query, ['foreclosure', 'close early', 'prepayment'])) {
      return 'Foreclosing before the penalty window can create a real cash loss. Waiting a little longer usually improves the outcome more than negotiating a rushed exit.';
    }

    if (alert != null && alert.severity.toLowerCase() != 'verified') {
      return '${alert.title} is not a cosmetic issue. It can change your total repayment or limit your refinancing flexibility.';
    }

    return report.healthSummary;
  }

  RiskAlertData? _pickAlert(LoanAnalysisReport report, String query) {
    if (report.alerts.isEmpty) return null;

    for (final alert in report.alerts) {
      final haystack = [
        alert.title,
        alert.body,
        alert.clause,
        alert.page,
        alert.severity,
      ].join(' ').toLowerCase();

      if (_containsAny(query, [
        'foreclosure',
        'close early',
        'prepay',
        'pre-payment',
      ]) && haystack.contains('pre')) {
        return alert;
      }

      if (_containsAny(query, ['fee', 'charge', 'penalty']) &&
          haystack.contains('fee')) {
        return alert;
      }

      if (_containsAny(query, ['interest', 'rate', 'emi']) &&
          haystack.contains('rate')) {
        return alert;
      }
    }

    return report.alerts.first;
  }

  String _waitPeriod(LoanAnalysisReport report, RiskAlertData? alert) {
    final text = '${alert?.body ?? report.detailedSummary} ${report.simpleSummary}'.toLowerCase();
    final match = RegExp(r'after\s+(\d+)\s+successful\s+emis?').firstMatch(text);
    if (match != null) {
      return match.group(1)!;
    }
    return '12';
  }

  String _extractPenalty(LoanAnalysisReport report, RiskAlertData? alert) {
    final text = '${alert?.body ?? report.detailedSummary} ${report.simpleSummary}';
    final match = RegExp(r'(\d+(?:\.\d+)?)%').firstMatch(text);
    if (match != null) {
      return '${match.group(1)}%';
    }
    return '2.5%';
  }

  String _sourceClause(LoanAnalysisReport report) {
    if (report.alerts.isNotEmpty) {
      return report.alerts.first.clause;
    }
    return 'Pre-payment & Foreclosure Terms (Article 4.2)';
  }

  String _pageLabel(LoanAnalysisReport report) {
    if (report.alerts.isNotEmpty) {
      return report.alerts.first.page;
    }
    if (report.sources.isNotEmpty) {
      return report.sources.first.page;
    }
    return 'Page 14';
  }

  String _documentLabel(LoanAnalysisReport report) {
    if (report.sources.isNotEmpty) {
      return '${report.lenderName}.pdf';
    }
    return 'Agreement_V2.pdf';
  }

  String _contextLabel(String contextLabel, LoanAnalysisReport report) {
    if (contextLabel.isNotEmpty) {
      return contextLabel;
    }
    return report.recommendedAction;
  }

  bool _containsAny(String value, List<String> needles) {
    return needles.any((needle) => value.contains(needle));
  }

  String _id(String prefix) {
    final now = DateTime.now().microsecondsSinceEpoch;
    return '$prefix-$now-${Random().nextInt(1 << 20)}';
  }
}
