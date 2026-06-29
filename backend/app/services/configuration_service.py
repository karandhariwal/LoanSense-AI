"""
Scoring Configuration Management
Replaces hardcoded safety score thresholds and calculation parameters with environment-driven configuration
"""

import os
from dataclasses import dataclass
from typing import Optional


@dataclass
class SafetyScoreThresholds:
    """Configurable thresholds for loan safety score ratings"""
    
    # Rating thresholds - these determine which rating a score gets
    excellent_min: float = float(os.getenv("SAFETY_SCORE_EXCELLENT_MIN", 8.5))
    excellent_max: float = float(os.getenv("SAFETY_SCORE_EXCELLENT_MAX", 10.0))
    
    good_min: float = float(os.getenv("SAFETY_SCORE_GOOD_MIN", 7.0))
    good_max: float = float(os.getenv("SAFETY_SCORE_GOOD_MAX", 8.5))
    
    moderate_min: float = float(os.getenv("SAFETY_SCORE_MODERATE_MIN", 5.0))
    moderate_max: float = float(os.getenv("SAFETY_SCORE_MODERATE_MAX", 7.0))
    
    risky_min: float = float(os.getenv("SAFETY_SCORE_RISKY_MIN", 3.0))
    risky_max: float = float(os.getenv("SAFETY_SCORE_RISKY_MAX", 5.0))
    
    high_risk_max: float = float(os.getenv("SAFETY_SCORE_HIGH_RISK_MAX", 3.0))
    
    def get_rating(self, score: float) -> str:
        """Determine rating based on score"""
        if self.excellent_min <= score <= self.excellent_max:
            return "EXCELLENT"
        elif self.good_min <= score < self.good_max:
            return "GOOD"
        elif self.moderate_min <= score < self.moderate_max:
            return "MODERATE"
        elif self.risky_min <= score < self.risky_max:
            return "RISKY"
        else:
            return "HIGH_RISK"


@dataclass
class RiskPenaltyWeights:
    """Configurable deduction weights for risk factors"""
    
    # Risk deduction amounts - these reduce the base score
    high_risk_penalty: float = float(os.getenv("RISK_PENALTY_HIGH", "-1.5"))
    medium_risk_penalty: float = float(os.getenv("RISK_PENALTY_MEDIUM", "-0.75"))
    low_risk_penalty: float = float(os.getenv("RISK_PENALTY_LOW", "-0.25"))
    
    # Base score before deductions
    base_score: float = float(os.getenv("BASE_SAFETY_SCORE", "10.0"))
    
    # Minimum score floor (can't go lower)
    minimum_score: float = float(os.getenv("MINIMUM_SAFETY_SCORE", "0.0"))


@dataclass
class ProcessingConstants:
    """Configurable PDF processing and timeout settings"""
    
    # PDF processing limits (in characters)
    max_metadata_chars: int = int(os.getenv("MAX_METADATA_CHARS", "12000"))
    max_risk_chars: int = int(os.getenv("MAX_RISK_CHARS", "16000"))
    
    # Chunk settings for document processing
    chunk_size: int = int(os.getenv("CHUNK_SIZE", "1000"))
    chunk_overlap: int = int(os.getenv("CHUNK_OVERLAP", "200"))
    
    # Timeout settings (in seconds)
    extraction_timeout: float = float(os.getenv("EXTRACTION_TIMEOUT", "120.0"))
    comparison_timeout: float = float(os.getenv("COMPARISON_TIMEOUT", "30.0"))
    safety_score_timeout: float = float(os.getenv("SAFETY_SCORE_TIMEOUT", "60.0"))


class ConfigurationService:
    """Centralized configuration management service"""
    
    _instance: Optional['ConfigurationService'] = None
    _safety_thresholds: Optional[SafetyScoreThresholds] = None
    _risk_weights: Optional[RiskPenaltyWeights] = None
    _processing_constants: Optional[ProcessingConstants] = None
    
    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
            cls._instance._initialize()
        return cls._instance
    
    def _initialize(self):
        """Initialize all configuration components from environment"""
        self._safety_thresholds = SafetyScoreThresholds()
        self._risk_weights = RiskPenaltyWeights()
        self._processing_constants = ProcessingConstants()
        print("Configuration Service initialized with environment variables")
    
    @property
    def safety_thresholds(self) -> SafetyScoreThresholds:
        """Get safety score threshold configuration"""
        return self._safety_thresholds or SafetyScoreThresholds()
    
    @property
    def risk_weights(self) -> RiskPenaltyWeights:
        """Get risk penalty weight configuration"""
        return self._risk_weights or RiskPenaltyWeights()
    
    @property
    def processing_constants(self) -> ProcessingConstants:
        """Get processing constants configuration"""
        return self._processing_constants or ProcessingConstants()
    
    def reload(self):
        """Reload configuration from environment - useful for development"""
        self._initialize()


# Global configuration service instance
config_service = ConfigurationService()
