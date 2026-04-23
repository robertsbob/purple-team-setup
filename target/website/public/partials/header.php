<?php
if (!isset($user)) { session_start(); require_once __DIR__ . '/../../config/db.php'; $user = current_user(); }
$cart_count = isset($_SESSION['cart']) ? array_sum(array_column($_SESSION['cart'], 'qty')) : 0;
?>
<header>
  <div class="header-inner">
    <a href="/" class="logo">Grizzy's <span>Gourmet Grub</span></a>
    <nav>
      <a href="/products.php">All Kits</a>
      <a href="/search.php">Search</a>
      <?php if ($user): ?>
        <a href="/account.php">My Account</a>
        <a href="/orders.php">My Orders</a>
        <a href="/logout.php">Log Out</a>
      <?php else: ?>
        <a href="/login.php">Log In</a>
        <a href="/register.php">Sign Up</a>
      <?php endif; ?>
      <a href="/cart.php">🛒<span class="cart-count"><?= $cart_count ?></span></a>
    </nav>
  </div>
</header>
