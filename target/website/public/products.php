<?php
session_start();
require_once __DIR__ . '/../config/db.php';
$user = current_user();
$db = get_db();

$cat = $_GET['cat'] ?? '';
$where = "WHERE in_stock = 1";
if ($cat) {
    $c = $db->real_escape_string($cat);
    $where .= " AND category = '$c'";
}
$products = $db->query("SELECT * FROM products $where ORDER BY featured DESC, name ASC");
$cats = $db->query("SELECT DISTINCT category FROM products WHERE in_stock = 1 ORDER BY category");
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>All Kits - Grizzy's Gourmet Grub</title>
<link rel="stylesheet" href="/assets/style.css">
</head>
<body>
<?php include __DIR__ . '/partials/header.php'; ?>
<main>
  <div class="page-header">
    <h1>All Meal Kits</h1>
  </div>
  <div style="margin-bottom:20px;display:flex;gap:10px;flex-wrap:wrap">
    <a href="/products.php" class="btn btn-sm <?= !$cat ? '' : 'btn-outline' ?>">All</a>
    <?php while ($c = $cats->fetch_assoc()): ?>
      <a href="/products.php?cat=<?= urlencode($c['category']) ?>" class="btn btn-sm <?= $cat === $c['category'] ? '' : 'btn-outline' ?>"><?= htmlspecialchars($c['category']) ?></a>
    <?php endwhile; ?>
  </div>
  <div class="product-grid">
    <?php while ($p = $products->fetch_assoc()): ?>
    <div class="product-card">
      <img src="/assets/food/<?= htmlspecialchars($p['image']) ?>" onerror="this.src='/assets/food/default.jpg'" alt="">
      <div class="card-body">
        <h3><a href="/product.php?id=<?= $p['id'] ?>"><?= htmlspecialchars($p['name']) ?></a></h3>
        <div class="tags">
          <?php foreach (explode(',', $p['tags'] ?? '') as $t): $t = trim($t); if ($t): ?>
            <span class="badge"><?= htmlspecialchars($t) ?></span>
          <?php endif; endforeach; ?>
        </div>
        <div class="price">£<?= number_format($p['price'], 2) ?></div>
        <a href="/product.php?id=<?= $p['id'] ?>" class="btn btn-sm">View Kit</a>
      </div>
    </div>
    <?php endwhile; ?>
  </div>
</main>
<?php include __DIR__ . '/partials/footer.php'; ?>
<?php include __DIR__ . '/partials/chat.php'; ?>
</body>
</html>
