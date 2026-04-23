<?php
session_start();
require_once __DIR__ . '/../config/db.php';
$user = current_user();
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Privacy Policy - Grizzy's Gourmet Grub</title>
<link rel="stylesheet" href="/assets/style.css">
</head>
<body>
<?php include __DIR__ . '/partials/header.php'; ?>
<main>
  <div class="page-header"><h1>Privacy Policy</h1></div>
  <div style="max-width:720px;line-height:1.7">
    <p style="color:#888;margin-bottom:20px">Last updated: 14 March 2024</p>
    <h2 style="font-size:1.1rem;margin-bottom:8px">What we collect</h2>
    <p>We collect your name, email address, and delivery address when you place an order. We also collect information about your orders to fulfil deliveries.</p>
    <h2 style="font-size:1.1rem;margin:20px 0 8px">How we use it</h2>
    <p>We use your information only to process and deliver your meal kit orders. We do not sell your data to third parties.</p>
    <h2 style="font-size:1.1rem;margin:20px 0 8px">Contact</h2>
    <p>Questions? Email us at <a href="mailto:hello@grizzygourmetgrub.co.uk">hello@grizzygourmetgrub.co.uk</a></p>
  </div>
</main>
<?php include __DIR__ . '/partials/footer.php'; ?>
</body>
</html>
