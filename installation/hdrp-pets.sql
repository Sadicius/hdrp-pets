-- HDRP-PETS: Tablas principales para instalación manual
/* */ 
-- VERSION PARA REFACTORIZAR A UNA ESTRUCTURA MÁS COMPLETA
-- Tabla: pet_companions
CREATE TABLE IF NOT EXISTS `pet_companion` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `stable` VARCHAR(50) NOT NULL,
    `citizenid` VARCHAR(50) NOT NULL,         -- Dueño
    `companionid` VARCHAR(64) NOT NULL,          -- ID única de mascota
    `data` LONGTEXT NOT NULL,                 -- JSON agrupado (estructura completa de la mascota)
    `customization` LONGTEXT DEFAULT NULL,    -- JSON de componentes/props visuales
    `achievements` LONGTEXT DEFAULT NULL,     -- JSON de logros y progreso
    `active` TINYINT(1) DEFAULT 0,            -- Si está activa
    PRIMARY KEY (`id`),
    UNIQUE KEY `companionid` (`companionid`),
    KEY `citizenid` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


-- Tabla: pet_breeding (estructura robusta)
CREATE TABLE IF NOT EXISTS `pet_breeding` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `citizenid` VARCHAR(50) NOT NULL,         -- Dueño (jugador)
    `history` LONGTEXT DEFAULT NULL,          -- JSON: historial de eventos de cría [{date, action, petA, petB, offspring, notes}]
    `parents` LONGTEXT DEFAULT NULL,          -- JSON: [{petid, times_bred, offspring_ids[]}]
    `offspring` LONGTEXT DEFAULT NULL,        -- JSON: [{petid, parent_a, parent_b, date, notes}]
    `cooldown` BIGINT DEFAULT NULL,           -- Timestamp global de cooldown de cría para el jugador
    `last_breeding` BIGINT DEFAULT NULL,      -- Timestamp del último evento de cría
    `genealogy_cache` LONGTEXT DEFAULT NULL,  -- (opcional) JSON: cache de genealogía para acceso rápido
    PRIMARY KEY (`id`),
    KEY `citizenid` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

/* 
-- VERSION ACTUAL
-- Tabla: pet_companions
CREATE TABLE IF NOT EXISTS `pet_companions` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `stable` VARCHAR(50) NOT NULL,
    `citizenid` VARCHAR(50) NOT NULL,
    `companionid` VARCHAR(11) NOT NULL,
    `companiondata` LONGTEXT NOT NULL DEFAULT '{}',
    `components` LONGTEXT NOT NULL DEFAULT '{}',
    `wild` VARCHAR(11) DEFAULT NULL,
    `active` TINYINT(4) DEFAULT 0,
    `breedable` VARCHAR(50) DEFAULT NULL,
    `inBreed` VARCHAR(50) DEFAULT NULL,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
*/
