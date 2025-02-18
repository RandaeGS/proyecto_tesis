from django.urls import path
from .api import views

urlpatterns = [
    path('register/', views.register_center, name='register_center'),
    path('login/', views.login_user, name='login_user'),
]
