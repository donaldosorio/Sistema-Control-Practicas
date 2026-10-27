<?php

declare(strict_types=1);
require_once __DIR__ . "/auth.php";
require_once __DIR__ . "/response.php";
require_once __DIR__ . "/csrf.php";
require_once __DIR__ . "/audit-log.php";

/**
 * Valida que el usuario esté autenticado y tenga un rol permitido.
 *
 * @param int|int[] $roles Roles permitidos (por ejemplo 1 o [1,2])
 * @return array Datos del usuario autenticado
 */
function requireAuth(int|array $roles = [])
{
    $data = checkAuth();
    if ($data === null) {
        Response::error("Usuario no autenticado", -2);
    }

    AuditLog::setUser($data);

    $method = strtoupper((string)($_SERVER['REQUEST_METHOD'] ?? 'GET'));
    if (!in_array($method, ['GET', 'HEAD', 'OPTIONS', 'QUERY'], true)) {
        requireCsrfToken();
    }
    if ($roles === [] || $roles === null) {
        return $data;
    }

    if (boolval($data['isAdmin'])) {
        return $data;
    }

    $rolesUsuario = explode(',', $data['roles']);
    $esValido = false;
    foreach ($rolesUsuario as $rolUsuario) {
        if (in_array(intval($rolUsuario), (array)$roles, true)) {
            $esValido = true;
            break;
        }
    }
    if (!$esValido) {
        Response::error("Usuario no autorizado");
    }

    return $data;
}
