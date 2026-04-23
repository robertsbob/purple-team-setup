<?php
session_start();
require_once __DIR__ . '/../config/db.php';
$user = current_user();

if (!$user) { header('Location: /login.php'); exit; }

$db = get_db();

// View single order
if (isset($_GET['id'])) {
    $oid = (int)$_GET['id'];
    // fetch order - show details to logged in users
    $r = $db->query("SELECT o.*, u.username, u.email FROM orders o JOIN users u ON o.user_id = u.id WHERE o.id = $oid");
    $order = $r ? $r->fetch_assoc() : null;
    if (!$order) { header('Location: /orders.php'); exit; }
    $items = json_decode($order['items'] ?? '[]', true);
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Order #<?= $oid ?> - Grizzy's Gourmet Grub</title>
<link rel="stylesheet" href="/assets/style.css">
</head>
<body>
<?php include __DIR__ . '/partials/header.php'; ?>
<main>
  <div class="breadcrumb"><a href="/orders.php">My Orders</a> › Order #<?= $oid ?></div>
  <div class="page-header"><h1>Order #<?= $oid ?></h1></div>
  <div class="two-col">
    <div>
      <div class="table-wrap">
        <table>
          <thead><tr><th>Item</th><th>Qty</th><th>Price</th></tr></thead>
          <tbody>
            <?php foreach ($items as $item): ?>
            <tr>
              <td><?= htmlspecialchars($item['name'] ?? '') ?></td>
              <td><?= (int)($item['qty'] ?? 1) ?></td>
              <td>£<?= number_format((float)($item['price'] ?? 0), 2) ?></td>
            </tr>
            <?php endforeach; ?>
          </tbody>
        </table>
      </div>
    </div>
    <div>
      <div style="background:#fff;border:1px solid var(--border);border-radius:8px;padding:20px">
        <p><strong>Status:</strong> <span class="status-badge status-<?= htmlspecialchars($order['status']) ?>"><?= ucfirst(htmlspecialchars($order['status'])) ?></span></p>
        <p style="margin-top:10px"><strong>Customer:</strong> <?= htmlspecialchars($order['username']) ?></p>
        <p style="margin-top:6px"><strong>Email:</strong> <?= htmlspecialchars($order['email']) ?></p>
        <p style="margin-top:6px"><strong>Total:</strong> £<?= number_format((float)$order['total'], 2) ?></p>
        <p style="margin-top:6px"><strong>Delivery:</strong> <?= htmlspecialchars($order['delivery_date'] ?? 'TBC') ?></p>
        <p style="margin-top:6px"><strong>Address:</strong> <?= htmlspecialchars($order['address'] ?? '') ?></p>
        <p style="margin-top:6px;font-size:0.82rem;color:#888">Placed: <?= date('j M Y H:i', strtotime($order['created_at'])) ?></p>
      </div>
    </div>
  </div>
</main>
<?php include __DIR__ . '/partials/footer.php'; ?>
</body>
</html>
<?php
    exit;
}

// List orders for current user
$orders = $db->query("SELECT * FROM orders WHERE user_id = " . (int)$user['id'] . " ORDER BY created_at DESC");
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>My Orders - Grizzy's Gourmet Grub</title>
<link rel="stylesheet" href="/assets/style.css">
</head>
<body>
<?php include __DIR__ . '/partials/header.php'; ?>
<main>
  <div class="page-header"><h1>My Orders</h1></div>
  <?php if ($orders->num_rows === 0): ?>
    <p style="color:#666">You haven't placed any orders yet. <a href="/products.php">Browse meal kits</a>.</p>
  <?php else: ?>
  <div class="table-wrap">
    <table>
      <thead><tr><th>Order #</th><th>Date</th><th>Items</th><th>Total</th><th>Status</th><th></th></tr></thead>
      <tbody>
        <?php while ($o = $orders->fetch_assoc()): $items = json_decode($o['items'] ?? '[]', true); ?>
        <tr>
          <td>#<?= $o['id'] ?></td>
          <td><?= date('j M Y', strtotime($o['created_at'])) ?></td>
          <td><?= count($items) ?> kit(s)</td>
          <td>£<?= number_format((float)$o['total'], 2) ?></td>
          <td><span class="status-badge status-<?= htmlspecialchars($o['status']) ?>"><?= ucfirst(htmlspecialchars($o['status'])) ?></span></td>
          <td><a href="/orders.php?id=<?= $o['id'] ?>" class="btn btn-sm btn-outline">View</a></td>
        </tr>
        <?php endwhile; ?>
      </tbody>
    </table>
  </div>
  <?php endif; ?>
</main>
<?php include __DIR__ . '/partials/footer.php'; ?>
</body>
</html>
