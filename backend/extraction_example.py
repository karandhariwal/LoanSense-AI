"""
Example implementation showing how to integrate the modular prompt templates with
LangChain, ChatNVIDIA, and Pydantic validation.
"""

import sys
import os
from typing import List, Dict, Any
from decimal import Decimal
from pydantic import BaseModel, Field

# Ensure backend directory is in the path to import app modules
# (assuming running from backend root or using standard PYTHONPATH)
backend_path = os.path.dirname(os.path.abspath(__file__))
if backend_path not in sys.path:
    sys.path.insert(0, backend_path)

from langchain_nvidia_ai_endpoints import ChatNVIDIA
from langchain_core.output_parsers import StrOutputParser
from langchain_core.runnables import RunnablePassthrough

from app.models.loan_metadata import LoanMetadata
from app.models.risk_clause import RiskClause
from app.models.loan_score import LoanSafetyScore, SafetyRating
from app.services.ai.prompt_templates import (
    LOAN_METADATA_EXTRACTION_PROMPT,
    RISK_CLAUSE_DETECTION_PROMPT,
    LOAN_SUMMARY_PROMPT,
    LOAN_SAFETY_SCORE_PROMPT
)

def run_extraction_pipeline(document_text: str, api_key: str, model_name: str = "meta/llama-3.1-70b-instruct"):
    """
    Executes the 4-stage modular extraction and analysis pipeline.
    """
    
    # 1. Initialize the NVIDIA NIM LLM
    print("--- Initializing ChatNVIDIA ---")
    llm = ChatNVIDIA(
        model=model_name,
        nvidia_api_key=api_key,
        temperature=0.0
    )
    
    # 2. Stage 1: Extract Loan Metadata using structured output
    print("\n--- Stage 1: Extracting Loan Metadata ---")
    metadata_llm = llm.with_structured_output(LoanMetadata)
    metadata_chain = LOAN_METADATA_EXTRACTION_PROMPT | metadata_llm
    
    # Run metadata extraction
    try:
        extracted_metadata = metadata_chain.invoke({"document_context": document_text})
        print(f"Extracted Metadata (Success):")
        print(f"  Lender: {extracted_metadata.lender_name}")
        print(f"  Loan Type: {extracted_metadata.loan_type}")
        print(f"  Principal: {extracted_metadata.principal_amount}")
        print(f"  Interest Rate: {extracted_metadata.interest_rate}% ({extracted_metadata.interest_type})")
        print(f"  EMI: {extracted_metadata.emi_amount}")
    except Exception as e:
        print(f"Error extracting metadata: {e}")
        extracted_metadata = None

    # 3. Stage 2: Detect Risk Clauses
    print("\n--- Stage 2: Detecting Risk Clauses ---")
    
    # We define a list-wrapped schema since with_structured_output expects a single Pydantic class
    class RiskClauseList(BaseModel):
        risks: List[RiskClause] = Field(description="List of detected risk clauses.")

    risk_llm = llm.with_structured_output(RiskClauseList)
    risk_chain = RISK_CLAUSE_DETECTION_PROMPT | risk_llm
    
    try:
        risk_result = risk_chain.invoke({"document_context": document_text})
        detected_risks = risk_result.risks
        print(f"Detected {len(detected_risks)} risk clauses:")
        for idx, risk in enumerate(detected_risks, 1):
            print(f"  [{idx}] {risk.category} - {risk.clause_title} ({risk.risk_level})")
            print(f"      Text: \"{risk.clause_text[:60]}...\"")
    except Exception as e:
        print(f"Error detecting risks: {e}")
        detected_risks = []

    # 4. Stage 3: Generate Loan Summary
    print("\n--- Stage 3: Generating Consumer-Friendly Summary ---")
    
    # Convert extracted items to strings for prompt insertion
    metadata_str = str(extracted_metadata.model_dump()) if extracted_metadata else "Not available"
    risks_str = str([r.model_dump() for r in detected_risks]) if detected_risks else "None detected"
    
    summary_chain = LOAN_SUMMARY_PROMPT | llm | StrOutputParser()
    
    try:
        summary_text = summary_chain.invoke({
            "document_context": document_text,
            "extracted_metadata": metadata_str,
            "detected_risks": risks_str
        })
        print("Generated Summary:")
        print(summary_text)
    except Exception as e:
        print(f"Error generating summary: {e}")
        summary_text = ""

    # 5. Stage 4: Generate Safety Score
    print("\n--- Stage 4: Generating Safety Score ---")
    score_llm = llm.with_structured_output(LoanSafetyScore)
    score_chain = LOAN_SAFETY_SCORE_PROMPT | score_llm
    
    try:
        safety_score = score_chain.invoke({
            "document_context": document_text,
            "extracted_metadata": metadata_str,
            "detected_risks": risks_str
        })
        print(f"Generated Safety Score (Success):")
        print(f"  Score: {safety_score.score}/10")
        print(f"  Rating: {safety_score.rating.value}")
        print(f"  Strengths: {safety_score.strengths}")
        print(f"  Weaknesses: {safety_score.weaknesses}")
        print(f"  Explanation: {safety_score.explanation}")
    except Exception as e:
        print(f"Error generating safety score: {e}")
        safety_score = None
        
    return {
        "metadata": extracted_metadata,
        "risks": detected_risks,
        "summary": summary_text,
        "safety_score": safety_score
    }

