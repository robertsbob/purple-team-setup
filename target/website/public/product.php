<?php
session_start();
require_once __DIR__ . '/../config/db.php';
$user = current_user();
$db = get_db();

$id = (int)($_GET['id'] ?? 0);
if (!$id) { header('Location: /products.php'); exit; }

$r = $db->query("SELECT * FROM products WHERE id = $id AND in_stock = 1");
if (!$r || !($p = $r->fetch_assoc())) { header('Location: /products.php'); exit; }

// Add to cart
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['add_cart'])) {
    $_SESSION['cart'][$id] = ['qty' => 1, 'name' => $p['name'], 'price' => $p['price']];
    $added = true;
}

$reviews = $db->query("SELECT r.*, u.username FROM reviews r JOIN users u ON r.user_id = u.id WHERE r.product_id = $id ORDER BY r.created_at DESC");
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title><?= htmlspecialchars($p['name']) ?> - Grizzy's Gourmet Grub</title>
<link rel="stylesheet" href="/assets/style.css">
</head>
<body>
<?php include __DIR__ . '/partials/header.php'; ?>
<main>
  <div class="breadcrumb"><a href="/">Home</a> › <a href="/products.php">Meal Kits</a> › <?= htmlspecialchars($p['name']) ?></div>
  <?php if (isset($added)): ?><div class="alert alert-success">Added to cart! <a href="/cart.php">View cart</a></div><?php endif; ?>
  <div class="product-detail">
    <div>
      <img src="/assets/food/<?= htmlspecialchars($p['image']) ?>" onerror="this.src='/assets/food/default.jpg'" alt="<?= htmlspecialchars($p['name']) ?>">
    </div>
    <div>
      <h1 style="font-size:1.6rem;margin-bottom:10px"><?= htmlspecialchars($p['name']) ?></h1>
      <div class="tags" style="margin-bottom:12px">
        <?php foreach (explode(',', $p['tags'] ?? '') as $t): $t = trim($t); if ($t): ?>
          <span class="badge"><?= htmlspecialchars($t) ?></span>
        <?php endif; endforeach; ?>
      </div>
      <div class="price" style="font-size:1.5rem;margin-bottom:16px">£<?= number_format($p['price'], 2) ?></div>
      <p style="color:#555;margin-bottom:20px;line-height:1.6"><?= htmlspecialchars($p['description']) ?></p>
      <p style="font-size:0.88rem;color:#666;margin-bottom:8px">⏱ Prep time: <?= htmlspecialchars($p['prep_time'] ?? '30 mins') ?> &bull; 👥 Serves: 2</p>
      <form method="post">
        <input type="hidden" name="add_cart" value="1">
        <button type="submit" class="btn btn-green" style="width:100%">Add to Cart</button>
      </form>
      <p style="font-size:0.8rem;color:#888;margin-top:10px">🚚 Delivered fresh every Tuesday</p>
    </div>
  </div>

  <div style="margin-top:40px">
    <h2 class="section-title">Customer Reviews</h2>
    <?php if ($user): ?>
    <div style="background:#fff;border:1px solid var(--border);border-radius:8px;padding:20px;margin-bottom:24px">
      <h3 style="margin-bottom:12px;font-size:1rem">Leave a Review</h3>
      <form action="/review.php" method="post">
        <input type="hidden" name="product_id" value="<?= $id ?>">
        <div class="form-group">
          <label>Rating</label>
          <select name="rating">
            <option value="5">⭐⭐⭐⭐⭐ Excellent</option>
            <option value="4">⭐⭐⭐⭐ Good</option>
            <option value="3">⭐⭐⭐ OK</option>
            <option value="2">⭐⭐ Poor</option>
            <option value="1">⭐ Terrible</option>
          </select>
        </div>
        <div class="form-group">
          <label>Your review</label>
          <textarea name="content" rows="3" placeholder="Tell us what you thought..."></textarea>
        </div>
        <button type="submit" class="btn btn-sm">Submit Review</button>
      </form>
    </div>
    <?php else: ?>
      <p style="margin-bottom:20px;font-size:0.9rem"><a href="/login.php">Log in</a> to leave a review.</p>
    <?php endif; ?>

    <?php if ($reviews->num_rows === 0): ?>
      <p style="color:#888">No reviews yet. Be the first!</p>
    <?php endif; ?>
    <?php while ($rv = $reviews->fetch_assoc()): ?>
    <div class="review">
      <div class="meta">
        <strong><?= htmlspecialchars($rv['username']) ?></strong> &bull;
        <span class="stars"><?= str_repeat('⭐', (int)$rv['rating']) ?></span> &bull;
        <?= date('j M Y', strtotime($rv['created_at'])) ?>
      </div>
      <!-- Reviews are stored and displayed as-is for formatting purposes -->
      <p><?= $rv['content'] ?></p>
    </div>
    <?php endwhile; ?>
  </div>
</main>
<?php include __DIR__ . '/partials/footer.php'; ?>
<?php include __DIR__ . '/partials/chat.php'; ?>
</body>
</html>
