<?php
session_start();
require_once __DIR__ . '/../config/db.php';
$user = current_user();

if (isset($_POST['remove'])) {
    $rid = (int)$_POST['remove'];
    unset($_SESSION['cart'][$rid]);
}

$cart = $_SESSION['cart'] ?? [];
$total = array_reduce($cart, fn($c, $i) => $c + ($i['price'] * $i['qty']), 0);
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Cart - Grizzy's Gourmet Grub</title>
<link rel="stylesheet" href="/assets/style.css">
</head>
<body>
<?php include __DIR__ . '/partials/header.php'; ?>
<main>
  <div class="page-header"><h1>Your Cart</h1></div>
  <?php if (empty($cart)): ?>
    <p>Your cart is empty. <a href="/products.php">Browse meal kits</a>.</p>
  <?php else: ?>
  <div class="two-col">
    <div class="table-wrap">
      <table>
        <thead><tr><th>Kit</th><th>Price</th><th></th></tr></thead>
        <tbody>
          <?php foreach ($cart as $pid => $item): ?>
          <tr>
            <td><a href="/product.php?id=<?= $pid ?>"><?= htmlspecialchars($item['name']) ?></a></td>
            <td>£<?= number_format($item['price'], 2) ?></td>
            <td>
              <form method="post" style="display:inline">
                <input type="hidden" name="remove" value="<?= $pid ?>">
                <button class="btn btn-sm btn-outline" type="submit">Remove</button>
              </form>
            </td>
          </tr>
          <?php endforeach; ?>
        </tbody>
      </table>
    </div>
    <div style="background:#fff;border:1px solid var(--border);border-radius:8px;padding:20px">
      <h3 style="margin-bottom:14px">Order Summary</h3>
      <p><strong>Total:</strong> £<?= number_format($total, 2) ?></p>
      <p style="font-size:0.82rem;color:#888;margin-top:6px">Delivery: Tuesday</p>
      <?php if ($user): ?>
        <a href="/checkout.php" class="btn btn-green" style="width:100%;margin-top:14px;display:block;text-align:center">Checkout</a>
      <?php else: ?>
        <a href="/login.php" class="btn" style="width:100%;margin-top:14px;display:block;text-align:center">Log in to Checkout</a>
      <?php endif; ?>
    </div>
  </div>
  <?php endif; ?>
</main>
<?php include __DIR__ . '/partials/footer.php'; ?>
</body>
</html>
