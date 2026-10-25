<?php

declare(strict_types=1);

/**
 * Bitácora central de cambios hechos desde el panel administrativo.
 *
 * Connection configura AuditedPDOStatement para que cada INSERT, UPDATE o
 * DELETE ejecutado por un usuario autenticado quede registrado sin tener que
 * repetir llamadas en cada endpoint.
 */
final class AuditLog
{
    private static ?string $user = null;
    private static bool $writing = false;

    public static function setUser(array $authData): void
    {
        $username = trim((string)($authData['username'] ?? ''));
        $name = trim((string)($authData['name'] ?? ''));
        self::$user = $username !== '' ? $username : ($name !== '' ? $name : null);
    }

    public static function record(
        PDO $connection,
        string $action,
        string $table,
        string|int $rowId,
        array $data
    ): void {
        if (self::$user === null || self::$writing || strtolower($table) === 'bitacora') {
            return;
        }

        self::$writing = true;
        try {
            $json = json_encode(
                self::redact($data),
                JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_THROW_ON_ERROR
            );
            $statement = $connection->prepare(
                'INSERT INTO bitacora (`user`, action, newDate, nameTable, idRowTable, dateEvent, status)
                 VALUES (:user, :action, :data, :table, :row_id, NOW(), 1)'
            );
            $statement->execute([
                ':user' => self::$user,
                ':action' => strtoupper($action),
                ':data' => $json,
                ':table' => $table,
                ':row_id' => (string)$rowId,
            ]);
        } finally {
            self::$writing = false;
        }
    }

    private static function redact(array $data): array
    {
        foreach ($data as $key => $value) {
            $normalizedKey = strtolower(ltrim((string)$key, ':'));
            if (str_contains($normalizedKey, 'password') || str_contains($normalizedKey, 'contrasena') || str_contains($normalizedKey, 'contraseña')) {
                $data[$key] = '[REDACTED]';
            } elseif (is_array($value)) {
                $data[$key] = self::redact($value);
            }
        }
        return $data;
    }
}

final class AuditedPDOStatement extends PDOStatement
{
    private Connection $connection;
    private string|false $insertId = false;

    /** ID generado por esta sentencia, antes del INSERT de la bitácora. */
    public function lastInsertId(): string|false
    {
        return $this->insertId;
    }

    protected function __construct(Connection $connection)
    {
        $this->connection = $connection;
    }

    public function execute(?array $params = null): bool
    {
        $this->insertId = false;
        $result = parent::execute($params);
        if (!$result || !preg_match('/^\s*(INSERT\s+INTO|UPDATE|DELETE\s+FROM)\s+`?([a-zA-Z0-9_]+)`?/i', $this->queryString, $match)) {
            return $result;
        }

        $verb = strtoupper(strtok($match[1], ' '));
        if ($verb === 'INSERT') {
            $this->insertId = $this->connection->lastInsertId();
        }
        $table = $match[2];
        $data = $params ?? [];
        $affectedRows = $this->rowCount();
        if ($affectedRows === 0) {
            return $result;
        }
        $rowId = self::findRowId($data);
        if ($verb === 'INSERT' && ($rowId === 'multiple' || $rowId === '')) {
            $rowId = $this->insertId ?: 'multiple';
        }

        $record = $this->findRecord($table, $rowId);
        AuditLog::record($this->connection, $verb, $table, $rowId, [
            'record' => $record,
            'changes' => $data,
            'affectedRows' => $affectedRows,
        ]);
        return $result;
    }

    private static function findRowId(array $params): string|int
    {
        foreach ([':id', 'id', ':codigo', 'codigo', ':row_id', 'row_id', ':event', 'event'] as $key) {
            if (array_key_exists($key, $params) && is_scalar($params[$key])) {
                return (string)$params[$key];
            }
        }
        return 'multiple';
    }

    private function findRecord(string $table, string|int $rowId): ?array
    {
        if ($rowId === '' || $rowId === 'multiple') {
            return null;
        }

        $primaryKey = $table === 'sismicidad' ? '_oid' : 'id';
        $statement = $this->connection->prepare(
            sprintf('SELECT * FROM `%s` WHERE `%s` = :audit_id LIMIT 1', $table, $primaryKey)
        );
        $statement->execute([':audit_id' => $rowId]);
        $record = $statement->fetch(PDO::FETCH_ASSOC);
        return $record ?: null;
    }
}
