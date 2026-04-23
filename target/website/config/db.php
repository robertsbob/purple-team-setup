<?php
// Database config - Gary 2023-09-12
// TODO: move this out of web root at some point

define('DB_HOST', '127.0.0.1');
define('DB_NAME', 'grizzy_db');
define('DB_USER', 'grizzy_app');
define('DB_PASS', 'grizzy2024!');

define('UPLOAD_DIR', __DIR__ . '/../public/uploads/');
define('UPLOAD_URL', '/uploads/');

define('OPENROUTER_KEY', getenv('OPENROUTER_KEY') ?: '');
define('OPENROUTER_MODEL', 'meta-llama/llama-3-8b-instruct');

function get_db() {
    static $conn = null;
    if ($conn === null) {
        $conn = new mysqli(DB_HOST, DB_USER, DB_PASS, DB_NAME);
        if ($conn->connect_error) {
            die("DB connection failed");
        }
        $conn->set_charset('utf8mb4');
    }
    return $conn;
}

function current_user() {
    if (isset($_SESSION['user_id'])) {
        $db = get_db();
        $id = (int)$_SESSION['user_id'];
        $r = $db->query("SELECT id, username, email, avatar FROM users WHERE id = $id");
        return $r ? $r->fetch_assoc() : null;
    }
    return null;
}
