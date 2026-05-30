-- ============================================================
-- script_creation.sql
-- Base de données db_efrei_project — MySQL 8.0
-- Domaine : prêt-à-porter (Uniqlo-style)
-- ============================================================

CREATE DATABASE IF NOT EXISTS db_efrei_project;
USE db_efrei_project;

-- ============================================================
-- Suppression des tables (enfants avant parents)
-- ============================================================

SET FOREIGN_KEY_CHECKS = 0;

DROP TABLE IF EXISTS order_items;
DROP TABLE IF EXISTS stock;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS sku;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS categories;
DROP TABLE IF EXISTS customers;
DROP TABLE IF EXISTS locations;
DROP TABLE IF EXISTS colors;
DROP TABLE IF EXISTS sizes;

SET FOREIGN_KEY_CHECKS = 1;

-- ============================================================
-- Création des tables
-- ============================================================

CREATE TABLE categories (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(50) NOT NULL,
    parent_id INT NULL,
    CONSTRAINT fk_category_parent
        FOREIGN KEY (parent_id) REFERENCES categories(id)
        ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE products (
    id INT AUTO_INCREMENT PRIMARY KEY,
    category_id INT NULL,
    name VARCHAR(50) NOT NULL,
    description TEXT,
    price DECIMAL(10,2) NOT NULL DEFAULT 0,
    created_at DATE DEFAULT (CURRENT_DATE),
    CONSTRAINT fk_product_category
        FOREIGN KEY (category_id) REFERENCES categories(id)
        ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE colors (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE
) ENGINE=InnoDB;

CREATE TABLE sizes (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(4) NOT NULL UNIQUE
) ENGINE=InnoDB;

CREATE TABLE sku (
    id INT AUTO_INCREMENT PRIMARY KEY,
    product_id INT NOT NULL,
    size_id INT NOT NULL,
    color_id INT NOT NULL,
    UNIQUE (product_id, size_id, color_id),
    CONSTRAINT fk_sku_product
        FOREIGN KEY (product_id) REFERENCES products(id)
        ON DELETE CASCADE,
    CONSTRAINT fk_sku_size
        FOREIGN KEY (size_id) REFERENCES sizes(id)
        ON DELETE RESTRICT,
    CONSTRAINT fk_sku_color
        FOREIGN KEY (color_id) REFERENCES colors(id)
        ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE locations (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(50) NOT NULL,
    type ENUM('STORE','WAREHOUSE','OUTLET') NOT NULL,
    address TEXT
) ENGINE=InnoDB;

CREATE TABLE stock (
    id INT AUTO_INCREMENT PRIMARY KEY,
    location_id INT NOT NULL,
    sku_id INT NOT NULL,
    quantity INT NOT NULL DEFAULT 0,
    UNIQUE (location_id, sku_id),
    CHECK (quantity >= 0),
    CONSTRAINT fk_stock_location
        FOREIGN KEY (location_id) REFERENCES locations(id)
        ON DELETE CASCADE,
    CONSTRAINT fk_stock_sku
        FOREIGN KEY (sku_id) REFERENCES sku(id)
        ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE customers (
    id INT AUTO_INCREMENT PRIMARY KEY,
    firstname VARCHAR(50) NOT NULL,
    lastname VARCHAR(50) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE
) ENGINE=InnoDB;

CREATE TABLE orders (
    id INT AUTO_INCREMENT PRIMARY KEY,
    customer_id INT NOT NULL,
    location_id INT NOT NULL,
    status ENUM('PENDING','PAID','CANCELLED') NOT NULL,
    created_at DATE DEFAULT (CURRENT_DATE),
    CONSTRAINT fk_order_customer
        FOREIGN KEY (customer_id) REFERENCES customers(id)
        ON DELETE CASCADE,
    CONSTRAINT fk_order_location
        FOREIGN KEY (location_id) REFERENCES locations(id)
        ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE order_items (
    id INT AUTO_INCREMENT PRIMARY KEY,
    order_id INT NOT NULL,
    sku_id INT NOT NULL,
    quantity INT NOT NULL DEFAULT 0,
    price DECIMAL(10,2) NOT NULL,
    UNIQUE (order_id, sku_id),
    CHECK (quantity >= 0),
    CONSTRAINT fk_orderitem_order
        FOREIGN KEY (order_id) REFERENCES orders(id)
        ON DELETE CASCADE,
    CONSTRAINT fk_orderitem_sku
        FOREIGN KEY (sku_id) REFERENCES sku(id)
        ON DELETE RESTRICT
) ENGINE=InnoDB;

-- ============================================================
-- Triggers & Fonctions
-- ============================================================

DELIMITER //

-- Trigger 1 : empêcher un stock négatif
CREATE TRIGGER block_negative_stock
BEFORE UPDATE ON stock
FOR EACH ROW
BEGIN
    IF NEW.quantity < 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Le stock ne peut pas etre negatif';
    END IF;
END //

-- Trigger 2 : affecter automatiquement le prix du produit à la ligne de commande
CREATE TRIGGER set_price_order_item
BEFORE INSERT ON order_items
FOR EACH ROW
BEGIN
    DECLARE v_price DECIMAL(10,2);
    SELECT p.price INTO v_price
    FROM products p
    INNER JOIN sku s ON s.product_id = p.id
    WHERE s.id = NEW.sku_id;
    SET NEW.price = v_price;
END //

-- Trigger 3 : vérifier le stock avant d'ajouter une ligne de commande
CREATE TRIGGER check_stock_before_order
BEFORE INSERT ON order_items
FOR EACH ROW
FOLLOWS set_price_order_item
BEGIN
    DECLARE v_location_id INT;
    DECLARE v_stock INT DEFAULT 0;

    SELECT location_id INTO v_location_id
    FROM orders
    WHERE id = NEW.order_id;

    SELECT COALESCE(SUM(quantity), 0) INTO v_stock
    FROM stock
    WHERE location_id = v_location_id
      AND sku_id = NEW.sku_id;

    IF v_stock < NEW.quantity THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Stock insuffisant pour cette commande';
    END IF;
END //

-- Trigger 4 : décrémenter le stock quand une commande passe à PAID
CREATE TRIGGER update_stock_after_payment
AFTER UPDATE ON orders
FOR EACH ROW
BEGIN
    IF NEW.status = 'PAID' AND OLD.status != 'PAID' THEN
        UPDATE stock s
        INNER JOIN order_items oi ON s.sku_id = oi.sku_id
        SET s.quantity = s.quantity - oi.quantity
        WHERE oi.order_id = NEW.id
          AND s.location_id = NEW.location_id;
    END IF;
END //

-- Fonction 1 : total d'une commande
CREATE FUNCTION get_order_total(p_order_id INT)
RETURNS DECIMAL(10,2)
DETERMINISTIC
BEGIN
    DECLARE v_total DECIMAL(10,2);
    SELECT COALESCE(SUM(quantity * price), 0) INTO v_total
    FROM order_items
    WHERE order_id = p_order_id;
    RETURN v_total;
END //

-- Fonction 2 : stock total d'un SKU (toutes locations)
CREATE FUNCTION get_total_stock(p_sku_id INT)
RETURNS INT
DETERMINISTIC
BEGIN
    DECLARE v_total INT;
    SELECT COALESCE(SUM(quantity), 0) INTO v_total
    FROM stock
    WHERE sku_id = p_sku_id;
    RETURN v_total;
END //

DELIMITER ;

-- ============================================================
-- Insertion des données
-- ============================================================

-- Catégories (9) : 4 parents + 5 sous-catégories
INSERT INTO categories (id, name, parent_id) VALUES
(1, 'Hauts',        NULL),
(2, 'Bas',          NULL),
(3, 'Chaussures',   NULL),
(4, 'Accessoires',  NULL),
(5, 'T-Shirts',     1),
(6, 'Chemises',     1),
(7, 'Jeans',        2),
(8, 'Pantalons',    2),
(9, 'Sneakers',     3);

-- Produits (22)
INSERT INTO products (id, category_id, name, description, price) VALUES
( 1, 5, 'T-Shirt Col Rond',  'T-shirt basique en coton a col rond',       14.90),
( 2, 5, 'T-Shirt Col V',     'T-shirt coupe classique col V',             14.90),
( 3, 5, 'T-Shirt Oversize',  'T-shirt coupe ample tendance',              19.90),
( 4, 5, 'T-Shirt Dry-EX',    'T-shirt technique respirant',               24.90),
( 5, 5, 'T-Shirt Raye',      'T-shirt mariniere a rayures',               17.90),
( 6, 5, 'T-Shirt Poche',     'T-shirt avec poche poitrine',               15.90),
( 7, 6, 'Chemise Oxford',    'Chemise en coton Oxford boutonne',           29.90),
( 8, 6, 'Chemise Lin',       'Chemise legere en lin naturel',              34.90),
( 9, 7, 'Jean Slim',         'Jean coupe slim stretch',                    39.90),
(10, 7, 'Jean Regular',      'Jean coupe droite classique',                39.90),
(11, 7, 'Jean Wide',         'Jean coupe large tendance',                  44.90),
(12, 8, 'Chino Slim',        'Pantalon chino coupe ajustee',               34.90),
(13, 8, 'Chino Regular',     'Pantalon chino coupe droite',                34.90),
(14, 9, 'Sneakers Canvas',   'Baskets en toile legere',                    29.90),
(15, 9, 'Sneakers Cuir',     'Baskets en cuir premium',                    99.90),
(16, 9, 'Sneakers Running',  'Baskets de course amorties',                 89.90),
(17, 3, 'Mocassins Cuir',    'Mocassins en cuir souple',                   89.90),
(18, 4, 'Casquette Logo',    'Casquette avec logo brode',                  14.90),
(19, 4, 'Ceinture Cuir',     'Ceinture en cuir veritable',                 19.90),
(20, 4, 'Echarpe Laine',     'Echarpe en laine merinos',                   24.90),
(21, 4, 'Sac Tote',          'Sac fourre-tout en coton',                    9.90),
(22, 4, 'Bonnet Maille',     'Bonnet en maille tricotee',                  12.90);

-- Couleurs (5)
INSERT INTO colors (id, name) VALUES
(1, 'Noir'), (2, 'Blanc'), (3, 'Bleu'), (4, 'Rouge'), (5, 'Gris');

-- Tailles (4)
INSERT INTO sizes (id, name) VALUES
(1, 'XS'), (2, 'S'), (3, 'M'), (4, 'L');

-- SKU (60 combinaisons produit + taille + couleur)
INSERT INTO sku (id, product_id, size_id, color_id) VALUES
-- T-Shirt Col Rond (4 SKU)
( 1,  1, 1, 1), ( 2,  1, 2, 1), ( 3,  1, 3, 2), ( 4,  1, 4, 3),
-- T-Shirt Col V (4 SKU)
( 5,  2, 2, 1), ( 6,  2, 3, 1), ( 7,  2, 3, 4), ( 8,  2, 4, 5),
-- T-Shirt Oversize (3 SKU)
( 9,  3, 3, 1), (10,  3, 4, 1), (11,  3, 3, 2),
-- T-Shirt Dry-EX (3 SKU)
(12,  4, 1, 3), (13,  4, 2, 3), (14,  4, 3, 5),
-- T-Shirt Raye (2 SKU)
(15,  5, 2, 4), (16,  5, 3, 2),
-- T-Shirt Poche (2 SKU)
(17,  6, 3, 1), (18,  6, 4, 5),
-- Chemise Oxford (3 SKU)
(19,  7, 2, 2), (20,  7, 3, 2), (21,  7, 3, 3),
-- Chemise Lin (3 SKU)
(22,  8, 2, 2), (23,  8, 3, 2), (24,  8, 4, 5),
-- Jean Slim (4 SKU)
(25,  9, 2, 3), (26,  9, 3, 3), (27,  9, 3, 1), (28,  9, 4, 3),
-- Jean Regular (3 SKU)
(29, 10, 2, 3), (30, 10, 3, 3), (31, 10, 4, 1),
-- Jean Wide (3 SKU)
(32, 11, 3, 3), (33, 11, 4, 3), (34, 11, 3, 1),
-- Chino Slim (3 SKU)
(35, 12, 2, 1), (36, 12, 3, 5), (37, 12, 4, 3),
-- Chino Regular (2 SKU)
(38, 13, 2, 1), (39, 13, 3, 5),
-- Sneakers Canvas (3 SKU)
(40, 14, 2, 2), (41, 14, 3, 1), (42, 14, 4, 4),
-- Sneakers Cuir (3 SKU)
(43, 15, 2, 1), (44, 15, 3, 1), (45, 15, 4, 2),
-- Sneakers Running (3 SKU)
(46, 16, 2, 3), (47, 16, 3, 5), (48, 16, 4, 1),
-- Mocassins Cuir (2 SKU)
(49, 17, 3, 1), (50, 17, 4, 1),
-- Casquette Logo (2 SKU)
(51, 18, 3, 1), (52, 18, 3, 2),
-- Ceinture Cuir (2 SKU)
(53, 19, 3, 1), (54, 19, 3, 5),
-- Echarpe Laine (2 SKU)
(55, 20, 3, 5), (56, 20, 3, 4),
-- Sac Tote (2 SKU)
(57, 21, 3, 2), (58, 21, 3, 1),
-- Bonnet Maille (2 SKU)
(59, 22, 3, 5), (60, 22, 3, 1);

-- Locations (4)
INSERT INTO locations (id, name, type, address) VALUES
(1, 'Boutique Paris Opera',      'STORE',     '1 Boulevard Haussmann, 75009 Paris'),
(2, 'Boutique Lyon Part-Dieu',   'STORE',     '17 Rue du Docteur Bouchut, 69003 Lyon'),
(3, 'Entrepot Central Lille',    'WAREHOUSE', 'Zone Industrielle, 59000 Lille'),
(4, 'Outlet Marseille',          'OUTLET',    'Les Terrasses du Port, 13002 Marseille');

-- Stock (60 lignes)
INSERT INTO stock (location_id, sku_id, quantity) VALUES
-- Paris (20 entrées)
(1,  1, 25), (1,  2, 30), (1,  3, 20), (1,  4, 15), (1,  5, 18),
(1,  6, 22), (1,  7, 12), (1,  8, 10), (1, 12, 14), (1, 13, 16),
(1, 14, 20), (1, 25, 15), (1, 26, 18), (1, 27, 12),
(1, 35, 10), (1, 36, 15), (1, 43,  8), (1, 44, 10),
(1, 51, 20), (1, 53, 25),
-- Lyon (15 entrées)
(2,  1, 15), (2,  5, 10), (2,  9, 20), (2, 10, 12), (2, 11, 18),
(2, 19, 14), (2, 20, 10), (2, 23, 12), (2, 29, 20), (2, 30, 15),
(2, 38, 10), (2, 39, 12), (2, 41,  8), (2, 47, 10), (2, 52, 15),
-- Entrepot Lille (15 entrées)
(3,  2, 50), (3,  9, 40), (3, 20, 35), (3, 21, 30), (3, 23, 25),
(3, 26, 40), (3, 30, 35), (3, 32, 30), (3, 34, 25), (3, 38, 20),
(3, 44, 35), (3, 49, 15), (3, 53, 30), (3, 56, 20), (3, 58, 25),
-- Outlet Marseille (10 entrées)
(4,  3, 12), (4,  7,  8), (4, 24, 10), (4, 31, 15), (4, 37, 10),
(4, 40, 12), (4, 46, 15), (4, 51, 10), (4, 55, 18), (4, 59, 10);

-- Clients (5)
INSERT INTO customers (id, firstname, lastname, email) VALUES
(1, 'Marie',  'Dupont',  'marie.dupont@email.fr'),
(2, 'Jean',   'Martin',  'jean.martin@email.fr'),
(3, 'Sophie', 'Bernard', 'sophie.bernard@email.fr'),
(4, 'Lucas',  'Petit',   'lucas.petit@email.fr'),
(5, 'Emma',   'Richard', 'emma.richard@email.fr');

-- Commandes (15) — toutes insérées en PENDING d'abord
INSERT INTO orders (id, customer_id, location_id, status, created_at) VALUES
( 1, 1, 1, 'PENDING', '2024-01-15'),
( 2, 1, 2, 'PENDING', '2024-01-20'),
( 3, 2, 1, 'PENDING', '2024-02-05'),
( 4, 2, 3, 'PENDING', '2024-02-10'),
( 5, 3, 1, 'PENDING', '2024-02-14'),
( 6, 3, 2, 'PENDING', '2024-02-28'),
( 7, 3, 4, 'PENDING', '2024-03-05'),
( 8, 4, 1, 'PENDING', '2024-03-10'),
( 9, 4, 2, 'PENDING', '2024-03-15'),
(10, 4, 3, 'PENDING', '2024-03-20'),
(11, 5, 1, 'PENDING', '2024-04-01'),
(12, 5, 2, 'PENDING', '2024-04-10'),
(13, 5, 4, 'PENDING', '2024-04-15'),
(14, 1, 3, 'PENDING', '2024-04-20'),
(15, 2, 4, 'PENDING', '2024-05-01');

-- Lignes de commande (25) — le prix est auto-rempli par le trigger set_price_order_item
INSERT INTO order_items (order_id, sku_id, quantity, price) VALUES
( 1,  1, 2, 0),   -- T-Shirt Col Rond XS Noir x2
( 1,  5, 1, 0),   -- T-Shirt Col V S Noir x1
( 2,  9, 1, 0),   -- T-Shirt Oversize M Noir x1
( 2, 19, 1, 0),   -- Chemise Oxford S Blanc x1
( 3, 25, 1, 0),   -- Jean Slim S Bleu x1
( 3,  2, 2, 0),   -- T-Shirt Col Rond S Noir x2
( 4, 20, 1, 0),   -- Chemise Oxford M Blanc x1
( 5, 43, 1, 0),   -- Sneakers Cuir S Noir x1
( 5, 35, 1, 0),   -- Chino Slim S Noir x1
( 6, 29, 2, 0),   -- Jean Regular S Bleu x2
( 6, 41, 1, 0),   -- Sneakers Canvas M Noir x1
( 7, 40, 1, 0),   -- Sneakers Canvas S Blanc x1
( 7, 51, 2, 0),   -- Casquette Logo M Noir x2
( 8,  6, 1, 0),   -- T-Shirt Col V M Noir x1
( 9, 23, 1, 0),   -- Chemise Lin M Blanc x1
(10, 32, 1, 0),   -- Jean Wide M Bleu x1
(10, 38, 1, 0),   -- Chino Regular S Noir x1
(11,  3, 1, 0),   -- T-Shirt Col Rond M Blanc x1
(11, 14, 1, 0),   -- T-Shirt Dry-EX M Gris x1
(12, 30, 1, 0),   -- Jean Regular M Bleu x1
(13, 46, 1, 0),   -- Sneakers Running S Bleu x1
(13, 55, 2, 0),   -- Echarpe Laine M Gris x2
(14, 49, 1, 0),   -- Mocassins Cuir M Noir x1
(14, 34, 2, 0),   -- Jean Wide M Noir x2
(15, 59, 1, 0);   -- Bonnet Maille M Gris x1

-- ============================================================
-- Mise à jour des statuts (déclenche update_stock_after_payment)
-- ============================================================

-- Commandes payées → le trigger décrémente le stock automatiquement
UPDATE orders SET status = 'PAID' WHERE id IN (1, 3, 5, 7, 11, 12, 13);

-- Commandes annulées → aucun impact sur le stock
UPDATE orders SET status = 'CANCELLED' WHERE id IN (4, 8);

-- Commandes 2, 6, 9, 10, 14, 15 restent PENDING
