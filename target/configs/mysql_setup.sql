-- Grizzy's Gourmet Grub - Database Setup
-- gary 2023-11-02

CREATE DATABASE IF NOT EXISTS grizzy_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE USER IF NOT EXISTS 'grizzy_app'@'%' IDENTIFIED BY 'grizzy2024!';
GRANT ALL PRIVILEGES ON grizzy_db.* TO 'grizzy_app'@'%';
FLUSH PRIVILEGES;

USE grizzy_db;

CREATE TABLE IF NOT EXISTS users (
    id         INT AUTO_INCREMENT PRIMARY KEY,
    username   VARCHAR(80)  NOT NULL,
    email      VARCHAR(180) NOT NULL UNIQUE,
    password   VARCHAR(64)  NOT NULL,
    avatar     VARCHAR(120) DEFAULT NULL,
    created_at DATETIME     NOT NULL
);

CREATE TABLE IF NOT EXISTS products (
    id          INT AUTO_INCREMENT PRIMARY KEY,
    name        VARCHAR(120) NOT NULL,
    description TEXT,
    price       DECIMAL(8,2) NOT NULL,
    image       VARCHAR(120) DEFAULT 'default.jpg',
    category    VARCHAR(60)  DEFAULT 'Other',
    tags        VARCHAR(200) DEFAULT '',
    prep_time   VARCHAR(40)  DEFAULT '30 mins',
    in_stock    TINYINT(1)   DEFAULT 1,
    featured    TINYINT(1)   DEFAULT 0
);

