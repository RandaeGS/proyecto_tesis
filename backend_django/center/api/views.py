from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response
from rest_framework.permissions import AllowAny
from django.contrib.auth import authenticate
from rest_framework_simplejwt.tokens import RefreshToken

from backend_django.users.api.serializers import UserSerializer
from center.api.serializer import CenterRegistrationSerializer, CenterSerializer


@api_view(['POST'])
@permission_classes([AllowAny])
def register_center(request):
    serializer = CenterRegistrationSerializer(data=request.data)
    if serializer.is_valid():
        data = serializer.save()
        user = data['user']

        # Generar token
        refresh = RefreshToken.for_user(user)

        return Response({
            'token': str(refresh.access_token),
            'user': UserSerializer(user).data,
            'center': CenterSerializer(data['center']).data
        }, status=status.HTTP_201_CREATED)
    return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


@api_view(['POST'])
@permission_classes([AllowAny])
def login_user(request):
    email = request.data.get('email')
    password = request.data.get('password')

    if not email or not password:
        return Response({
            'error': 'Por favor proporcione email y contraseña'
        }, status=status.HTTP_400_BAD_REQUEST)

    user = authenticate(email=email, password=password)

    if user:
        refresh = RefreshToken.for_user(user)
        return Response({
            'token': str(refresh.access_token),
            'user': UserSerializer(user).data
        })

    return Response({
        'error': 'Credenciales inválidas'
    }, status=status.HTTP_401_UNAUTHORIZED)
