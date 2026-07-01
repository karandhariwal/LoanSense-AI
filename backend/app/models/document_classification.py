from pydantic import BaseModel, Field

class DocumentClassification(BaseModel):
    """
    Schema for document type classification.
    Used to distinguish valid loan/financial documents from unrelated documents (e.g. resumes, cover letters).
    """
    is_valid_financial_document: bool = Field(
        ...,
        description="True if the document is a valid financial or loan-related document (e.g., loan agreement, bank statement, mortgage contract, credit terms, sanction letter). False otherwise."
    )
    document_type: str = Field(
        ...,
        description="The classified type of the document (e.g., 'loan_agreement', 'bank_statement', 'resume', 'cover_letter', 'unrelated')."
    )
    confidence: float = Field(
        ...,
        description="Confidence score of the classification, ranging from 0.0 to 1.0."
    )
    reason: str = Field(
        ...,
        description="Short reasoning explaining why the document was classified this way."
    )
