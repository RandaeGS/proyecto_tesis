import os
import time
import base64
from io import BytesIO
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

        # Crear una ruta absoluta para el directorio debug_images
        current_dir = os.path.dirname(os.path.abspath(__file__))
        self.debug_dir = os.path.join(current_dir, 'debug_images')
        os.makedirs(self.debug_dir, exist_ok=True)

        # Imprimir la ruta para verificación
        print(f"Directorio de debug creado en: {self.debug_dir}")

    def load_model(self):
        # No hace nada; la SDK es serverless
        pass

    def _convert_image_to_base64(self, img_data) -> str:
        """
        Convierte la imagen de Roboflow a base64 para enviar al frontend
        """
        try:
            if isinstance(img_data, str):
                # Si ya es base64, devolverla tal como está
                return img_data
            elif hasattr(img_data, 'numpy_image'):
                # Si es un objeto de Roboflow con numpy_image
                import numpy as np

                pil_image = Image.fromarray(img_data.numpy_image)
                buffer = BytesIO()
                pil_image.save(buffer, format='PNG')
                img_str = base64.b64encode(buffer.getvalue()).decode()
                return img_str
            elif isinstance(img_data, Image.Image):
                # Si es una imagen PIL (Image ya está importado al inicio)
                buffer = BytesIO()
                img_data.save(buffer, format='PNG')
                img_str = base64.b64encode(buffer.getvalue()).decode()
                return img_str
            else:
                logger.warning(f"Tipo de imagen no reconocido: {type(img_data)}")
                return None
        except Exception as e:
            logger.error(f"Error convirtiendo imagen a base64: {str(e)}")
            return None

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
                            pred.get('y', 0) + pred.get('height', 0) / 2  # y2
                        ],
                        'detection_id': pred.get('detection_id', ''),
                        'class_id': pred.get('class_id', 0)
                    }
                    detections.append(detection)

            logger.info(f"RF-DETR: Detecciones convertidas: {len(detections)}")

            if first.get("output_image"):
                debug_output_path = os.path.join(self.debug_dir, f"output_roboflow_{int(time.time())}.png")
                print(f"Intentando guardar imagen en: {debug_output_path}")
                print(f"Tipo de output_image: {type(first['output_image'])}")

                try:
                    # Verificar si el directorio existe
                    print(f"¿Directorio existe? {os.path.exists(self.debug_dir)}")

                    if isinstance(first["output_image"], str):
                        print("Es un string (probablemente base64)")
                        # Decodificar base64 a bytes
                        try:
                            # Eliminar el prefijo 'data:image/png;base64,' si existe
                            base64_data = first["output_image"]
                            if ',' in base64_data:
                                base64_data = base64_data.split(',')[1]

                            # Decodificar base64 a bytes
                            image_bytes = base64.b64decode(base64_data)

                            # Convertir bytes a imagen PIL
                            image = Image.open(BytesIO(image_bytes))

                            # Guardar imagen
                            image.save(debug_output_path)
                            print("Guardado exitosamente desde base64")
                        except Exception as e:
                            print(f"Error procesando base64: {str(e)}")

                    elif hasattr(first["output_image"], 'numpy_image'):
                        print("Tiene atributo numpy_image")
                        output_img = Image.fromarray(first["output_image"].numpy_image)
                        output_img.save(debug_output_path)
                        print("Guardado como numpy")
                    elif isinstance(first["output_image"], Image.Image):
                        print("Es una imagen PIL")
                        first["output_image"].save(debug_output_path)
                        print("Guardado como PIL")

                    # Verificar si el archivo existe después de guardarlo
                    if os.path.exists(debug_output_path):
                        print(f"Verificado: el archivo existe en {debug_output_path}")
                        print(f"Tamaño del archivo: {os.path.getsize(debug_output_path)} bytes")

                        # Verificar que la imagen se puede abrir
                        try:
                            with Image.open(debug_output_path) as img:
                                print(f"Imagen guardada correctamente: {img.size}")
                        except Exception as e:
                            print(f"Error verificando la imagen guardada: {str(e)}")
                    else:
                        print(f"Error: el archivo no existe en {debug_output_path}")

                except Exception as e:
                    print(f"Error durante el guardado: {str(e)}")
                    # Imprimir los primeros 100 caracteres del string para debug
                    if isinstance(first["output_image"], str):
                        print(f"Primeros 100 caracteres del string: {first['output_image'][:100]}")

                # Continuar con el proceso normal de conversión a base64
            output_image_base64 = None
            if first.get("output_image"):
                output_image_base64 = self._convert_image_to_base64(first.get("output_image"))
                logger.info(f"RF-DETR: Imagen de salida convertida a base64: {'Sí' if output_image_base64 else 'No'}")

            # Devolver en el formato esperado por tu view
            return {
                "detections": detections,  # ← Esto es lo que busca tu view
                "count_objects": count,
                "predictions": predictions,
                "output_image": output_image_base64,  # ← Imagen con bounding boxes en base64
                "visualization": output_image_base64,  # ← Alias para compatibilidad
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
                "output_image": None,
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
