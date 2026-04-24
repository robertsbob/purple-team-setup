<?php
session_start();
require_once __DIR__ . '/../config/db.php';
$user = current_user();
if (!$user) { header('Location: /login.php'); exit; }

$db = get_db();
$error = '';
$success = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_FILES['avatar'])) {
    $file = $_FILES['avatar'];
    $allowed_types = ['image/jpeg', 'image/png', 'image/gif'];

    if ($file['error'] === UPLOAD_ERR_INI_SIZE || $file['error'] === UPLOAD_ERR_FORM_SIZE) {
        $error = 'File too large (max 2MB).';
    // check the file type the browser says it is
    } elseif (!in_array($file['type'], $allowed_types)) {
        $error = 'Only JPG, PNG and GIF images are allowed.';
    } elseif ($file['size'] > 2 * 1024 * 1024) {
        $error = 'File too large (max 2MB).';
    } else {
        $ext = pathinfo($file['name'], PATHINFO_EXTENSION);
        $filename = 'avatar_' . $user['id'] . '_' . time() . '.' . $ext;
        $dest = UPLOAD_DIR . $filename;
        if (move_uploaded_file($file['tmp_name'], $dest)) {
            $db->query("UPDATE users SET avatar = '" . $db->real_escape_string($filename) . "' WHERE id = " . (int)$user['id']);
            $success = 'Profile picture updated!';
            $user = current_user();
        } else {
            $error = 'Upload failed. Please try again.';
        }
    }
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>My Account - Grizzy's Gourmet Grub</title>
<link rel="stylesheet" href="/assets/style.css">
</head>
<body>
<?php include __DIR__ . '/partials/header.php'; ?>
<main>
  <div class="page-header"><h1>My Account</h1></div>
  <div class="two-col">
    <div>
      <div style="background:#fff;border:1px solid var(--border);border-radius:8px;padding:24px;margin-bottom:24px">
        <h2 style="font-size:1.1rem;margin-bottom:16px">Account Details</h2>
        <p><strong>Username:</strong> <?= htmlspecialchars($user['username']) ?></p>
        <p style="margin-top:8px"><strong>Email:</strong> <?= htmlspecialchars($user['email']) ?></p>
      </div>

      <div style="background:#fff;border:1px solid var(--border);border-radius:8px;padding:24px">
        <h2 style="font-size:1.1rem;margin-bottom:16px">Profile Picture</h2>
        <?php if ($error): ?><div class="alert alert-error"><?= htmlspecialchars($error) ?></div><?php endif; ?>
        <?php if ($success): ?><div class="alert alert-success"><?= htmlspecialchars($success) ?></div><?php endif; ?>
        <?php if ($user['avatar']): ?>
          <img src="/uploads/<?= htmlspecialchars($user['avatar']) ?>" style="width:80px;height:80px;border-radius:50%;object-fit:cover;margin-bottom:12px;border:2px solid var(--border)" alt="Avatar">
        <?php endif; ?>
        <form method="post" enctype="multipart/form-data">
          <div class="form-group">
            <label>Upload new picture (JPG, PNG, GIF)</label>
            <input type="file" name="avatar" accept="image/*">
          </div>
          <button type="submit" class="btn btn-sm">Upload</button>
        </form>
      </div>
    </div>
    <div>
      <div style="background:#fff;border:1px solid var(--border);border-radius:8px;padding:24px">
        <h2 style="font-size:1.1rem;margin-bottom:16px">Quick Links</h2>
        <ul style="list-style:none;line-height:2">
          <li><a href="/orders.php">📦 View My Orders</a></li>
          <li><a href="/products.php">🥗 Browse Meal Kits</a></li>
          <li><a href="/logout.php">🚪 Log Out</a></li>
        </ul>
      </div>
    </div>
  </div>
</main>
<?php include __DIR__ . '/partials/footer.php'; ?>
</body>
</html>
