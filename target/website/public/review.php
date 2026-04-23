<?php
session_start();
require_once __DIR__ . '/../config/db.php';
$user = current_user();

if (!$user) { header('Location: /login.php'); exit; }
if ($_SERVER['REQUEST_METHOD'] !== 'POST') { header('Location: /products.php'); exit; }

$product_id = (int)($_POST['product_id'] ?? 0);
$rating     = (int)($_POST['rating'] ?? 3);
$content    = $_POST['content'] ?? '';

if (!$product_id || !$content) { header("Location: /product.php?id=$product_id"); exit; }

$rating = max(1, min(5, $rating));

$db = get_db();
$uid = (int)$user['id'];

// store review - content saved as provided
$db->query("INSERT INTO reviews (product_id, user_id, rating, content, created_at) VALUES ($product_id, $uid, $rating, '" . $db->real_escape_string($content) . "', NOW())");

header("Location: /product.php?id=$product_id&reviewed=1");
exit;
