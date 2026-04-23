<?php
session_start();
require_once __DIR__ . '/../config/db.php';
$user = current_user();
$db = get_db();

$q = $_GET['q'] ?? '';
$results = [];
$searched = false;

if ($q !== '') {
    $searched = true;
    // search products
    $results_r = $db->query("SELECT * FROM products WHERE in_stock = 1 AND (name LIKE '%$q%' OR description LIKE '%$q%' OR tags LIKE '%$q%')");
    if ($results_r) {
        while ($row = $results_r->fetch_assoc()) $results[] = $row;
    }
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Search - Grizzy's Gourmet Grub</title>
<link rel="stylesheet" href="/assets/style.css">
</head>
<body>
<?php include __DIR__ . '/partials/header.php'; ?>
<main>
  <div class="page-header">
    <h1>Search Meal Kits</h1>
  </div>
  <form action="/search.php" method="get" style="display:flex;gap:8px;margin-bottom:28px">
    <input type="text" name="q" value="<?= htmlspecialchars($q) ?>" placeholder="e.g. pasta, vegan, spicy..." style="max-width:400px">
    <button class="btn" type="submit">Search</button>
  </form>

  <?php if ($searched): ?>
    <?php if (empty($results)): ?>
      <p style="color:#666">No kits found for "<strong><?= htmlspecialchars($q) ?></strong>". Try a different keyword.</p>
    <?php else: ?>
      <p style="margin-bottom:18px;color:#555"><?= count($results) ?> kit(s) found for "<strong><?= htmlspecialchars($q) ?></strong>"</p>
      <div class="product-grid">
        <?php foreach ($results as $p): ?>
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
        <?php endforeach; ?>
      </div>
    <?php endif; ?>
  <?php endif; ?>
</main>
<?php include __DIR__ . '/partials/footer.php'; ?>
<?php include __DIR__ . '/partials/chat.php'; ?>
</body>
</html>
