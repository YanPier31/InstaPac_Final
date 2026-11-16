-- ==============================================================================
-- PROYECTO: InstaPac Microseguros
-- MOTOR: MySQL 8.0+ (Dockerizado en AWS EC2)
-- DESCRIPCIÓN: Script de creación de esquema de base de datos relacional.
-- ==============================================================================

-- 1. CONFIGURACIÓN INICIAL DEL ESQUEMA
CREATE DATABASE IF NOT EXISTS instapac_db
CHARACTER SET utf8mb4 
COLLATE utf8mb4_unicode_ci;

USE instapac_db;

-- 2. CREACIÓN DE TABLAS

-- TABLA 1: Clientes
CREATE TABLE IF NOT EXISTS Clientes (
    id_cliente INT AUTO_INCREMENT PRIMARY KEY,
    nombre_completo VARCHAR(150) NOT NULL,
    dni VARCHAR(8) UNIQUE NOT NULL,
    telefono VARCHAR(15),
    fecha_registro DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- TABLA 2: Usuarios
CREATE TABLE IF NOT EXISTS Usuarios (
    id_usuario INT AUTO_INCREMENT PRIMARY KEY,
    id_cliente INT UNIQUE, -- Garantiza relación 1:1 con Clientes. NULL para Administradores.
    correo_universitario VARCHAR(150) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    rol ENUM('Cliente', 'Administrador') NOT NULL DEFAULT 'Cliente',
    estado ENUM('Activo', 'Inactivo') NOT NULL DEFAULT 'Activo',
    fecha_creacion DATETIME DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_usuario_cliente 
        FOREIGN KEY (id_cliente) REFERENCES Clientes(id_cliente) 
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- TABLA 3: Equipos
CREATE TABLE IF NOT EXISTS Equipos (
    id_equipo INT AUTO_INCREMENT PRIMARY KEY,
    id_cliente INT NOT NULL,
    tipo_dispositivo ENUM('Laptop', 'Celular') NOT NULL,
    marca VARCHAR(50) NOT NULL,
    modelo VARCHAR(100) NOT NULL,
    nro_serie VARCHAR(100) UNIQUE,
    valor_declarado DECIMAL(10,2) NOT NULL,
    moneda CHAR(3) DEFAULT 'PEN',
    fecha_registro DATETIME DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_valor_positivo CHECK (valor_declarado > 0),
    CONSTRAINT fk_equipo_cliente 
        FOREIGN KEY (id_cliente) REFERENCES Clientes(id_cliente) 
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- TABLA 4: Solicitudes
CREATE TABLE IF NOT EXISTS Solicitudes (
    id_solicitud INT AUTO_INCREMENT PRIMARY KEY,
    id_equipo INT NOT NULL,
    fecha_solicitud DATETIME DEFAULT CURRENT_TIMESTAMP,
    estado ENUM('Pendiente', 'Aprobada', 'Rechazada') NOT NULL DEFAULT 'Pendiente',
    ruta_foto_evidencia VARCHAR(255) NOT NULL,
    observaciones TEXT,
    id_usuario_revisor INT,
    fecha_revision DATETIME NULL,
    CONSTRAINT fk_solicitud_equipo 
        FOREIGN KEY (id_equipo) REFERENCES Equipos(id_equipo) 
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_solicitud_revisor 
        FOREIGN KEY (id_usuario_revisor) REFERENCES Usuarios(id_usuario) 
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- TABLA 5: Polizas
CREATE TABLE IF NOT EXISTS Polizas (
    id_poliza INT AUTO_INCREMENT PRIMARY KEY,
    id_solicitud INT UNIQUE NOT NULL, -- Garantiza relación 1:1 con Solicitudes. Una póliza por equipo/solicitud.
    numero_poliza VARCHAR(50) UNIQUE NOT NULL,
    valor_asegurado DECIMAL(10,2) NOT NULL,
    prima_mensual DECIMAL(10,2) NOT NULL,
    moneda CHAR(3) DEFAULT 'PEN',
    deducible DECIMAL(10,2) NOT NULL,
    fecha_emision DATETIME DEFAULT CURRENT_TIMESTAMP,
    fecha_inicio DATE NOT NULL,
    fecha_fin DATE NOT NULL,
    estado ENUM('Pendiente de pago', 'Activa', 'Vencida', 'Cancelada') NOT NULL DEFAULT 'Pendiente de pago',
    CONSTRAINT chk_prima_positiva CHECK (prima_mensual >= 0),
    CONSTRAINT chk_deducible_positivo CHECK (deducible >= 0),
    CONSTRAINT chk_fechas_logicas CHECK (fecha_fin > fecha_inicio),
    CONSTRAINT fk_poliza_solicitud 
        FOREIGN KEY (id_solicitud) REFERENCES Solicitudes(id_solicitud) 
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- TABLA 6: Pagos
CREATE TABLE IF NOT EXISTS Pagos (
    id_pago INT AUTO_INCREMENT PRIMARY KEY,
    id_poliza INT NOT NULL,
    numero_cuota INT NOT NULL,
    monto DECIMAL(10,2) NOT NULL,
    moneda CHAR(3) DEFAULT 'PEN',
    metodo_pago VARCHAR(50) NOT NULL,
    estado_pago ENUM('Pendiente', 'Aprobado', 'Rechazado', 'Anulado') NOT NULL DEFAULT 'Pendiente',
    codigo_transaccion VARCHAR(100) UNIQUE,
    fecha_intento DATETIME DEFAULT CURRENT_TIMESTAMP,
    fecha_confirmacion DATETIME NULL,
    periodo_inicio DATE NOT NULL,
    periodo_fin DATE NOT NULL,
    CONSTRAINT chk_monto_positivo CHECK (monto > 0),
    CONSTRAINT chk_cuota_positiva CHECK (numero_cuota > 0),
    CONSTRAINT chk_periodos_pagos CHECK (periodo_fin > periodo_inicio),
    CONSTRAINT fk_pago_poliza 
        FOREIGN KEY (id_poliza) REFERENCES Polizas(id_poliza) 
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 3. CREACIÓN DE ÍNDICES PARA OPTIMIZACIÓN DE CONSULTAS
-- (Mejoran la velocidad de búsqueda en paneles de administración y login)
CREATE INDEX idx_usuarios_correo ON Usuarios(correo_universitario);
CREATE INDEX idx_equipos_cliente ON Equipos(id_cliente);
CREATE INDEX idx_solicitudes_estado ON Solicitudes(estado);
CREATE INDEX idx_polizas_estado ON Polizas(estado);
CREATE INDEX idx_pagos_poliza ON Pagos(id_poliza);
CREATE INDEX idx_pagos_estado ON Pagos(estado_pago);

-- ==============================================================================
-- FIN DEL SCRIPT
-- ==============================================================================-- ==============================================================================
-- PROYECTO: InstaPac Microseguros
-- MOTOR: MySQL 8.0+ (Dockerizado en AWS EC2)
-- DESCRIPCIÓN: Script de creación de esquema de base de datos relacional.
-- ==============================================================================

-- 1. CONFIGURACIÓN INICIAL DEL ESQUEMA
CREATE DATABASE IF NOT EXISTS instapac_db
CHARACTER SET utf8mb4 
COLLATE utf8mb4_unicode_ci;

USE instapac_db;

-- 2. CREACIÓN DE TABLAS

-- TABLA 1: Clientes
CREATE TABLE IF NOT EXISTS Clientes (
    id_cliente INT AUTO_INCREMENT PRIMARY KEY,
    nombre_completo VARCHAR(150) NOT NULL,
    dni VARCHAR(8) UNIQUE NOT NULL,
    telefono VARCHAR(15),
    fecha_registro DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- TABLA 2: Usuarios
CREATE TABLE IF NOT EXISTS Usuarios (
    id_usuario INT AUTO_INCREMENT PRIMARY KEY,
    id_cliente INT UNIQUE, -- Garantiza relación 1:1 con Clientes. NULL para Administradores.
    correo_universitario VARCHAR(150) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    rol ENUM('Cliente', 'Administrador') NOT NULL DEFAULT 'Cliente',
    estado ENUM('Activo', 'Inactivo') NOT NULL DEFAULT 'Activo',
    fecha_creacion DATETIME DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_usuario_cliente 
        FOREIGN KEY (id_cliente) REFERENCES Clientes(id_cliente) 
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- TABLA 3: Equipos
CREATE TABLE IF NOT EXISTS Equipos (
    id_equipo INT AUTO_INCREMENT PRIMARY KEY,
    id_cliente INT NOT NULL,
    tipo_dispositivo ENUM('Laptop', 'Celular') NOT NULL,
    marca VARCHAR(50) NOT NULL,
    modelo VARCHAR(100) NOT NULL,
    nro_serie VARCHAR(100) UNIQUE,
    valor_declarado DECIMAL(10,2) NOT NULL,
    moneda CHAR(3) DEFAULT 'PEN',
    fecha_registro DATETIME DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_valor_positivo CHECK (valor_declarado > 0),
    CONSTRAINT fk_equipo_cliente 
        FOREIGN KEY (id_cliente) REFERENCES Clientes(id_cliente) 
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- TABLA 4: Solicitudes
CREATE TABLE IF NOT EXISTS Solicitudes (
    id_solicitud INT AUTO_INCREMENT PRIMARY KEY,
    id_equipo INT NOT NULL,
    fecha_solicitud DATETIME DEFAULT CURRENT_TIMESTAMP,
    estado ENUM('Pendiente', 'Aprobada', 'Rechazada') NOT NULL DEFAULT 'Pendiente',
    ruta_foto_evidencia VARCHAR(255) NOT NULL,
    observaciones TEXT,
    id_usuario_revisor INT,
    fecha_revision DATETIME NULL,
    CONSTRAINT fk_solicitud_equipo 
        FOREIGN KEY (id_equipo) REFERENCES Equipos(id_equipo) 
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_solicitud_revisor 
        FOREIGN KEY (id_usuario_revisor) REFERENCES Usuarios(id_usuario) 
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- TABLA 5: Polizas
CREATE TABLE IF NOT EXISTS Polizas (
    id_poliza INT AUTO_INCREMENT PRIMARY KEY,
    id_solicitud INT UNIQUE NOT NULL, -- Garantiza relación 1:1 con Solicitudes. Una póliza por equipo/solicitud.
    numero_poliza VARCHAR(50) UNIQUE NOT NULL,
    valor_asegurado DECIMAL(10,2) NOT NULL,
    prima_mensual DECIMAL(10,2) NOT NULL,
    moneda CHAR(3) DEFAULT 'PEN',
    deducible DECIMAL(10,2) NOT NULL,
    fecha_emision DATETIME DEFAULT CURRENT_TIMESTAMP,
    fecha_inicio DATE NOT NULL,
    fecha_fin DATE NOT NULL,
    estado ENUM('Pendiente de pago', 'Activa', 'Vencida', 'Cancelada') NOT NULL DEFAULT 'Pendiente de pago',
    CONSTRAINT chk_prima_positiva CHECK (prima_mensual >= 0),
    CONSTRAINT chk_deducible_positivo CHECK (deducible >= 0),
    CONSTRAINT chk_fechas_logicas CHECK (fecha_fin > fecha_inicio),
    CONSTRAINT fk_poliza_solicitud 
        FOREIGN KEY (id_solicitud) REFERENCES Solicitudes(id_solicitud) 
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- TABLA 6: Pagos
CREATE TABLE IF NOT EXISTS Pagos (
    id_pago INT AUTO_INCREMENT PRIMARY KEY,
    id_poliza INT NOT NULL,
    numero_cuota INT NOT NULL,
    monto DECIMAL(10,2) NOT NULL,
    moneda CHAR(3) DEFAULT 'PEN',
    metodo_pago VARCHAR(50) NOT NULL,
    estado_pago ENUM('Pendiente', 'Aprobado', 'Rechazado', 'Anulado') NOT NULL DEFAULT 'Pendiente',
    codigo_transaccion VARCHAR(100) UNIQUE,
    fecha_intento DATETIME DEFAULT CURRENT_TIMESTAMP,
    fecha_confirmacion DATETIME NULL,
    periodo_inicio DATE NOT NULL,
    periodo_fin DATE NOT NULL,
    CONSTRAINT chk_monto_positivo CHECK (monto > 0),
    CONSTRAINT chk_cuota_positiva CHECK (numero_cuota > 0),
    CONSTRAINT chk_periodos_pagos CHECK (periodo_fin > periodo_inicio),
    CONSTRAINT fk_pago_poliza 
        FOREIGN KEY (id_poliza) REFERENCES Polizas(id_poliza) 
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 3. CREACIÓN DE ÍNDICES PARA OPTIMIZACIÓN DE CONSULTAS
-- (Mejoran la velocidad de búsqueda en paneles de administración y login)
CREATE INDEX idx_usuarios_correo ON Usuarios(correo_universitario);
CREATE INDEX idx_equipos_cliente ON Equipos(id_cliente);
CREATE INDEX idx_solicitudes_estado ON Solicitudes(estado);
CREATE INDEX idx_polizas_estado ON Polizas(estado);
CREATE INDEX idx_pagos_poliza ON Pagos(id_poliza);
CREATE INDEX idx_pagos_estado ON Pagos(estado_pago);

-- ==============================================================================
-- FIN DEL SCRIPT
-- ==============================================================================