if __name__ == "__main__":
    # Sample mock loan text for testing
    sample_agreement = """
    LOAN AGREEMENT
    This Loan Agreement is entered into on 1st June 2026 by and between APEX FINANCE CORP (hereinafter called 'the Lender') and John Doe (hereinafter called 'the Borrower').
    
    1. LOAN AMOUNT & SANCTION
    The Lender agrees to sanction a Home Loan of Rs. 50,00,000/- (Rupees Fifty Lakhs only) to the Borrower, with the principal amount being disbursed to the borrower net of processing fees.
    
    2. DISBURSAL AMOUNT
    The net disbursal amount shall be Rs. 49,72,500/- after deducting processing fees.
    
    3. INTEREST RATE
    The loan shall bear interest at an annual interest rate of 8.75% per annum. The interest rate is floating and linked to the Lender's Prime Lending Rate (PLR) which may be altered unilaterally by the Lender at any time without notice.
    
    4. REPAYMENT & TENURE
    The tenure of the loan shall be 240 months. Repayment frequency is monthly. Equated Monthly Installment (EMI) shall be Rs. 44,186/- starting on 1st June 2026. The maturity date is 1st June 2046.
    
    5. FEES AND PENALTIES
    - Processing Fee: A processing fee of Rs. 10,000/- is applicable.
    - Documentation charges: Rs. 2,500/-.
    - Insurance fee: Rs. 15,000/-.
    - Prepayment Fee: 1.5% fee if borrower repays principal early.
    - Late Payment Fee: A late fee of 24.0% per annum shall be charged on all overdue amounts.
    - Cheque/ECS bounce charges: A flat charge of Rs. 500/- per instance.
    
    6. LENDER DISCRETION & JURISDICTION
    The Lender reserves the absolute right to demand immediate repayment of the entire outstanding balance at any time by giving 7 days written notice. All disputes shall be subject to the exclusive jurisdiction of courts in Mumbai.
    """
    
    import os
    from app.core.config import settings
    
    api_key = settings.NVIDIA_API_KEY or os.getenv("NVIDIA_API_KEY")
    if not api_key or api_key == "mock_key":
        print("WARNING: NVIDIA_API_KEY is not configured in .env or environment.")
        print("Run extraction_example.py directly inside the application backend environment with a real key to test.")
    else:
        model_name = settings.NVIDIA_LLM_MODEL or "meta/llama-3.1-70b-instruct"
        print(f"NVIDIA_API_KEY found. Running extraction pipeline using model: {model_name}...")
        run_extraction_pipeline(sample_agreement, api_key, model_name=model_name)


