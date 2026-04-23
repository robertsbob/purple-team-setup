<?php
session_start();
require_once __DIR__ . '/../../config/db.php';

$error = '';
$success = '';
$step = 'request';

if (isset($_GET['token']) && isset($_GET['email'])) {
    $step = 'reset';
    $token    = $_GET['token'];
    $email    = $_GET['email'];

    // validate token - it should be md5(email . floor(time()/60))
    // we check current minute and the one before, in case of edge case
    $expected1 = md5($email . floor(time() / 60));
    $expected2 = md5($email . (floor(time() / 60) - 1));

    if ($token !== $expected1 && $token !== $expected2) {
        $error = 'Invalid or expired reset link.';
        $step = 'request';
    } elseif ($_SERVER['REQUEST_METHOD'] === 'POST') {
        $pass = trim($_POST['password'] ?? '');
        if (strlen($pass) < 6) {
            $error = 'Password must be at least 6 characters.';
        } else {
            $db = get_db();
            $e = $db->real_escape_string($email);
            $h = md5($pass);
            $db->query("UPDATE users SET password = '$h' WHERE email = '$e'");
            $success = 'Password updated! <a href="/login.php">Log in</a>.';
            $step = 'done';
        }
    }
} elseif ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['email'])) {
    $email = trim($_POST['email'] ?? '');
    $db = get_db();
    $e = $db->real_escape_string($email);
    $r = $db->query("SELECT id FROM users WHERE email = '$e'");
    if ($r && $r->num_rows > 0) {
        $token = md5($email . floor(time() / 60));
        $link = "http://{$_SERVER['HTTP_HOST']}/api/reset_password.php?email=" . urlencode($email) . "&token=$token";
        // gary: send by email properly later, for now just show link
        $success = "Reset link (dev mode): <a href='$link'>$link</a>";
    } else {
        $success = 'If that email is registered, a reset link has been sent.';
    }
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Reset Password - Grizzy's Gourmet Grub</title>
<link rel="stylesheet" href="/assets/style.css">
</head>
<body>
<?php include __DIR__ . '/../partials/header.php'; ?>
<main>
  <div class="form-box">
    <h2>Reset Password</h2>
    <?php if ($error): ?><div class="alert alert-error"><?= htmlspecialchars($error) ?></div><?php endif; ?>
    <?php if ($success): ?><div class="alert alert-success"><?= $success ?></div><?php endif; ?>

    <?php if ($step === 'request'): ?>
    <form method="post">
      <div class="form-group">
        <label>Email address</label>
        <input type="email" name="email" required>
      </div>
      <button type="submit" class="btn" style="width:100%">Send Reset Link</button>
    </form>
    <?php elseif ($step === 'reset'): ?>
    <form method="post">
      <div class="form-group">
        <label>New password</label>
        <input type="password" name="password" required minlength="6">
      </div>
      <button type="submit" class="btn" style="width:100%">Set New Password</button>
    </form>
    <?php endif; ?>
    <p style="margin-top:14px;text-align:center;font-size:0.88rem"><a href="/login.php">← Back to login</a></p>
  </div>
</main>
<?php include __DIR__ . '/../partials/footer.php'; ?>
</body>
</html>
