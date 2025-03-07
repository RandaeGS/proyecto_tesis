from rest_framework import serializers
from django.contrib.auth import get_user_model

from center.models import Center

User = get_user_model()

class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ('id', 'email', 'name', 'password', 'is_superuser', 'is_staff')
        extra_kwargs = {
            'password': {'write_only': True},
            'id': {'read_only': True}
        }

    def create(self, validated_data):
        password = validated_data.pop('password')
        user = User(**validated_data)
        user.set_password(password)
        user.save()
        return user


class UserSerializerForCenter(serializers.ModelSerializer):
    centers = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = ['id', 'username', 'email', 'first_name', 'last_name', 'centers']

    def get_centers(self, obj):
        return [
            {
                'id': center.id,
                'name': center.name
            }
            for center in obj.centers.all()
        ]

class CenterSerializer(serializers.ModelSerializer):
    users = UserSerializer(many=True, read_only=True)

    class Meta:
        model = Center
        fields = ['id', 'name', 'address', 'users', 'created_at']
