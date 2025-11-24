CREATE DATABASE IF NOT EXISTS techmarica_producao CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE techmarica_producao;

CREATE TABLE employees (
    employee_id INT AUTO_INCREMENT PRIMARY KEY,
    full_name VARCHAR(150) NOT NULL,
    role VARCHAR(80) NOT NULL,
    area VARCHAR(80) NOT NULL,
    email VARCHAR(150) UNIQUE,
    active BOOLEAN NOT NULL DEFAULT TRUE,
    hire_date DATE DEFAULT (CURRENT_DATE)
) ENGINE=InnoDB;

CREATE TABLE machines (
    machine_id INT AUTO_INCREMENT PRIMARY KEY,
    machine_code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(120) NOT NULL,
    location VARCHAR(100),
    status ENUM('OPERATIONAL','MAINTENANCE','INATIVA') NOT NULL DEFAULT 'OPERATIONAL',
    installed_date DATE DEFAULT (CURRENT_DATE)
) ENGINE=InnoDB;

CREATE TABLE products (
    product_id INT AUTO_INCREMENT PRIMARY KEY,
    product_code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    tech_lead_id INT,
    estimated_cost DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    created_at DATE NOT NULL DEFAULT (CURRENT_DATE),
    active BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT fk_products_techlead FOREIGN KEY (tech_lead_id) REFERENCES employees(employee_id) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE production_orders (
    order_id INT AUTO_INCREMENT PRIMARY KEY,
    product_id INT NOT NULL,
    machine_id INT NOT NULL,
    authorized_by_employee_id INT NOT NULL,
    start_date DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    end_date DATETIME DEFAULT NULL,
    quantity INT NOT NULL DEFAULT 1,
    status ENUM('EM PRODUÇÃO','PAUSADA','FINALIZADA','CANCELADA') NOT NULL DEFAULT 'EM PRODUÇÃO',
    batch_code VARCHAR(80),
    remarks TEXT,
    CONSTRAINT fk_orders_product FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_orders_machine FOREIGN KEY (machine_id) REFERENCES machines(machine_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_orders_authorizer FOREIGN KEY (authorized_by_employee_id) REFERENCES employees(employee_id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE INDEX idx_orders_status_start ON production_orders(status, start_date);

INSERT INTO employees (full_name, role, area, email, active, hire_date) VALUES
('Lucas Menezes', 'Engenheiro de Automação', 'Produção', 'lucas.menezes@techmarica.com', TRUE, '2020-02-11'),
('Marina Duarte', 'Técnica de Manutenção', 'Manutenção', 'marina.duarte@techmarica.com', TRUE, '2021-03-28'),
('Rafael Pires', 'Responsável Técnico', 'P&D', 'rafael.pires@techmarica.com', TRUE, '2017-08-14'),
('Ivana Rodrigues', 'Operadora de Linha', 'Produção', 'ivana.rodrigues@techmarica.com', FALSE, '2019-06-17'),
('Thiago Bezerra', 'Inspetor de Qualidade', 'Qualidade', 'thiago.bezerra@techmarica.com', TRUE, '2022-09-03');

INSERT INTO machines (machine_code, name, location, status, installed_date) VALUES
('MCX-4100', 'Soldadora Laser GX', 'Setor 1 - Galpão A', 'OPERATIONAL', '2018-03-12'),
('MCX-5100', 'Estação de Testes Omega', 'Setor 2 - Galpão B', 'MAINTENANCE', '2020-11-08'),
('MCX-6100', 'Montadora Automática ZR', 'Setor 3 - Galpão C', 'OPERATIONAL', '2021-07-22');

INSERT INTO products (product_code, name, tech_lead_id, estimated_cost, created_at, active) VALUES
('ELE-101', 'Módulo GPS Orion', 3, 42.90, '2019-02-15', TRUE),
('ELE-102', 'Sensor Magnético Vector', 1, 18.50, '2020-09-27', TRUE),
('ELE-103', 'Controlador Solar Helios', 3, 57.70, '2018-11-03', TRUE),
('ELE-104', 'Placa IoT Nimbus', 1, 26.40, '2021-04-19', TRUE),
('ELE-105', 'Medidor Digital Kronos', 3, 33.10, '2017-12-08', TRUE);

INSERT INTO production_orders (product_id, machine_id, authorized_by_employee_id, start_date, end_date, quantity, status, batch_code, remarks) VALUES
(1, 1, 1, '2025-10-12 08:15:00', '2025-10-12 16:50:00', 140, 'FINALIZADA', 'BT-20251012-A', NULL),
(2, 3, 3, '2025-11-03 07:10:00', NULL, 90, 'EM PRODUÇÃO', 'BT-20251103-B', NULL),
(3, 1, 1, '2025-08-22 09:30:00', '2025-08-22 14:05:00', 120, 'FINALIZADA', 'BT-20250822-C', NULL),
(4, 3, 5, '2025-11-14 10:20:00', NULL, 200, 'EM PRODUÇÃO', 'BT-20251114-D', NULL),
(5, 2, 2, '2025-07-09 06:55:00', '2025-07-09 12:40:00', 160, 'FINALIZADA', 'BT-20250709-E', NULL);

CREATE OR REPLACE VIEW vw_production_overview AS
SELECT
    o.order_id,
    o.batch_code,
    p.product_code,
    p.name AS product_name,
    p.estimated_cost,
    e.employee_id AS tech_lead_id,
    e.full_name AS tech_lead_name,
    m.machine_code,
    m.name AS machine_name,
    o.start_date,
    o.end_date,
    o.status,
    o.quantity,
    TIMESTAMPDIFF(MINUTE, o.start_date, COALESCE(o.end_date, NOW())) AS duration_minutes
FROM production_orders o
LEFT JOIN products p ON o.product_id = p.product_id
LEFT JOIN machines m ON o.machine_id = m.machine_id
LEFT JOIN employees e ON p.tech_lead_id = e.employee_id;

DELIMITER $$
CREATE PROCEDURE sp_create_production_order(
    IN p_product_id INT,
    IN p_authorized_by_employee_id INT,
    IN p_machine_id INT,
    IN p_quantity INT
)
BEGIN
    INSERT INTO production_orders (product_id, machine_id, authorized_by_employee_id, quantity, status)
    VALUES (p_product_id, p_machine_id, p_authorized_by_employee_id, p_quantity, 'EM PRODUÇÃO');

    SELECT LAST_INSERT_ID() AS new_order_id;
END$$
DELIMITER ;

DELIMITER $$
CREATE TRIGGER trg_orders_set_finalized_before_update
BEFORE UPDATE ON production_orders
FOR EACH ROW
BEGIN
    IF OLD.end_date IS NULL AND NEW.end_date IS NOT NULL THEN
        SET NEW.status = 'FINALIZADA';
    END IF;
END$$
DELIMITER ;
