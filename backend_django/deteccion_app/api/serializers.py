from rest_framework import serializers
from ..models import Deteccion


class DeteccionSerializer(serializers.ModelSerializer):
    """Serializador para el modelo de Detección"""

    resultados = serializers.SerializerMethodField()

    class Meta:
        model = Deteccion
        fields = ['id', 'fecha_creacion', 'tipo_modelo', 'numero_objetos',
                  'tiempo_procesamiento', 'resultados']
        read_only_fields = ['id', 'fecha_creacion', 'numero_objetos',
                            'tiempo_procesamiento', 'resultados']

    def get_resultados(self, obj):
        """Obtiene los resultados como diccionario"""
        return obj.get_resultados()


class ImagenUploadSerializer(serializers.Serializer):
    """Serializador para la subida de imágenes"""

    imagen = serializers.ImageField()
    tipo_modelo = serializers.ChoiceField(
        choices=[
            ('yolo', 'YOLO'),
            ('claude', 'Claude API'),
            ('roboflow', 'Roboflow API')
        ]
    )
    guardar_imagen = serializers.BooleanField(default=False)
