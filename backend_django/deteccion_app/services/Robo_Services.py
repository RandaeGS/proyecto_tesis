# services/Robo_Services.py
import io
import os
import tempfile
import time
from typing import Dict, Any
from PIL import Image
from inference_sdk import InferenceHTTPClient
from .model_service import ModelService
import logging

logger = logging.getLogger(__name__)


class RoboflowService(ModelService):
    """
    Servicio para RF-DETR usando la inference_sdk de Roboflow.
    """
    def __init__(self):
        self.client = InferenceHTTPClient(
            api_url="https://serverless.roboflow.com",
            api_key="Nh09oS7de2WO80DMVv7g"
        )
        self.workspace = "friasluna-ovd8y"
        self.workflow = "detect-count-and-visualize"

    def load_model(self):
        # No hace nada; la SDK es serverless
        pass

    def process_image(self, img: Image.Image) -> Dict[str, Any]:
        try:
            # Debug: información de la imagen recibida
            logger.info(f"RF-DETR: Procesando imagen {img.size}, modo: {img.mode}")

            # Guardar imagen para debug (temporal)
            debug_path = f"/tmp/debug_roboflow_{int(time.time())}.png"
            img.save(debug_path)
            logger.info(f"RF-DETR: Imagen guardada para debug en {debug_path}")

            # Pasar directamente el objeto PIL Image
            result = self.client.run_workflow(
                workspace_name=self.workspace,
                workflow_id=self.workflow,
                images={"image": img},
                use_cache=True
            )

            first = result[0]

            # Debug: información del resultado
            count = first.get("count_objects", 0)
            predictions = first.get("predictions", [])
            logger.info(f"RF-DETR: Resultado crudo - count: {count}, predictions: {len(predictions)}")

            # Convertir el formato de Roboflow al formato esperado por tu view
            detections = []

            if 'predictions' in predictions and len(predictions['predictions']) > 0:
                for pred in predictions['predictions']:
                    detection = {
                        'class': pred.get('class', 'unknown'),
                        'confidence': pred.get('confidence', 0.0),
                        'bbox': [
                            pred.get('x', 0) - pred.get('width', 0) / 2,  # x1
                            pred.get('y', 0) - pred.get('height', 0) / 2,  # y1
                            pred.get('x', 0) + pred.get('width', 0) / 2,  # x2
                            pred.get('y', 0) + pred.get('height', 0) / 2   # y2
                        ],
                        'detection_id': pred.get('detection_id', ''),
                        'class_id': pred.get('class_id', 0)
                    }
                    detections.append(detection)

            logger.info(f"RF-DETR: Detecciones convertidas: {len(detections)}")

            # Devolver en el formato esperado por tu view
            return {
                "detections": detections,  # ← Esto es lo que busca tu view
                "count_objects": count,
                "predictions": predictions,
                "visualization": first.get("visualization"),
                # Datos adicionales para compatibilidad
                "model_info": {
                    "type": "RF-DETR",
                    "workspace": self.workspace,
                    "workflow": self.workflow
                }
            }

        except Exception as e:
            logger.error(f"RF-DETR: Error procesando imagen: {str(e)}")
            # Devolver estructura vacía pero consistente
            return {
                "detections": [],
                "count_objects": 0,
                "predictions": [],
                "visualization": None,
                "error": str(e)
            }

    def get_model_info(self) -> Dict[str, Any]:
        """
        Devuelve información sobre el servicio RF-DETR de Roboflow,
        con formato similar a YOLO y Claude para mantener consistencia.
        """
        return {
            'type': 'RF-DETR',
            'path': "Roboflow Cloud",
            'device': 'cloud',
            'classes': ['canned-individual'],  # Basado en tu ejemplo que funciona
            'model': self.workflow,
            'workspace': self.workspace,
        }
