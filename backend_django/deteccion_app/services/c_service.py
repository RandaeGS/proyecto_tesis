import os
import base64
import io
import logging
import requests
from PIL import Image
from typing import Dict, Any, Optional

from django.conf import settings
from .model_service import ModelService

logger = logging.getLogger(__name__)


class ClaudeService(ModelService):
    """
    Implementación del servicio para la API de Claude
    """

    def __init__(self, api_key: Optional[str] = None, api_url: Optional[str] = None):
        """
        Inicializa el servicio de Claude

        Args:
            api_key: Clave de API de Claude. Si es None, se usará la clave de las configuraciones.
            api_url: URL base de la API de Claude. Si es None, se usará la URL por defecto.
        """
        self.api_key = api_key or getattr(settings, 'CLAUDE_API_KEY', '')
        self.api_url = api_url or getattr(settings, 'CLAUDE_API_URL', 'https://api.anthropic.com/v1/messages')
        self.model = None  # No hay modelo para cargar, pero mantenemos la misma interfaz

        if not self.api_key:
            logger.warning("No se ha configurado la clave de API de Claude.")

    def load_model(self) -> None:
        """
        No hay modelo para cargar en este caso, pero implementamos el método para
        mantener la consistencia con la interfaz
        """
        logger.info("No se requiere cargar un modelo para el servicio de Claude.")
        pass

    def process_image(self, image: Image.Image) -> Dict[str, Any]:
        """
        Envía una imagen a la API de Claude para su análisis

        Args:
            image: Imagen a procesar en formato PIL

        Returns:
            Diccionario con los resultados de la detección
        """
        if not self.api_key:
            raise ValueError("Se requiere una clave de API para usar el servicio de Claude.")

        # Convertir la imagen a base64
        buffered = io.BytesIO()
        image.save(buffered, format="JPEG")
        img_str = base64.b64encode(buffered.getvalue()).decode('utf-8')

        # Preparar la solicitud
        headers = {
            "x-api-key": self.api_key,
            "anthropic-version": "2023-06-01",
            "content-type": "application/json"
        }

        payload = {
            "model": "claude-3-opus-20240229",  # Ajusta según el modelo de Claude que quieras usar
            "max_tokens": 1000,
            "messages": [
                {
                    "role": "user",
                    "content": [
                        {
                            "type": "text",
                            "text": "Detecta y describe todos los objetos en esta imagen. Proporciona sus coordenadas aproximadas (x1, y1, x2, y2), la clase del objeto y tu nivel de confianza."
                        },
                        {
                            "type": "image",
                            "source": {
                                "type": "base64",
                                "media_type": "image/jpeg",
                                "data": img_str
                            }
                        }
                    ]
                }
            ]
        }

        try:
            # Enviar la solicitud
            response = requests.post(self.api_url, headers=headers, json=payload)
            response.raise_for_status()

            # Procesar la respuesta
            result = response.json()

            # Extraer la respuesta de Claude
            claude_text = result.get('content', [{}])[0].get('text', '')

            # Aquí tendrías que parsear el texto de Claude para extraer las detecciones
            # Este es un ejemplo simple, necesitarías una lógica más robusta para parsear la respuesta
            detections = self._parse_claude_response(claude_text)

            return {
                'detections': detections,
                'count': len(detections),
                'model_type': 'claude',
                'raw_response': claude_text
            }

        except Exception as e:
            logger.error(f"Error al procesar la imagen con Claude: {str(e)}")
            raise

    def _parse_claude_response(self, response_text: str) -> list:
        """
        Parsea la respuesta de texto de Claude para extraer las detecciones

        Args:
            response_text: Texto de respuesta de la API de Claude

        Returns:
            Lista de detecciones
        """
        # Esta es una implementación muy básica. En la práctica, necesitarías usar NLP
        # o regex más sofisticados para extraer esta información.
        detections = []

        # Ejemplo simple: busca líneas que contengan coordenadas
        import re

        # Busca patrones como "x1: 100, y1: 200, x2: 300, y2: 400" o similares
        pattern = r'(?:coordenadas|coordinates)?.*?(\d+).*?(\d+).*?(\d+).*?(\d+).*?(confianza|confidence).*?(\d+(?:\.\d+)?)'
        matches = re.finditer(pattern, response_text, re.IGNORECASE)

        for match in matches:
            try:
                x1, y1, x2, y2 = map(int, match.groups()[:4])
                confidence = float(match.group(6))

                # Intenta encontrar la clase del objeto
                class_match = re.search(r'(object|clase|class|objeto).*?(\w+)',
                                        response_text[match.start():match.start() + 200], re.IGNORECASE)
                object_class = class_match.group(2) if class_match else "desconocido"

                detections.append({
                    'class': object_class,
                    'confidence': confidence,
                    'bbox': {
                        'x1': x1,
                        'y1': y1,
                        'x2': x2,
                        'y2': y2,
                    }
                })
            except Exception as e:
                logger.warning(f"Error al parsear una detección: {str(e)}")

        return detections

    def get_model_info(self) -> Dict[str, Any]:
        """
        Devuelve información sobre el servicio de Claude

        Returns:
            Diccionario con información sobre el servicio
        """
        return {
            'type': 'Claude API',
            'api_url': self.api_url,
            'has_api_key': bool(self.api_key)
        }