CREATE TABLE IF NOT EXISTS orders (
    id            INT AUTO_INCREMENT PRIMARY KEY,
    user_id       INT          NOT NULL,
    items         JSON,
    total         DECIMAL(8,2) NOT NULL,
    status        VARCHAR(30)  DEFAULT 'pending',
    delivery_date DATE,
    address       TEXT,
    created_at    DATETIME     NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE TABLE IF NOT EXISTS reviews (
    id         INT AUTO_INCREMENT PRIMARY KEY,
    product_id INT  NOT NULL,
    user_id    INT  NOT NULL,
    rating     TINYINT(1) DEFAULT 3,
    content    TEXT,
    created_at DATETIME NOT NULL,
    FOREIGN KEY (product_id) REFERENCES products(id),
    FOREIGN KEY (user_id)    REFERENCES users(id)
);

-- Seed: admin/staff account  (password: grizzy@dmin2024)
INSERT INTO users (username, email, password, created_at) VALUES
('greg_grizzy',  'greg@grizzygourmetgrub.co.uk',  md5('grizzy@dmin2024'), NOW()),
('gary_dev',     'gary@grizzygourmetgrub.co.uk',   md5('gary1234'),        NOW()),
('sarah_jones',  'sarah.j@example.com',             md5('sarah123'),        NOW()),
('mike_t',       'mike.thompson@example.com',        md5('password1'),       NOW()),
('emma_w',       'emma.watson92@example.com',        md5('ilovefood'),       NOW());

-- Seed: products
INSERT INTO products (name, description, price, image, category, tags, prep_time, featured) VALUES
('Smoky Shakshuka Kit',       'Eggs poached in a rich tomato and pepper sauce with smoked paprika, cumin, and fresh herbs. Served with crusty sourdough bread.',          7.99,  'shakshuka.jpg',   'Vegetarian', 'vegetarian,spicy,eggs,quick',       '25 mins', 1),
('Peak District Lamb Stew',   'Slow-braised lamb shoulder with root vegetables, rosemary, and pearl barley. A proper northern classic.',                                   12.49, 'lamb_stew.jpg',   'Meat',       'hearty,lamb,slow-cook,winter',       '2.5 hrs', 1),
('Thai Green Curry',          'Fragrant coconut milk curry with chicken, courgette, and fresh Thai basil. Served with jasmine rice.',                                      9.99,  'thai_curry.jpg',  'Meat',       'spicy,chicken,dairy-free,asian',     '30 mins', 1),
('Roasted Aubergine Pasta',   'Whole-wheat penne with roasted aubergine, cherry tomatoes, garlic, and a generous handful of parmesan.',                                    8.49,  'aubergine.jpg',   'Vegetarian', 'vegetarian,pasta,italian',           '35 mins', 0),
('Paneer Tikka Masala',       'Tandoor-spiced paneer in a creamy tomato masala sauce. Served with pilau rice and a mini garlic naan.',                                     9.49,  'tikka.jpg',       'Vegetarian', 'vegetarian,indian,spicy,creamy',     '40 mins', 1),
('Harissa Salmon Tray Bake',  'Atlantic salmon fillets with harissa marinade, roasted cherry tomatoes, olives, and couscous.',                                             11.99, 'salmon.jpg',      'Fish',       'fish,healthy,mediterranean,quick',   '25 mins', 0),
('Sheffield Street Burger',   'Two smashed beef patties with caramelised onions, pickles, and Grizzy''s special sauce. Includes brioche buns and hand-cut chips.',         10.99, 'burger.jpg',      'Meat',       'burgers,beef,comfort,american',      '30 mins', 1),
('Mushroom Risotto',          'Creamy arborio rice with wild mushrooms, white wine, thyme, and aged parmesan. Vegetarian comfort food at its best.',                       8.99,  'risotto.jpg',     'Vegetarian', 'vegetarian,italian,creamy,mushroom', '40 mins', 0),
('BBQ Pulled Jackfruit Tacos','Slow-cooked jackfruit in smoky BBQ sauce, served in corn tortillas with pickled red cabbage and chipotle mayo.',                            8.49,  'jackfruit.jpg',   'Vegan',      'vegan,mexican,bbq,smoky',            '45 mins', 0),
('Classic Fish & Chips',      'Beer-battered sustainable cod fillets with thick-cut chips, mushy peas, and tartare sauce. A Yorkshire staple.',                            10.49, 'fishchips.jpg',   'Fish',       'fish,british,classic,comfort',       '35 mins', 0),
('Vegan Dahl',                'Red lentil dahl with turmeric, coconut milk, and wilted spinach. Served with basmati rice and poppadoms.',                                  7.49,  'dahl.jpg',        'Vegan',      'vegan,indian,healthy,lentils',       '30 mins', 0),
('Steak Night Kit',           'Two 8oz sirloin steaks with chimichurri sauce, peppercorn sauce, roasted tenderstem broccoli, and triple-cooked chips.',                   15.99, 'steak.jpg',       'Meat',       'steak,beef,premium,dinner',          '25 mins', 1);

-- Seed: sample orders
INSERT INTO orders (user_id, items, total, status, delivery_date, address, created_at) VALUES
(3, '[{"name":"Smoky Shakshuka Kit","qty":1,"price":7.99},{"name":"Vegan Dahl","qty":1,"price":7.49}]',        15.48, 'delivered', '2024-03-05', '22 Peel Street, Sheffield, S10 2PD', '2024-03-01 11:32:00'),
(3, '[{"name":"Peak District Lamb Stew","qty":1,"price":12.49}]',                                               12.49, 'shipped',   '2024-03-12', '22 Peel Street, Sheffield, S10 2PD', '2024-03-08 09:14:00'),
(4, '[{"name":"Thai Green Curry","qty":1,"price":9.99},{"name":"Sheffield Street Burger","qty":1,"price":10.99}]', 20.98, 'processing', '2024-03-12', '7 Glossop Road, Sheffield, S10 2GW', '2024-03-08 14:55:00'),
(5, '[{"name":"Harissa Salmon Tray Bake","qty":1,"price":11.99}]',                                              11.99, 'pending',   '2024-03-12', '104 Abbeydale Road, Sheffield, S7 1FE', '2024-03-09 08:20:00'),
(1, '[{"name":"Steak Night Kit","qty":2,"price":15.99}]',                                                       31.98, 'delivered', '2024-02-27', 'Unit 4, Kelham Island, Sheffield, S3 8RW', '2024-02-23 16:00:00');

-- Seed: reviews
INSERT INTO reviews (product_id, user_id, rating, content, created_at) VALUES
(1, 3, 5, 'Absolutely loved this! Eggs were perfect and the sourdough really made it. Will order again.', '2024-02-14 18:22:00'),
(1, 4, 4, 'Really tasty, though I added a bit more paprika. Easy to follow recipe card.', '2024-02-20 20:10:00'),
(7, 5, 5, 'Best burger I''ve had outside of a restaurant. That special sauce is incredible!', '2024-02-28 21:05:00'),
(3, 3, 4, 'Great curry, loads of flavour. I added extra chilli because I like it hot.', '2024-03-06 19:40:00'),
(12,1, 5, 'Sirloin was quality stuff. Greg picks good suppliers! Chimichurri was a revelation.', '2024-02-27 22:15:00');
