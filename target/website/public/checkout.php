<?php
session_start();
require_once __DIR__ . '/../config/db.php';
$user = current_user();

if (!$user) { header('Location: /login.php'); exit; }
$cart = $_SESSION['cart'] ?? [];
if (empty($cart)) { header('Location: /cart.php'); exit; }

$db = get_db();
$error = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $address = trim($_POST['address'] ?? '');
    if (!$address) {
        $error = 'Please enter a delivery address.';
    } else {
        $total = array_reduce($cart, fn($c, $i) => $c + ($i['price'] * $i['qty']), 0);
        $items_json = $db->real_escape_string(json_encode(array_values($cart)));
        $addr = $db->real_escape_string($address);
        $uid = (int)$user['id'];
        $delivery = date('Y-m-d', strtotime('next tuesday'));
        $db->query("INSERT INTO orders (user_id, items, total, status, delivery_date, address, created_at) VALUES ($uid, '$items_json', $total, 'pending', '$delivery', '$addr', NOW())");
        $_SESSION['cart'] = [];
        $oid = $db->insert_id;
        header("Location: /orders.php?id=$oid&placed=1");
        exit;
    }
}

$total = array_reduce($cart, fn($c, $i) => $c + ($i['price'] * $i['qty']), 0);
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Checkout - Grizzy's Gourmet Grub</title>
<link rel="stylesheet" href="/assets/style.css">
</head>
<body>
<?php include __DIR__ . '/partials/header.php'; ?>
<main>
  <div class="page-header"><h1>Checkout</h1></div>
  <?php if ($error): ?><div class="alert alert-error"><?= htmlspecialchars($error) ?></div><?php endif; ?>
  <div class="two-col">
    <div>
      <div style="background:#fff;border:1px solid var(--border);border-radius:8px;padding:24px">
        <h2 style="font-size:1.1rem;margin-bottom:16px">Delivery Details</h2>
        <form method="post">
          <div class="form-group">
            <label>Full delivery address</label>
            <textarea name="address" rows="3" placeholder="15 Example Street&#10;Sheffield&#10;S1 1AA" required></textarea>
          </div>
          <p style="font-size:0.85rem;color:#666;margin-bottom:16px">💳 Payment is collected on delivery. We accept cash and card.</p>
          <button type="submit" class="btn btn-green" style="width:100%">Place Order – £<?= number_format($total, 2) ?></button>
        </form>
      </div>
    </div>
    <div>
      <div style="background:#fff;border:1px solid var(--border);border-radius:8px;padding:20px">
        <h3 style="margin-bottom:14px">Your Order</h3>
        <?php foreach ($cart as $item): ?>
          <p style="margin-bottom:6px"><?= htmlspecialchars($item['name']) ?> — £<?= number_format($item['price'], 2) ?></p>
        <?php endforeach; ?>
        <hr style="margin:12px 0;border-color:var(--border)">
        <p><strong>Total: £<?= number_format($total, 2) ?></strong></p>
        <p style="font-size:0.82rem;color:#888;margin-top:6px">Delivery: Next Tuesday</p>
      </div>
    </div>
  </div>
</main>
<?php include __DIR__ . '/partials/footer.php'; ?>
</body>
</html>
