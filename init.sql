-- =============================================================================
-- SCRIPT DE BASE DE DATOS: FEED DE OPORTUNIDADES Y SEGUIMIENTO DE POSTULACIONES
-- Arquitectura: Monolito Modular con Control de Permisos de Publicación
-- Motor: MySQL 8.0+ / MariaDB 10.5+
-- Juego de caracteres: utf8mb4 | Colación: utf8mb4_unicode_ci
-- =============================================================================

CREATE DATABASE IF NOT EXISTS control_practicas_db
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE control_practicas_db;

SET FOREIGN_KEY_CHECKS = 0;

DROP TABLE IF EXISTS bitacora;
DROP TABLE IF EXISTS asignaciones_roles;
DROP TABLE IF EXISTS sesiones_usuario;
DROP TABLE IF EXISTS notificaciones;
DROP TABLE IF EXISTS mensajes_postulacion;
DROP TABLE IF EXISTS historial_estado_postulacion;
DROP TABLE IF EXISTS postulaciones;
DROP TABLE IF EXISTS solicitudes_publicacion;
DROP TABLE IF EXISTS oportunidades;
DROP TABLE IF EXISTS usuarios;
DROP TABLE IF EXISTS carreras;
DROP TABLE IF EXISTS instituciones;
DROP TABLE IF EXISTS roles;

SET FOREIGN_KEY_CHECKS = 1;

