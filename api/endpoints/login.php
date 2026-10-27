<?php

require_once __DIR__ . "/../models/login.php";
require_once __DIR__ . "/../core/connection.php";
require_once __DIR__ . "/../core/auth-middleware.php";

$connection = Connection::load();
$response   = new Response();
$method     = $_SERVER["REQUEST_METHOD"];

switch ($method) {
    case 'GET':
        # Al cargar la página: si la cookie es válida devuelve la sesión y un csrfToken nuevo
        $auth_data = checkAuth();
        if ($auth_data === null) {
            Response::error("Usuario no autenticado", -2);
        }

        Response::success([
            'id'        => $auth_data['id'],
            'username'  => $auth_data['username'],
            'name'      => $auth_data['name'],
            'roles'     => $auth_data['roles'],
            'isAdmin'   => $auth_data['isAdmin'],
            'csrfToken' => csrfToken(),
        ]);
        break;

    case 'POST':
        $loginData = [
            'identificador' => trim($_POST['identificador'] ?? ''),
            'contrasena'    => $_POST['contrasena'] ?? ''
        ];

        try {
            $login = new Login($connection, $response);
            $login->login($loginData);
        } catch (\Throwable $th) {
            Response::error("Error");
            //Response::debugError($th);
        }
        break;

    case 'DELETE':
        requireAuth();

        try {
            $login = new Login($connection, $response);
            $login->logout();
        } catch (\Throwable $th) {
            Response::error("Error");
            //Response::debugError($th);
        }
        break;

    default:
        Response::invalidMethod();
}
