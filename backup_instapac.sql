-- MySQL dump 10.13  Distrib 8.0.46, for Linux (x86_64)
--
-- Host: localhost    Database: instapac_db
-- ------------------------------------------------------
-- Server version	8.0.46

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!50503 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `Clientes`
--

DROP TABLE IF EXISTS `Clientes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `Clientes` (
  `id_cliente` int NOT NULL AUTO_INCREMENT,
  `nombre_completo` varchar(150) NOT NULL,
  `dni` varchar(8) NOT NULL,
  `telefono` varchar(15) DEFAULT NULL,
  `fecha_registro` datetime DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id_cliente`),
  UNIQUE KEY `dni` (`dni`)
) ENGINE=InnoDB AUTO_INCREMENT=6 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `Clientes`
--

LOCK TABLES `Clientes` WRITE;
/*!40000 ALTER TABLE `Clientes` DISABLE KEYS */;
INSERT INTO `Clientes` VALUES (1,'Yan Pier Huayascachi','76543210','987654321','2026-11-10 01:02:08'),(2,'Naomi Beteta ','60003483','924893002','2026-11-10 01:25:42'),(3,'Yan Pier Huayascachi Ñahuin','71803363','906334550','2026-11-10 04:45:53'),(5,'Yan Pol Huayascachi Ñahuin','71803364','906334550','2026-11-10 16:38:34');
/*!40000 ALTER TABLE `Clientes` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `Equipos`
--

DROP TABLE IF EXISTS `Equipos`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `Equipos` (
  `id_equipo` int NOT NULL AUTO_INCREMENT,
  `id_cliente` int NOT NULL,
  `tipo_dispositivo` enum('Laptop','Celular') NOT NULL,
  `marca` varchar(50) NOT NULL,
  `modelo` varchar(100) NOT NULL,
  `nro_serie` varchar(100) DEFAULT NULL,
  `valor_declarado` decimal(10,2) NOT NULL,
  `moneda` char(3) DEFAULT 'PEN',
  `fecha_registro` datetime DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id_equipo`),
  UNIQUE KEY `nro_serie` (`nro_serie`),
  KEY `idx_equipos_cliente` (`id_cliente`),
  CONSTRAINT `fk_equipo_cliente` FOREIGN KEY (`id_cliente`) REFERENCES `Clientes` (`id_cliente`) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `chk_valor_positivo` CHECK ((`valor_declarado` > 0))
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `Equipos`
--

LOCK TABLES `Equipos` WRITE;
/*!40000 ALTER TABLE `Equipos` DISABLE KEYS */;
INSERT INTO `Equipos` VALUES (1,3,'Celular','Apple','iPhone 13',NULL,1.00,'PEN','2026-11-10 04:57:53');
/*!40000 ALTER TABLE `Equipos` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `Pagos`
--

DROP TABLE IF EXISTS `Pagos`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `Pagos`
--

LOCK TABLES `Pagos` WRITE;
/*!40000 ALTER TABLE `Pagos` DISABLE KEYS */;
/*!40000 ALTER TABLE `Pagos` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `Polizas`
--

DROP TABLE IF EXISTS `Polizas`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
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
  `estado` enum('Pendiente de pago','Activa','Vencida','Cancelada') NOT NULL DEFAULT 'Pendiente de pago',
  PRIMARY KEY (`id_poliza`),
  UNIQUE KEY `id_solicitud` (`id_solicitud`),
  UNIQUE KEY `numero_poliza` (`numero_poliza`),
  KEY `idx_polizas_estado` (`estado`),
  CONSTRAINT `fk_poliza_solicitud` FOREIGN KEY (`id_solicitud`) REFERENCES `Solicitudes` (`id_solicitud`) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `chk_deducible_positivo` CHECK ((`deducible` >= 0)),
  CONSTRAINT `chk_fechas_logicas` CHECK ((`fecha_fin` > `fecha_inicio`)),
  CONSTRAINT `chk_prima_positiva` CHECK ((`prima_mensual` >= 0))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `Polizas`
--

LOCK TABLES `Polizas` WRITE;
/*!40000 ALTER TABLE `Polizas` DISABLE KEYS */;
/*!40000 ALTER TABLE `Polizas` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `Solicitudes`
--

DROP TABLE IF EXISTS `Solicitudes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
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
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `Solicitudes`
--

LOCK TABLES `Solicitudes` WRITE;
/*!40000 ALTER TABLE `Solicitudes` DISABLE KEYS */;
INSERT INTO `Solicitudes` VALUES (1,1,'2026-11-10 04:57:53','Aprobada','sin_foto.jpg','PAGADO|Yape / Tarjeta Online|10/11/2026 16:42',NULL,'2026-11-10 16:41:22');
/*!40000 ALTER TABLE `Solicitudes` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `Usuarios`
--

DROP TABLE IF EXISTS `Usuarios`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
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
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `Usuarios`
--

LOCK TABLES `Usuarios` WRITE;
/*!40000 ALTER TABLE `Usuarios` DISABLE KEYS */;
INSERT INTO `Usuarios` VALUES (2,3,'yanpiernahuin@gmail.com','scrypt:32768:8:1$guhKoL92FdKtD2jB$f638b6a654a5e3f5e58bd2654f2d7c1df6aacc3ede41fba38400adb14a93101cc9b702a8711461c69558efb03d6b9c6d7481c6d236e28a375f4cf7ef611de5d6','Cliente','Activo','2026-11-10 04:45:53'),(3,5,'administrador@gmail.com','scrypt:32768:8:1$jG02XAGdaW66DS7M$bbc25b4176c95f0e43a3731fd077ae72a1030e3e2544ad745b99ccf457e62abdcbc7d31b24f359ffb5d50c4a656a57d768c9b0c6ecaa5d5aab9bc60ae442d667','Administrador','Activo','2026-11-10 16:38:34');
/*!40000 ALTER TABLE `Usuarios` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2026-11-10 16:47:56
