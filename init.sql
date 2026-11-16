SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

DROP TABLE IF EXISTS `Siniestros`;
DROP TABLE IF EXISTS `Pagos`;
DROP TABLE IF EXISTS `Polizas`;
DROP TABLE IF EXISTS `Solicitudes`;
DROP TABLE IF EXISTS `Equipos`;
DROP TABLE IF EXISTS `Usuarios`;
DROP TABLE IF EXISTS `Clientes`;
DROP TABLE IF EXISTS `Catalogo_Dispositivos`;
DROP TABLE IF EXISTS `Parametros_Sistema`;

CREATE TABLE `Parametros_Sistema` (
  `clave` varchar(50) NOT NULL,
  `valor` varchar(100) NOT NULL,
  `descripcion` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`clave`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT INTO `Parametros_Sistema` (`clave`, `valor`, `descripcion`) VALUES
('PORCENTAJE_COBERTURA', '80', 'Porcentaje de reembolso sobre el valor de boleta en caso de robo (%)'),
('PORCENTAJE_PRIMA', '4', 'Porcentaje de cuota mensual sobre el valor de boleta (%)'),
('DIAS_MAX_BOLETA', '30', 'Antiguedad maxima permitida de la boleta de compra (dias)'),
('PLAZO_MAX_REEMBOLSO', '14', 'Plazo maximo compromiso para ejecutar el reembolso (dias)');

CREATE TABLE `Catalogo_Dispositivos` (
  `id_catalogo` int NOT NULL AUTO_INCREMENT,
  `tipo_dispositivo` enum('Laptop','Celular') NOT NULL,
  `marca` varchar(50) NOT NULL,
  `modelo` varchar(100) NOT NULL,
  `activo` tinyint(1) NOT NULL DEFAULT '1',
  PRIMARY KEY (`id_catalogo`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT INTO `Catalogo_Dispositivos` (`tipo_dispositivo`, `marca`, `modelo`, `activo`) VALUES
('Celular', 'Samsung', 'Galaxy A54', 1),
('Celular', 'Samsung', 'Galaxy A55 5G', 1),
('Celular', 'Samsung', 'Galaxy S23', 1),
('Celular', 'Apple', 'iPhone 13', 1),
('Celular', 'Apple', 'iPhone 15', 1),
('Celular', 'Xiaomi', 'Redmi Note 12', 1),
('Celular', 'Xiaomi', 'Xiaomi 13T', 1),
('Laptop', 'Apple', 'MacBook Air M2', 1),
('Laptop', 'Lenovo', 'ThinkPad E14', 1),
('Laptop', 'Lenovo', 'IdeaPad 3', 1),
('Laptop', 'Lenovo', 'Legion 5', 1),
('Laptop', 'HP', 'Pavilion 15', 1),
('Laptop', 'HP', 'ProBook 450', 1),
('Laptop', 'Asus', 'VivoBook 15', 1),
('Laptop', 'Asus', 'TUF Gaming F15', 1);

CREATE TABLE `Clientes` (
  `id_cliente` int NOT NULL AUTO_INCREMENT,
  `nombre_completo` varchar(150) NOT NULL,
  `dni` varchar(8) NOT NULL,
  `codigo_universitario` varchar(30) DEFAULT 'U20241001',
  `telefono` varchar(15) DEFAULT NULL,
  `cuenta_reembolso` varchar(120) DEFAULT 'Yape: 906334550',
  `fecha_registro` datetime DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id_cliente`),
  UNIQUE KEY `dni` (`dni`)
) ENGINE=InnoDB AUTO_INCREMENT=7 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT INTO `Clientes` (`id_cliente`, `nombre_completo`, `dni`, `codigo_universitario`, `telefono`, `cuenta_reembolso`, `fecha_registro`) VALUES
(1, 'Yan Pier Huayascachi', '76543210', '100124589', '987654321', 'Yape: 987654321', '2026-11-10 01:02:08'),
(2, 'Naomi Beteta', '60003483', '100128940', '924893002', 'Yape: 924893002', '2026-11-10 01:25:42'),
(3, 'Yan Pier Huayascachi Ñahuin', '71803363', '100130412', '906334550', 'Yape: 906334550 / BCP: 191-98451230-0-14', '2026-11-10 04:45:53'),
(5, 'Yan Pol Huayascachi Ñahuin', '71803364', '100130499', '906334550', 'Yape: 906334550', '2026-11-10 16:38:34'),
(6, 'Admin Corporativo', '92730133', 'ADM-0001', 'AD-CORP', 'Cuenta Corporativa', '2026-11-10 21:38:12');

CREATE TABLE `Usuarios` (
  `id_usuario` int NOT NULL AUTO_INCREMENT,
  `id_cliente` int DEFAULT NULL,
  `correo_universitario` varchar(150) NOT NULL,
  `password_hash` varchar(255) NOT NULL,
  `rol` enum('Cliente','Administrador') NOT NULL DEFAULT 'Cliente',
  `estado` enum('Activo','Inactivo') NOT NULL DEFAULT 'Activo',
  `fecha_creacion` datetime DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id_usuario`),
  UNIQUE KEY `correo_universitario` (`correo_universitario`),
  UNIQUE KEY `id_cliente` (`id_cliente`),
  KEY `idx_usuarios_correo` (`correo_universitario`),
  CONSTRAINT `fk_usuario_cliente` FOREIGN KEY (`id_cliente`) REFERENCES `Clientes` (`id_cliente`) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=6 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT INTO `Usuarios` (`id_usuario`, `id_cliente`, `correo_universitario`, `password_hash`, `rol`, `estado`, `fecha_creacion`) VALUES
(1, 2, 'naomi.beteta@cientifica.edu.pe', 'scrypt:32768:8:1$guhKoL92FdKtD2jB$f638b6a654a5e3f5e58bd2654f2d7c1df6aacc3ede41fba38400adb14a93101cc9b702a8711461c69558efb03d6b9c6d7481c6d236e28a375f4cf7ef611de5d6', 'Cliente', 'Activo', '2026-11-10 01:25:42'),
(2, 3, 'yanpiernahuin@gmail.com', 'scrypt:32768:8:1$guhKoL92FdKtD2jB$f638b6a654a5e3f5e58bd2654f2d7c1df6aacc3ede41fba38400adb14a93101cc9b702a8711461c69558efb03d6b9c6d7481c6d236e28a375f4cf7ef611de5d6', 'Cliente', 'Activo', '2026-11-10 04:45:53'),
(3, 5, 'administrador@gmail.com', 'scrypt:32768:8:1$jG02XAGdaW66DS7M$bbc25b4176c95f0e43a3731fd077ae72a1030e3e2544ad745b99ccf457e62abdcbc7d31b24f359ffb5d50c4a656a57d768c9b0c6ecaa5d5aab9bc60ae442d667', 'Administrador', 'Activo', '2026-11-10 16:38:34'),
(4, 6, 'admin_ad@instapac.local', 'scrypt:32768:8:1$NL9lOl24qJbAWFPM$975842638c9a323728ec0b04eba459ae8bc3448581519fc0b87d4937f4fd3fe9b5c238398491119b917751ed4f2699e0036a353f6ce697b30ab0f9e13ce60300', 'Administrador', 'Activo', '2026-11-10 21:38:12');

CREATE TABLE `Equipos` (
  `id_equipo` int NOT NULL AUTO_INCREMENT,
  `id_cliente` int NOT NULL,
  `tipo_dispositivo` enum('Laptop','Celular') NOT NULL,
  `marca` varchar(50) NOT NULL,
  `modelo` varchar(100) NOT NULL,
  `nro_serie` varchar(100) NOT NULL,
  `fecha_compra` date NOT NULL,
  `valor_declarado` decimal(10,2) NOT NULL,
  `moneda` char(3) DEFAULT 'PEN',
  `fecha_registro` datetime DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id_equipo`),
  UNIQUE KEY `nro_serie` (`nro_serie`),
  KEY `idx_equipos_cliente` (`id_cliente`),
  CONSTRAINT `fk_equipo_cliente` FOREIGN KEY (`id_cliente`) REFERENCES `Clientes` (`id_cliente`) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `chk_valor_positivo` CHECK ((`valor_declarado` >= 200))
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT INTO `Equipos` (`id_equipo`, `id_cliente`, `tipo_dispositivo`, `marca`, `modelo`, `nro_serie`, `fecha_compra`, `valor_declarado`, `moneda`, `fecha_registro`) VALUES
(1, 3, 'Laptop', 'Lenovo', 'Legion 5', 'SN-LEG5-8849201', DATE_SUB(CURDATE(), INTERVAL 10 DAY), 3500.00, 'PEN', '2026-11-10 04:57:53'),
(2, 3, 'Celular', 'Samsung', 'Galaxy A54', '358901247610294', DATE_SUB(CURDATE(), INTERVAL 5 DAY), 1400.00, 'PEN', '2026-11-12 10:20:00'),
(3, 3, 'Celular', 'Apple', 'iPhone 15', '354982109481203', DATE_SUB(CURDATE(), INTERVAL 3 DAY), 3200.00, 'PEN', '2026-11-15 18:10:00'),
(4, 2, 'Laptop', 'HP', 'Pavilion 15', 'SN-HPPAV-551920', DATE_SUB(CURDATE(), INTERVAL 12 DAY), 2500.00, 'PEN', '2026-11-08 09:15:00');

CREATE TABLE `Solicitudes` (
  `id_solicitud` int NOT NULL AUTO_INCREMENT,
  `id_equipo` int NOT NULL,
  `fecha_solicitud` datetime DEFAULT CURRENT_TIMESTAMP,
  `estado` enum('Pendiente','Aprobada','Rechazada') NOT NULL DEFAULT 'Pendiente',
  `ruta_foto_evidencia` varchar(255) NOT NULL,
  `observaciones` text,
  `id_usuario_revisor` int DEFAULT NULL,
  `fecha_revision` datetime DEFAULT NULL,
  PRIMARY KEY (`id_solicitud`),
  KEY `fk_solicitud_equipo` (`id_equipo`),
  KEY `fk_solicitud_revisor` (`id_usuario_revisor`),
  KEY `idx_solicitudes_estado` (`estado`),
  CONSTRAINT `fk_solicitud_equipo` FOREIGN KEY (`id_equipo`) REFERENCES `Equipos` (`id_equipo`) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `fk_solicitud_revisor` FOREIGN KEY (`id_usuario_revisor`) REFERENCES `Usuarios` (`id_usuario`) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT INTO `Solicitudes` (`id_solicitud`, `id_equipo`, `fecha_solicitud`, `estado`, `ruta_foto_evidencia`, `observaciones`, `id_usuario_revisor`, `fecha_revision`) VALUES
(1, 1, '2026-11-10 04:57:53', 'Aprobada', 'Boleta_SagaFalabella_B001-4821.pdf', 'Boleta e IMEI/Serie verificados conforme.', 3, '2026-11-10 16:41:22'),
(2, 2, '2026-11-12 10:20:00', 'Aprobada', 'Boleta_SamsungStore_F002-9104.pdf', 'Equipo nuevo dentro de los 30 dias.', 3, '2026-11-12 14:15:00'),
(3, 3, '2026-11-15 18:10:00', 'Pendiente', 'Boleta_iShop_B014-3329.pdf', 'En evaluacion tecnica de boleta e IMEI.', NULL, NULL),
(4, 4, '2026-11-08 09:15:00', 'Aprobada', 'Boleta_Ripley_B009-1120.pdf', 'Verificacion técnica aprobada.', 3, '2026-11-08 12:00:00');

CREATE TABLE `Polizas` (
  `id_poliza` int NOT NULL AUTO_INCREMENT,
  `id_solicitud` int NOT NULL,
  `numero_poliza` varchar(50) NOT NULL,
  `valor_asegurado` decimal(10,2) NOT NULL,
  `prima_mensual` decimal(10,2) NOT NULL,
  `moneda` char(3) DEFAULT 'PEN',
  `deducible` decimal(10,2) NOT NULL,
  `fecha_emision` datetime DEFAULT CURRENT_TIMESTAMP,
  `fecha_inicio` date NOT NULL,
  `fecha_fin` date NOT NULL,
  `estado` enum('Pendiente de pago','Activa','Suspendida','Vencida','Cancelada') NOT NULL DEFAULT 'Pendiente de pago',
  PRIMARY KEY (`id_poliza`),
  UNIQUE KEY `id_solicitud` (`id_solicitud`),
  UNIQUE KEY `numero_poliza` (`numero_poliza`),
  KEY `idx_polizas_estado` (`estado`),
  CONSTRAINT `fk_poliza_solicitud` FOREIGN KEY (`id_solicitud`) REFERENCES `Solicitudes` (`id_solicitud`) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `chk_deducible_positivo` CHECK ((`deducible` >= 0)),
  CONSTRAINT `chk_fechas_logicas` CHECK ((`fecha_fin` > `fecha_inicio`)),
  CONSTRAINT `chk_prima_positiva` CHECK ((`prima_mensual` >= 0))
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT INTO `Polizas` (`id_poliza`, `id_solicitud`, `numero_poliza`, `valor_asegurado`, `prima_mensual`, `moneda`, `deducible`, `fecha_emision`, `fecha_inicio`, `fecha_fin`, `estado`) VALUES
(1, 1, 'POL-001', 2800.00, 140.00, 'PEN', 700.00, '2026-11-10 16:41:22', CURDATE(), DATE_ADD(CURDATE(), INTERVAL 30 DAY), 'Activa'),
(2, 2, 'POL-002', 1120.00, 56.00, 'PEN', 280.00, '2026-11-12 14:15:00', CURDATE(), DATE_ADD(CURDATE(), INTERVAL 30 DAY), 'Pendiente de pago'),
(3, 4, 'POL-004', 2000.00, 100.00, 'PEN', 500.00, '2026-11-08 12:00:00', DATE_SUB(CURDATE(), INTERVAL 7 DAY), DATE_ADD(CURDATE(), INTERVAL 23 DAY), 'Activa');

CREATE TABLE `Pagos` (
  `id_pago` int NOT NULL AUTO_INCREMENT,
  `id_poliza` int NOT NULL,
  `numero_cuota` int NOT NULL,
  `monto` decimal(10,2) NOT NULL,
  `moneda` char(3) DEFAULT 'PEN',
  `metodo_pago` varchar(50) NOT NULL,
  `estado_pago` enum('Pendiente','Aprobado','Rechazado','Anulado') NOT NULL DEFAULT 'Pendiente',
  `codigo_transaccion` varchar(100) DEFAULT NULL,
  `fecha_intento` datetime DEFAULT CURRENT_TIMESTAMP,
  `fecha_confirmacion` datetime DEFAULT NULL,
  `periodo_inicio` date NOT NULL,
  `periodo_fin` date NOT NULL,
  PRIMARY KEY (`id_pago`),
  UNIQUE KEY `codigo_transaccion` (`codigo_transaccion`),
  KEY `idx_pagos_poliza` (`id_poliza`),
  KEY `idx_pagos_estado` (`estado_pago`),
  CONSTRAINT `fk_pago_poliza` FOREIGN KEY (`id_poliza`) REFERENCES `Polizas` (`id_poliza`) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `chk_cuota_positiva` CHECK ((`numero_cuota` > 0)),
  CONSTRAINT `chk_monto_positivo` CHECK ((`monto` > 0)),
  CONSTRAINT `chk_periodos_pagos` CHECK ((`periodo_fin` > `periodo_inicio`))
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT INTO `Pagos` (`id_pago`, `id_poliza`, `numero_cuota`, `monto`, `moneda`, `metodo_pago`, `estado_pago`, `codigo_transaccion`, `fecha_intento`, `fecha_confirmacion`, `periodo_inicio`, `periodo_fin`) VALUES
(1, 1, 1, 140.00, 'PEN', 'Yape / Transferencia', 'Aprobado', 'OP-YAPE-894120', '2026-11-10 16:45:00', '2026-11-10 17:00:00', CURDATE(), DATE_ADD(CURDATE(), INTERVAL 30 DAY)),
(2, 3, 1, 100.00, 'PEN', 'Yape / Transferencia', 'Aprobado', 'OP-YAPE-772319', '2026-11-08 13:10:00', '2026-11-08 14:00:00', DATE_SUB(CURDATE(), INTERVAL 7 DAY), DATE_ADD(CURDATE(), INTERVAL 23 DAY));

CREATE TABLE `Siniestros` (
  `id_siniestro` int NOT NULL AUTO_INCREMENT,
  `id_poliza` int NOT NULL,
  `fecha_incidente` date NOT NULL,
  `fecha_reporte` datetime DEFAULT CURRENT_TIMESTAMP,
  `nro_denuncia_policial` varchar(80) NOT NULL,
  `comisaria` varchar(120) NOT NULL,
  `archivo_denuncia` varchar(255) NOT NULL,
  `descripcion` text NOT NULL,
  `monto_reembolso` decimal(10,2) NOT NULL,
  `cuenta_destino` varchar(150) NOT NULL,
  `estado` enum('En revision','Aprobado','Reembolsado','Rechazado') NOT NULL DEFAULT 'En revision',
  `codigo_desembolso` varchar(100) DEFAULT NULL,
  `observaciones_admin` text,
  `fecha_resolucion` datetime DEFAULT NULL,
  PRIMARY KEY (`id_siniestro`),
  KEY `idx_siniestros_poliza` (`id_poliza`),
  CONSTRAINT `fk_siniestro_poliza` FOREIGN KEY (`id_poliza`) REFERENCES `Polizas` (`id_poliza`) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT INTO `Siniestros` (`id_siniestro`, `id_poliza`, `fecha_incidente`, `fecha_reporte`, `nro_denuncia_policial`, `comisaria`, `archivo_denuncia`, `descripcion`, `monto_reembolso`, `cuenta_destino`, `estado`, `codigo_desembolso`, `observaciones_admin`, `fecha_resolucion`) VALUES
(1, 3, DATE_SUB(CURDATE(), INTERVAL 2 DAY), NOW(), 'DEN-PNP-2026-9941', 'Comisaria Santa Anita', 'Denuncia_Policial_PNP_9941.pdf', 'Sustracción de mochila con laptop al salir de clases en avenida principal.', 2000.00, 'Yape: 924893002', 'En revision', NULL, 'En validacion de acta policial.', NULL);

SET FOREIGN_KEY_CHECKS = 1;
