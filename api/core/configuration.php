<?php
require_once(__DIR__ . "/env.php");

Env::load(__DIR__ . "/.env");

#   SECURITY & SESSIONS
ini_set('session.cookie_secure', '1');
ini_set('session.cookie_httponly', '1');
ini_set('session.cookie_samesite', 'Strict');

if (session_status() === PHP_SESSION_NONE) {
    session_start();
}

#   ENVIRONMENT DEFINITIONS
define('COOKIE_NAME', Env::get('COOKIE_NAME'));
define('COOKIE_KEY', Env::get('COOKIE_KEY'));
define('COOKIE_LIFETIME', Env::get('COOKIE_LIFETIME'));
define('COOKIE_DOMAIN', Env::get('COOKIE_DOMAIN'));
define('COOKIE_SECURE', Env::get('COOKIE_SECURE'));
define('COOKIE_HTTPONLY', Env::get('COOKIE_HTTPONLY'));
define('COOKIE_SAMESITE', Env::get('COOKIE_SAMESITE'));


define("HOST_DB", Env::get('HOST_DB'));
define("USER_DB", Env::get('USER_DB'));
define("PASSWORD_DB", Env::get('PASSWORD_DB'));
define("DATABASE", Env::get('DATABASE'));
define("CHARSET", Env::get('CHARSET'));
