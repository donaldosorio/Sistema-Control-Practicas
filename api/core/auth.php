<?php

declare(strict_types=1);

function checkAuth(): ?array
{
    if (empty($_COOKIE[COOKIE_NAME])) {
        return null;
    }

    $raw = $_COOKIE[COOKIE_NAME];

    // Debe venir EXACTAMENTE como "<b64>|<hex_signature>"
    $parts = explode('|', $raw, 2);
    if (count($parts) !== 2) {
        return null;
    }

    [$b64, $sig] = $parts;

    // Firma debe ser hex SHA-256 (64 chars) para evitar bypass raros
    if (!is_string($sig) || !preg_match('/^[a-f0-9]{64}$/i', $sig)) {
        return null;
    }

    // Decodificar Base64 en modo estricto
    $serialized = base64_decode($b64, true);
    if ($serialized === false) {
        return null;
    }

    // Recalcular HMAC y comparar en tiempo constante
    $calc = hash_hmac('sha256', $serialized, COOKIE_KEY);
    if (!hash_equals($calc, $sig)) {
        return null;
    }

    // Parsear JSON
    $data = json_decode($serialized, true, flags: JSON_THROW_ON_ERROR);
    if (!is_array($data)) {
        return null;
    }

    // Validaciones de tiempo (exp obligatorio, nbf opcional)
    $now = time();
    if (!isset($data['exp']) || !is_int($data['exp']) || $data['exp'] < $now) {
        return null;
    }

    if (isset($data['ip']) && strpos(($_SERVER['REMOTE_ADDR'] ?? ''), $data['ip']) !== 0) {
        return null;
    }

    return $data;
}
