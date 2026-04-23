<?php
session_start();
require_once __DIR__ . '/../config/db.php';
$user = current_user();
if ($user) { header('Location: /account.php'); exit; }

$error = '';
$success = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $username = trim($_POST['username'] ?? '');
    $email    = trim($_POST['email'] ?? '');
    $pass     = trim($_POST['password'] ?? '');

    if (!$username || !$email || !$pass) {
        $error = 'Please fill in all fields.';
    } elseif (strlen($pass) < 6) {
        $error = 'Password must be at least 6 characters.';
    } else {
        $db = get_db();
        $e = $db->real_escape_string($email);
        $check = $db->query("SELECT id FROM users WHERE email = '$e'");
        if ($check->num_rows > 0) {
            $error = 'An account with that email already exists.';
        } else {
            $u  = $db->real_escape_string($username);
            $h  = md5($pass);
            $db->query("INSERT INTO users (username, email, password, created_at) VALUES ('$u', '$e', '$h', NOW())");
            $success = 'Account created! You can now <a href="/login.php">log in</a>.';
        }
    }
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Sign Up - Grizzy's Gourmet Grub</title>
<link rel="stylesheet" href="/assets/style.css">
</head>
<body>
<?php include __DIR__ . '/partials/header.php'; ?>
<main>
  <div class="form-box">
    <h2>Create an Account</h2>
    <?php if ($error): ?><div class="alert alert-error"><?= htmlspecialchars($error) ?></div><?php endif; ?>
    <?php if ($success): ?><div class="alert alert-success"><?= $success ?></div><?php endif; ?>
    <form method="post">
      <div class="form-group">
        <label>Username</label>
        <input type="text" name="username" required>
      </div>
      <div class="form-group">
        <label>Email address</label>
        <input type="email" name="email" required autocomplete="email">
      </div>
      <div class="form-group">
        <label>Password</label>
        <input type="password" name="password" required minlength="6">
      </div>
      <button type="submit" class="btn" style="width:100%">Create Account</button>
    </form>
    <p style="margin-top:14px;text-align:center;font-size:0.88rem">Already have an account? <a href="/login.php">Log in</a></p>
  </div>
</main>
<?php include __DIR__ . '/partials/footer.php'; ?>
</body>
</html>