CREATE TABLE roles (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL UNIQUE COMMENT 'administrador, estudiante, reclutador',
    descripcion VARCHAR(255) NULL,
    estado TINYINT(1) NOT NULL DEFAULT 1 COMMENT '1: activo, 0: inactivo (soft delete)',
    creado_en DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE instituciones (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(150) NOT NULL UNIQUE,
    siglas VARCHAR(20) NULL,
    tipo ENUM('universidad', 'empresa', 'startup_estudiantil', 'otra') NOT NULL DEFAULT 'empresa',
    contacto_email VARCHAR(150) NULL,
    sitio_web VARCHAR(255) NULL,
    estado TINYINT(1) NOT NULL DEFAULT 1 COMMENT '1: activo, 0: inactivo (soft delete)',
    creado_en DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE carreras (
    id INT AUTO_INCREMENT PRIMARY KEY,
    institucion_id INT NOT NULL,
    nombre VARCHAR(150) NOT NULL,
    codigo VARCHAR(30) NULL,
    estado TINYINT(1) NOT NULL DEFAULT 1 COMMENT '1: activo, 0: inactivo (soft delete)',
    creado_en DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_id_institucion_carreta (institucion_id),
    CONSTRAINT fk_carreras_institucion FOREIGN KEY (institucion_id)
        REFERENCES instituciones(id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT uk_inst_carrera UNIQUE (institucion_id, nombre)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE usuarios (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    nombre VARCHAR(100) NOT NULL,
    apellido VARCHAR(100) NOT NULL,
    email VARCHAR(150) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    institucion_id INT NULL COMMENT 'FK a la institución/empresa registrada',
    carrera_id INT NULL COMMENT 'Aplica para estudiantes',
    carnet VARCHAR(30) NULL COMMENT 'Aplica para estudiantes',
    telefono VARCHAR(30) NULL,
    biografia TEXT NULL,
    autorizado_publicar TINYINT(1) NOT NULL DEFAULT 0 COMMENT '0: No autorizado a publicar ofertas, 1: Autorizado por admin',
    estado TINYINT(1) NOT NULL DEFAULT 1 COMMENT '1: activo, 0: inactivo (soft delete)',
    fecha_registro DATETIME DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_usuarios_institucion FOREIGN KEY (institucion_id)
        REFERENCES instituciones(id) ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_usuarios_carrera FOREIGN KEY (carrera_id)
        REFERENCES carreras(id) ON DELETE SET NULL ON UPDATE CASCADE,
    INDEX idx_usuarios_email (email),
    INDEX idx_usuarios_autorizado (autorizado_publicar)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE solicitudes_publicacion (
    id INT AUTO_INCREMENT PRIMARY KEY,
    usuario_id INT NOT NULL,
    nombre_organizacion_proyecto VARCHAR(150) NOT NULL COMMENT 'Ej: Startup campus, Empresa X',
    descripcion_actividades TEXT NOT NULL COMMENT 'Por qué requiere practicantes y qué tareas harán',
    documento_respaldo_url VARCHAR(255) NULL COMMENT 'PDF de constitución, carta firmada o carnet',
    estado_solicitud ENUM('pendiente', 'aprobada', 'rechazada') NOT NULL DEFAULT 'pendiente',
    estado TINYINT(1) NOT NULL DEFAULT 1 COMMENT '1: activo, 0: inactivo (soft delete)',
    comentario_admin TEXT NULL COMMENT 'Motivo de rechazo o instrucciones',
    revisado_por INT NULL COMMENT 'ID del administrador que revisó',
    fecha_solicitud DATETIME DEFAULT CURRENT_TIMESTAMP,
    fecha_revision DATETIME NULL,
    CONSTRAINT fk_solicitudes_usuario FOREIGN KEY (usuario_id)
        REFERENCES usuarios(id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_solicitudes_admin FOREIGN KEY (revisado_por)
        REFERENCES usuarios(id) ON DELETE SET NULL ON UPDATE CASCADE,
    INDEX idx_solicitudes_estado (estado_solicitud, fecha_solicitud)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE oportunidades (
    id INT AUTO_INCREMENT PRIMARY KEY,
    titulo VARCHAR(150) NOT NULL,
    descripcion TEXT NOT NULL,
    requisitos TEXT NULL,
    institucion_id INT NULL COMMENT 'Institución o Startup asociada',
    carrera_id INT NULL COMMENT 'Carrera objetivo para filtrar',
    modalidad ENUM('presencial', 'remoto', 'hibrido') NOT NULL DEFAULT 'presencial',
    ubicacion VARCHAR(150) NULL,
    fecha_publicacion DATE NOT NULL,
    fecha_cierre DATE NOT NULL,
    estado_oportunidad ENUM('activa', 'cerrada', 'cancelada') NOT NULL DEFAULT 'activa',
    estado TINYINT(1) NOT NULL DEFAULT 1 COMMENT '1: activo, 0: inactivo (soft delete)',
    creado_por INT NOT NULL COMMENT 'Usuario autorizado',
    creado_en DATETIME DEFAULT CURRENT_TIMESTAMP,
    visto BOOLEAN DEFAULT FALSE,
    CONSTRAINT fk_oportunidades_institucion FOREIGN KEY (institucion_id)
        REFERENCES instituciones(id) ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_oportunidades_carrera FOREIGN KEY (carrera_id)
        REFERENCES carreras(id) ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_oportunidades_creador FOREIGN KEY (creado_por)
        REFERENCES usuarios(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    -- Índice optimizado para el Feed: filtro por carrera, estado activo y fecha en orden descendente
    INDEX idx_feed_oportunidades (estado_oportunidad, carrera_id, fecha_publicacion DESC)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE postulaciones (
    id INT AUTO_INCREMENT PRIMARY KEY,
    oportunidad_id INT NOT NULL,
    estudiante_id INT NOT NULL,
    fecha_postulacion DATETIME DEFAULT CURRENT_TIMESTAMP,
    estado_postulacion ENUM('pendiente', 'en_revision', 'aceptada', 'rechazada') NOT NULL DEFAULT 'pendiente',
    estado TINYINT(1) NOT NULL DEFAULT 1 COMMENT '1: activo, 0: inactivo (soft delete)',
    cv_url VARCHAR(255) NOT NULL COMMENT 'PDF de hoja de vida',
    constancia_estudios_url VARCHAR(255) NULL COMMENT 'PDF opcional de constancia de materias/créditos',
    mensaje_presentacion TEXT NULL,
    CONSTRAINT fk_postulaciones_oportunidad FOREIGN KEY (oportunidad_id)
        REFERENCES oportunidades(id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_postulaciones_estudiante FOREIGN KEY (estudiante_id)
        REFERENCES usuarios(id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT uk_oportunidad_estudiante UNIQUE (oportunidad_id, estudiante_id),
    INDEX idx_postulaciones_estudiante (estudiante_id),
    INDEX idx_postulaciones_estado (estado_postulacion)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


CREATE TABLE historial_estado_postulacion (
    id INT AUTO_INCREMENT PRIMARY KEY,
    postulacion_id INT NOT NULL,
    estado_anterior VARCHAR(30) NOT NULL,
    estado_nuevo VARCHAR(30) NOT NULL,
    comentario TEXT NULL,
    actualizado_por INT NOT NULL,
    fecha DATETIME DEFAULT CURRENT_TIMESTAMP,
    estado TINYINT(1) NOT NULL DEFAULT 1 COMMENT '1: activo, 0: inactivo (soft delete)',
    CONSTRAINT fk_historial_postulacion FOREIGN KEY (postulacion_id)
        REFERENCES postulaciones(id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_historial_usuario FOREIGN KEY (actualizado_por)
        REFERENCES usuarios(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    INDEX idx_historial_postulacion (postulacion_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


CREATE TABLE notificaciones (
    id INT AUTO_INCREMENT PRIMARY KEY,
    usuario_id INT NOT NULL,
    titulo VARCHAR(150) NOT NULL,
    mensaje TEXT NOT NULL,
    leido TINYINT(1) NOT NULL DEFAULT 0,
    fecha_creacion DATETIME DEFAULT CURRENT_TIMESTAMP,
    estado TINYINT(1) NOT NULL DEFAULT 1 COMMENT '1: activo, 0: inactivo (soft delete)',
    CONSTRAINT fk_notificaciones_usuario FOREIGN KEY (usuario_id)
        REFERENCES usuarios(id) ON DELETE CASCADE ON UPDATE CASCADE,
    INDEX idx_notificaciones_usuario (usuario_id, leido)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE sesiones_usuario (
    id INT AUTO_INCREMENT PRIMARY KEY,
    usuario_id INT NOT NULL,
    refresh_token_hash CHAR(64) NOT NULL,
    user_agent VARCHAR(255) NULL,
    direccion_ip VARCHAR(45) NULL,
    expira_en DATETIME NOT NULL,
    revocado TINYINT(1) NOT NULL DEFAULT 0,
    creado_en TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    estado TINYINT(1) NOT NULL DEFAULT 1 COMMENT '1: activo, 0: inactivo (soft delete)',

    CONSTRAINT fk_sesiones_usuario
        FOREIGN KEY (usuario_id)
        REFERENCES usuarios (id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    INDEX idx_sesiones_refresh_token (refresh_token_hash),
    INDEX idx_sesiones_usuario_id (usuario_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Roles extra de un usuario (el principal sigue en usuarios.rol_id)
CREATE TABLE asignaciones_roles (
    id_usuario INT NOT NULL,
    id_rol INT NOT NULL,
    estado TINYINT(1) NOT NULL DEFAULT 1 COMMENT '1: activo, 0: inactivo (soft delete)',
    PRIMARY KEY (id_usuario, id_rol),
    CONSTRAINT fk_asignaciones_usuario FOREIGN KEY (id_usuario)
        REFERENCES usuarios(id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_asignaciones_rol FOREIGN KEY (id_rol)
        REFERENCES roles(id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Bitácora que llena api/core/audit-log.php en cada INSERT/UPDATE/DELETE
CREATE TABLE bitacora (
    id INT AUTO_INCREMENT PRIMARY KEY,
    `user` VARCHAR(100) NOT NULL,
    action VARCHAR(10) NOT NULL,
    newDate JSON NULL,
    nameTable VARCHAR(64) NOT NULL,
    idRowTable VARCHAR(64) NOT NULL,
    dateEvent DATETIME NOT NULL,
    status TINYINT(1) NOT NULL DEFAULT 1,
    INDEX idx_bitacora_tabla (nameTable, idRowTable)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- =============================================================================
-- Seed de datos iniciales para la base de datos control_practicas_db
-- Orden de inserción: roles -> instituciones -> carreras
-- =============================================================================

-- 1. ROLES (Valores permitidos por el ENUM: estudiante, administrador, reclutador)
INSERT INTO roles (id, nombre, descripcion) VALUES
(1, 'estudiante', 'Usuario común del sistema (USER)'),
(2, 'administrador', 'Administrador general del sistema (ADMIN)'),
(3, 'reclutador', 'Usuario reclutador o evaluador')
ON DUPLICATE KEY UPDATE nombre = VALUES(nombre), descripcion = VALUES(descripcion);

-- 2. INSTITUCIONES
INSERT INTO instituciones (id, nombre, siglas, tipo, contacto_email, sitio_web) VALUES
(1, 'Universidad Mariano Gálvez de Guatemala', 'UMG', 'universidad', 'info@umg.edu.gt', 'https://umg.edu.gt'),
(2, 'Universidad de San Carlos de Guatemala', 'USAC', 'universidad', 'informacion@usac.edu.gt', 'https://usac.edu.gt'),
(3, 'Instituto Nacional Central para Varones', 'IN3', 'otra', 'contacto@in3.edu.gt', 'https://in3.edu.gt')
ON DUPLICATE KEY UPDATE nombre = VALUES(nombre), siglas = VALUES(siglas), tipo = VALUES(tipo), contacto_email = VALUES(contacto_email), sitio_web = VALUES(sitio_web);

-- 3. CARRERAS
INSERT INTO carreras (id, institucion_id, nombre, codigo) VALUES
-- Carreras para UMG (institucion_id = 1)
(1, 1, 'Ingeniería en Sistemas de Información y Ciencias de la Computación', 'UMG-ISICC'),
(2, 1, 'Ingeniería Industrial', 'UMG-IND'),
(3, 1, 'Ingeniería Civil', 'UMG-CIV'),
(4, 1, 'Licenciatura en Ciencias Jurídicas y Sociales', 'UMG-DER'),
(5, 1, 'Licenciatura en Administración de Empresas', 'UMG-ADM'),

-- Carreras para USAC (institucion_id = 2)
(6, 2, 'Ingeniería en Ciencias y Sistemas', 'USAC-ICS'),
(7, 2, 'Ingeniería Mecánica Eléctrica', 'USAC-IME'),
(8, 2, 'Ingeniería Química', 'USAC-IQ'),
(9, 2, 'Médico y Cirujano', 'USAC-MED'),
(10, 2, 'Licenciatura en Auditoría y Contaduría Pública', 'USAC-CPA'),

-- Carreras/Especialidades para IN3 (institucion_id = 3)
(11, 3, 'Bachillerato en Ciencias y Letras con Orientación en Computación', 'IN3-BCLC'),
(12, 3, 'Perito en Electricidad Industrial', 'IN3-PEI'),
(13, 3, 'Perito en Electrónica Digital', 'IN3-PED'),
(14, 3, 'Perito en Mecánica Automotriz', 'IN3-PMA'),
(15, 3, 'Bachillerato Industrial y Perito en Dibujo Técnico de Ingeniería', 'IN3-BIPD')
ON DUPLICATE KEY UPDATE institucion_id = VALUES(institucion_id), nombre = VALUES(nombre), codigo = VALUES(codigo);
