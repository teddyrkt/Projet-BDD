from django.urls import path
from . import views

urlpatterns = [
    path('', views.product_list, name='product_list'),
    path('produit/<int:pk>/', views.product_detail, name='product_detail'),
    path('produit/ajouter/', views.product_create, name='product_create'),
    path('produit/<int:pk>/modifier/', views.product_update, name='product_update'),
    path('produit/<int:pk>/supprimer/', views.product_delete, name='product_delete'),
    path('statistiques/', views.stats, name='stats'),
]
