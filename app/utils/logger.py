"""
Logging Configuration
"""

import logging
import sys
from pythonjsonlogger import jsonlogger


def setup_logger(name: str) -> logging.Logger:
    """
    Set up a logger with JSON formatting

    Args:
        name: Logger name (usually __name__)

    Returns:
        Configured logger instance
    """
    logger = logging.getLogger(name)

    # Only add handler if logger doesn't have one
    if not logger.handlers:
        handler = logging.StreamHandler(sys.stdout)

        # JSON formatter for structured logging
        formatter = jsonlogger.JsonFormatter(
            '%(asctime)s %(name)s %(levelname)s %(message)s',
            timestamp=True
        )

        handler.setFormatter(formatter)
        logger.addHandler(handler)

    # Set log level from environment or default to INFO
    import os
    log_level = os.getenv('LOG_LEVEL', 'INFO').upper()
    logger.setLevel(getattr(logging, log_level, logging.INFO))

    return logger
