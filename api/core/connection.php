<?php
require_once(__DIR__  .  "/configuration.php");
require_once(__DIR__  .  "/response.php");
require_once(__DIR__  .  "/audit-log.php");

date_default_timezone_set("America/Guatemala");

class Connection extends PDO
{

    public static ?Connection $loaded = null;

public function __construct()

    {
        try {
            $dsn = "mysql:host=" . HOST_DB . ";dbname=" . DATABASE . ";charset=" . CHARSET;
            parent::__construct($dsn, USER_DB, PASSWORD_DB);
            $this->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
            $this->setAttribute(PDO::ATTR_STATEMENT_CLASS, [AuditedPDOStatement::class, [$this]]);
        } catch (PDOException $e) {
            Response::error("Ocurrio un error", -1, 400);
            //Response::debugError($e);
        }
    }
    public static function load() {
        if (self::$loaded === null) {
            self::$loaded = new Connection();
        }
        return self::$loaded;

    }
}
