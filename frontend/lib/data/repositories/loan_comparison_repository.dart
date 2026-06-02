import 'dart:async';
import 'dart:io';
import 'package:loansense_ai/data/models/loan_comparison_report.dart';
import 'package:loansense_ai/data/repositories/loan_repository.dart';

class LoanComparisonRepository {
  final LoanRepository _loanRepository;

  LoanComparisonRepository({LoanRepository? loanRepository})
      : _loanRepository = loanRepository ?? LoanRepository();

  Future<LoanComparisonReport> compare({
    required LoanDocumentSummary loanA,
    required LoanDocumentSummary loanB,
  }) async {
    return _loanRepository.compareLoans(loanA.id, loanB.id);
  }

  Future<Map<String, dynamic>> uploadLoan(File file) {
    return _loanRepository.uploadLoan(file);
  }
}
