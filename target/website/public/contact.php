<?php
session_start();
require_once __DIR__ . '/../config/db.php';
$user = current_user();
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Contact Us - Grizzy's Gourmet Grub</title>
<link rel="stylesheet" href="/assets/style.css">
</head>
<body>
<?php include __DIR__ . '/partials/header.php'; ?>
<main>
  <div class="page-header"><h1>Contact Us</h1></div>
  <div style="max-width:600px">
    <div style="background:#fff;border:1px solid var(--border);border-radius:8px;padding:24px;margin-bottom:20px">
      <p>📞 <strong>Phone:</strong> 0114 496 0022 (Mon–Fri 9am–5pm)</p>
      <p style="margin-top:10px">📧 <strong>Email:</strong> <a href="mailto:hello@grizzygourmetgrub.co.uk">hello@grizzygourmetgrub.co.uk</a></p>
      <p style="margin-top:10px">📍 <strong>Address:</strong> Unit 4, Kelham Island Industrial Park, Sheffield, S3 8RW</p>
    </div>
    <p style="color:#666;font-size:0.9rem">For order queries, use the chat widget in the bottom-right corner or email us. We aim to respond within one business day.</p>
  </div>
</main>
<?php include __DIR__ . '/partials/footer.php'; ?>
<?php include __DIR__ . '/partials/chat.php'; ?>
</body>
</html>
