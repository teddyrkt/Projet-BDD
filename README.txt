===================================================
  GESTION PRODUITS — Projet ALSI61
  WAN William | LO Hsiao-Wen-Paul | RAKOTOARISOA Teddy
===================================================

DOMAINE : Système de gestion de produits (retail/e-commerce)
LANGAGE : Python 3 + Django 4.2
BASE DE DONNÉES : MySQL

---------------------------------------------------
PRÉREQUIS
---------------------------------------------------
- Python 3.10+
- MySQL 8.0+
- pip

---------------------------------------------------
INSTALLATION
---------------------------------------------------

1. Cloner le repo et aller dans le dossier src/

2. Installer les dépendances :
   pip install -r requirements.txt

3. Configurer MySQL dans gestion_produits/settings.py :
   - NAME     → db_efrei_project
   - USER     → votre user MySQL (ex: root)
   - PASSWORD → votre mot de passe MySQL
   - HOST     → 127.0.0.1
   - PORT     → 3306

4. Créer la base de données et charger les données :
   mysql -u root -p < ../script_creation.sql

5. Lancer le serveur Django :
   python manage.py migrate --run-syncdb
   python manage.py runserver

6. Ouvrir dans le navigateur :
   http://127.0.0.1:8000

---------------------------------------------------
FONCTIONNALITÉS
---------------------------------------------------
- /                    → Liste + recherche de produits
- /produit/<id>/       → Détail d'un produit (SKU + stock)
- /produit/ajouter/    → Ajouter un produit
- /produit/<id>/modifier/   → Modifier un produit
- /produit/<id>/supprimer/  → Supprimer un produit
- /statistiques/       → Classements et stats globales

---------------------------------------------------
RÈGLES MÉTIER (résumé)
---------------------------------------------------
- Un produit appartient à une catégorie (nullable)
- Un SKU = combinaison unique produit + taille + couleur
- Un SKU ne peut apparaître qu'une fois par localisation
- La quantité de stock ne peut pas être négative
- Un client a un email unique
- Une commande a un statut : PENDING, PAID ou CANCELLED
