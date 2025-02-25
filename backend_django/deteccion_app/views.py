import time
from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.response import Response
from django.conf import settings

from .models import Deteccion
from .api.serializers import DeteccionSerializer, ImagenUploadSerializer
from .services.Robo_Services import RoboflowService
from .services.yolo_service import YOLOService
from .services.c_service import ClaudeService

from PIL import Image
import logging

logger = logging.getLogger(__name__)


class DeteccionViewSet(viewsets.ReadOnlyModelViewSet):
    """ViewSet para listar y recuperar detecciones"""

    queryset = Deteccion.objects.all()
    serializer_class = DeteccionSerializer

    # En tu clase DeteccionViewSet
    @action(detail=False, methods=['post'], url_path='analizar')
    def analizar_imagen(self, request):
        """
        Analiza una imagen usando el modelo seleccionado
        """
        serializer = ImagenUploadSerializer(data=request.data)

        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        imagen_file = serializer.validated_data['imagen']
        tipo_modelo = serializer.validated_data['tipo_modelo']
        guardar_imagen = serializer.validated_data['guardar_imagen']

        # Cargar imagen con PIL
        try:
            imagen_pil = Image.open(imagen_file)
        except Exception as e:
            return Response(
                {'error': f'Error al abrir la imagen: {str(e)}'},
                status=status.HTTP_400_BAD_REQUEST
            )

        # Seleccionar el servicio de modelo apropiado
        if tipo_modelo == 'yolo':
            modelo_service = YOLOService()
        elif tipo_modelo == 'claude':
            modelo_service = ClaudeService()
        elif tipo_modelo == 'roboflow':
            modelo_service = RoboflowService()
        else:
            return Response(
                {'error': f'Tipo de modelo no soportado: {tipo_modelo}'},
                status=status.HTTP_400_BAD_REQUEST
            )

        # Resto del código...

        # Procesar la imagen
        try:
            start_time = time.time()
            modelo_service.load_model()  # Asegurarse de que el modelo esté cargado
            resultados = modelo_service.process_image(imagen_pil)
            tiempo_procesamiento = time.time() - start_time

            # Crear registro en la base de datos
            deteccion = Deteccion(
                tipo_modelo=tipo_modelo,
                tiempo_procesamiento=tiempo_procesamiento
            )

            # Guardar la imagen si se solicita
            if guardar_imagen:
                deteccion.imagen = imagen_file

            # Guardar los resultados
            deteccion.set_resultados(resultados)
            deteccion.save()

            # Devolver los resultados
            return Response({
                'deteccion_id': deteccion.id,
                'tiempo_procesamiento': tiempo_procesamiento,
                'resultados': resultados
            })

        except Exception as e:
            logger.error(f"Error al procesar la imagen: {str(e)}", exc_info=True)
            return Response(
                {'error': f'Error al procesar la imagen: {str(e)}'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

    @action(detail=False, methods=['get'], url_path='info-modelo')
    def info_modelo(self, request):
        """
        Devuelve información sobre los modelos disponibles
        """
        tipo_modelo = request.query_params.get('tipo', 'yolo')

        try:
            if tipo_modelo == 'yolo':
                modelo_service = YOLOService()
            elif tipo_modelo == 'claude':
                modelo_service = ClaudeService()
            else:
                return Response(
                    {'error': f'Tipo de modelo no soportado: {tipo_modelo}'},
                    status=status.HTTP_400_BAD_REQUEST
                )

            modelo_service.load_model()
            info = modelo_service.get_model_info()

            return Response(info)

        except Exception as e:
            logger.error(f"Error al obtener información del modelo: {str(e)}", exc_info=True)
            return Response(
                {'error': f'Error al obtener información del modelo: {str(e)}'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
