<?php
session_start();
require_once __DIR__ . '/../config/db.php';
$user = current_user();
if ($user) { header('Location: /account.php'); exit; }

$error = '';
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $email = trim($_POST['email'] ?? '');
    $pass  = trim($_POST['password'] ?? '');
    if ($email && $pass) {
        $db = get_db();
        $hash = md5($pass);
        $e = $db->real_escape_string($email);
        $r = $db->query("SELECT id, username FROM users WHERE email = '$e' AND password = '$hash' LIMIT 1");
        if ($r && $r->num_rows > 0) {
            $row = $r->fetch_assoc();
            $_SESSION['user_id'] = $row['id'];
            header('Location: /account.php');
            exit;
        } else {
            $error = 'Invalid email or password.';
        }
    } else {
        $error = 'Please fill in all fields.';
    }
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Log In - Grizzy's Gourmet Grub</title>
<link rel="stylesheet" href="/assets/style.css">
</head>
<body>
<?php include __DIR__ . '/partials/header.php'; ?>
<main>
  <div class="form-box">
    <h2>Log In</h2>
    <?php if ($error): ?><div class="alert alert-error"><?= htmlspecialchars($error) ?></div><?php endif; ?>
    <form method="post">
      <div class="form-group">
        <label>Email address</label>
        <input type="email" name="email" required autocomplete="email">
      </div>
      <div class="form-group">
        <label>Password</label>
        <input type="password" name="password" required>
      </div>
      <button type="submit" class="btn" style="width:100%">Log In</button>
    </form>
    <p style="margin-top:14px;text-align:center;font-size:0.88rem">
      No account? <a href="/register.php">Sign up free</a> &bull;
      <a href="/api/reset_password.php">Forgot password?</a>
    </p>
  </div>
</main>
<?php include __DIR__ . '/partials/footer.php'; ?>
</body>
</html>
