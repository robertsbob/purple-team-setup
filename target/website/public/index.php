<?php
session_start();
require_once __DIR__ . '/../config/db.php';
$user = current_user();
$db = get_db();

$featured = $db->query("SELECT * FROM products WHERE in_stock = 1 ORDER BY featured DESC, id ASC LIMIT 6");
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Grizzy's Gourmet Grub - Fresh Meal Kits Delivered</title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<link rel="stylesheet" href="/assets/style.css">
</head>
<body>
<?php include __DIR__ . '/partials/header.php'; ?>

<div class="hero">
  <h1>Cook Amazing Meals at Home</h1>
  <p>Fresh ingredients, step-by-step recipes, delivered to your door every week.</p>
  <form action="/search.php" method="get">
    <input type="text" name="q" placeholder="Search meal kits...">
    <button class="btn" type="submit">Search</button>
  </form>
</div>

<main>
  <h2 class="section-title">This Week's Kits</h2>
  <div class="product-grid">
    <?php while ($p = $featured->fetch_assoc()): ?>
    <div class="product-card">
      <img src="/assets/food/<?= htmlspecialchars($p['image']) ?>" alt="<?= htmlspecialchars($p['name']) ?>" onerror="this.src='/assets/food/default.jpg'">
      <div class="card-body">
        <h3><a href="/product.php?id=<?= $p['id'] ?>"><?= htmlspecialchars($p['name']) ?></a></h3>
        <div class="tags">
          <?php foreach (explode(',', $p['tags'] ?? '') as $t): $t = trim($t); if ($t): ?>
            <span class="badge"><?= htmlspecialchars($t) ?></span>
          <?php endif; endforeach; ?>
        </div>
        <div class="price">£<?= number_format($p['price'], 2) ?> <small style="color:#888;font-size:0.7em">/ kit (2 servings)</small></div>
        <a href="/product.php?id=<?= $p['id'] ?>" class="btn btn-sm">View Kit</a>
      </div>
    </div>
    <?php endwhile; ?>
  </div>

  <div style="background:#fff;border:1px solid var(--border);border-radius:8px;padding:28px;margin-top:40px;display:grid;grid-template-columns:1fr 1fr 1fr;gap:20px;text-align:center;">
    <div>
      <div style="font-size:2rem">🥦</div>
      <strong>Fresh & Local</strong>
      <p style="font-size:0.88rem;color:#666;margin-top:6px">Sourced from farms in Yorkshire and the Peak District.</p>
    </div>
    <div>
      <div style="font-size:2rem">📦</div>
      <strong>Weekly Delivery</strong>
      <p style="font-size:0.88rem;color:#666;margin-top:6px">Every Tuesday, straight to your doorstep. No fuss.</p>
    </div>
    <div>
      <div style="font-size:2rem">📖</div>
      <strong>Easy Recipes</strong>
      <p style="font-size:0.88rem;color:#666;margin-top:6px">Step-by-step cards included. Beginner friendly.</p>
    </div>
  </div>
</main>

<?php include __DIR__ . '/partials/footer.php'; ?>
<?php include __DIR__ . '/partials/chat.php'; ?>
</body>
</html>
