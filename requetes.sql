-- ============================================================
-- requetes.sql — 15 requêtes sur db_efrei_project
-- MySQL 8.0
-- ============================================================

USE db_efrei_project;

-- ----------------------------------------------------------------
-- R1 : Liste de tous les produits triés par nom
-- Approche : SELECT simple avec ORDER BY alphabétique sur name
-- ----------------------------------------------------------------
SELECT *
FROM products
ORDER BY name;

-- ----------------------------------------------------------------
-- R2 : Produits dont le prix est supérieur à 50 €
-- Approche : filtrage avec WHERE price > 50
-- ----------------------------------------------------------------
SELECT id, name, price
FROM products
WHERE price > 50
ORDER BY price;

-- ----------------------------------------------------------------
-- R3 : Produits d'une catégorie donnée (ici catégorie 5 = T-Shirts)
-- Approche : filtrage direct par category_id
-- ----------------------------------------------------------------
SELECT id, name, price
FROM products
WHERE category_id = 5;

-- ----------------------------------------------------------------
-- R4 : Jointure interne produits + catégories
-- Approche : INNER JOIN — seuls les produits ayant une catégorie
--            existante sont retournés
-- ----------------------------------------------------------------
SELECT p.id,
       p.name   AS produit,
       p.price,
       c.name   AS categorie
FROM products p
INNER JOIN categories c ON p.category_id = c.id
ORDER BY c.name, p.name;

-- ----------------------------------------------------------------
-- R5 : Jointure externe produits + catégories
-- Approche : LEFT JOIN — conserve tous les produits, y compris
--            ceux dont category_id serait NULL
-- ----------------------------------------------------------------
SELECT p.id,
       p.name   AS produit,
       p.price,
       c.name   AS categorie
FROM products p
LEFT JOIN categories c ON p.category_id = c.id
ORDER BY c.name, p.name;

-- ----------------------------------------------------------------
-- R6 : Somme des prix par catégorie avec le nom de la catégorie
-- Approche : GROUP BY catégorie + SUM(price) + JOIN pour le nom
-- ----------------------------------------------------------------
SELECT c.name          AS categorie,
       SUM(p.price)    AS total_prix
FROM products p
INNER JOIN categories c ON p.category_id = c.id
GROUP BY c.id, c.name
ORDER BY total_prix DESC;

-- ----------------------------------------------------------------
-- R7 : Nombre de produits par catégorie, trié par ordre décroissant
-- Approche : LEFT JOIN pour inclure les catégories vides,
--            COUNT sur products.id, ORDER BY DESC
-- ----------------------------------------------------------------
SELECT c.name          AS categorie,
       COUNT(p.id)     AS nb_produits
FROM categories c
LEFT JOIN products p ON c.id = p.category_id
GROUP BY c.id, c.name
ORDER BY nb_produits DESC;

-- ----------------------------------------------------------------
-- R8 : Catégories ayant plus de 5 produits
-- Approche : GROUP BY + HAVING COUNT > 5 pour filtrer après
--            agrégation (T-Shirts = 6 produits)
-- ----------------------------------------------------------------
SELECT c.name          AS categorie,
       COUNT(p.id)     AS nb_produits
FROM categories c
INNER JOIN products p ON c.id = p.category_id
GROUP BY c.id, c.name
HAVING COUNT(p.id) > 5;

-- ----------------------------------------------------------------
-- R9 : Somme des prix par catégorie, uniquement > 200 €
-- Approche : GROUP BY + SUM + HAVING SUM > 200
--            (Sneakers = 219.70 €)
-- ----------------------------------------------------------------
SELECT c.name          AS categorie,
       SUM(p.price)    AS total_prix
FROM products p
INNER JOIN categories c ON p.category_id = c.id
GROUP BY c.id, c.name
HAVING SUM(p.price) > 200;

-- ----------------------------------------------------------------
-- R10 : Prix maximum par catégorie
-- Approche : GROUP BY catégorie + MAX(price)
-- ----------------------------------------------------------------
SELECT c.name          AS categorie,
       MAX(p.price)    AS prix_max
FROM products p
INNER JOIN categories c ON p.category_id = c.id
GROUP BY c.id, c.name
ORDER BY prix_max DESC;

-- ----------------------------------------------------------------
-- R11 : Produits dont le prix dépasse la moyenne générale
-- Approche : sous-requête scalaire SELECT AVG(price) dans le WHERE
--            (moyenne ≈ 34.54 €)
-- ----------------------------------------------------------------
SELECT p.name  AS produit,
       p.price,
       c.name  AS categorie
FROM products p
INNER JOIN categories c ON p.category_id = c.id
WHERE p.price > (SELECT AVG(price) FROM products)
ORDER BY p.price DESC;

-- ----------------------------------------------------------------
-- R12 : Clients dont TOUTES les commandes sont PAID
-- Approche : NOT EXISTS avec sous-requête corrélée cherchant
--            une commande NON payée pour ce client.
--            "∀ commandes PAID" ⟺ "¬∃ commande non-PAID"
-- ----------------------------------------------------------------
SELECT cu.id,
       cu.firstname,
       cu.lastname,
       cu.email
FROM customers cu
WHERE NOT EXISTS (
    SELECT 1
    FROM orders o
    WHERE o.customer_id = cu.id
      AND o.status != 'PAID'
);

-- ----------------------------------------------------------------
-- R13 : Classement des produits par catégorie puis prix DESC
-- Approche : fonction fenêtre RANK() partitionnée par category_id,
--            ordonnée par price DESC
-- ----------------------------------------------------------------
SELECT c.name  AS categorie,
       p.name  AS produit,
       p.price,
       RANK() OVER (
           PARTITION BY p.category_id
           ORDER BY p.price DESC
       ) AS rang
FROM products p
INNER JOIN categories c ON p.category_id = c.id
ORDER BY c.name, rang;

-- ----------------------------------------------------------------
-- R14 : SKU présents dans au moins 2 locations différentes
-- Approche : GROUP BY sku_id sur la table stock,
--            HAVING COUNT(DISTINCT location_id) >= 2
-- ----------------------------------------------------------------
SELECT sk.id       AS sku_id,
       p.name      AS produit,
       sz.name     AS taille,
       co.name     AS couleur,
       COUNT(DISTINCT st.location_id) AS nb_locations
FROM sku sk
INNER JOIN stock st    ON sk.id = st.sku_id
INNER JOIN products p  ON sk.product_id = p.id
INNER JOIN sizes sz    ON sk.size_id = sz.id
INNER JOIN colors co   ON sk.color_id = co.id
GROUP BY sk.id, p.name, sz.name, co.name
HAVING COUNT(DISTINCT st.location_id) >= 2
ORDER BY nb_locations DESC, p.name;

-- ----------------------------------------------------------------
-- R15 : Pour chaque catégorie, le(s) produit(s) au prix maximum
--        (égalités incluses)
-- Approche : sous-requête corrélée — on compare le prix de chaque
--            produit au MAX(price) de sa propre catégorie
-- ----------------------------------------------------------------
SELECT p.name  AS produit,
       p.price,
       c.name  AS categorie
FROM products p
INNER JOIN categories c ON p.category_id = c.id
WHERE p.price = (
    SELECT MAX(p2.price)
    FROM products p2
    WHERE p2.category_id = p.category_id
)
ORDER BY c.name, p.name;
