<?php

declare(strict_types=1);

require_once __DIR__ . '/configuration.php';
require_once __DIR__ . '/response.php';

function csrfToken(): string
{
    $cookie = (string)($_COOKIE[COOKIE_NAME] ?? '');
    return hash_hmac('sha256', 'csrf|' . $cookie, COOKIE_KEY);
}

function requireCsrfToken(): void
{
    $provided = (string)($_SERVER['HTTP_X_CSRF_TOKEN'] ?? '');
    if ($provided === '' || !hash_equals(csrfToken(), $provided)) {
        header('Content-Type: application/json; charset=utf-8');
        Response::json(-1, 'La solicitud de seguridad expiró. Recargue la página e inténtelo nuevamente.', [], 403);
    }
}
