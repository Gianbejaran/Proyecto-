CREATE DATABASE MensajeriaProyecto
USE MensajeriaProyecto

CREATE TABLE Usuarios ( 
    UsuarioID INT PRIMARY KEY IDENTITY, 
    Nombre VARCHAR(100), 
    Telefono VARCHAR(15) UNIQUE,
    Email VARCHAR(100), 
    Rol VARCHAR(50) 
);

CREATE TABLE Contactos (
    ContactoID INT PRIMARY KEY IDENTITY,
    UsuarioID INT, 
    Nombre VARCHAR(100), 
    Telefono VARCHAR(15) UNIQUE, 
    Email VARCHAR(100), 
    FOREIGN KEY (UsuarioID) REFERENCES Usuarios(UsuarioID)
);

CREATE TABLE Grupos (
    GrupoID INT PRIMARY KEY IDENTITY,
    Nombre VARCHAR(100)
);

CREATE TABLE MiembrosGrupo (
    GrupoID INT,
    UsuarioID INT,
    PRIMARY KEY (GrupoID, UsuarioID),
    FOREIGN KEY (GrupoID) REFERENCES Grupos(GrupoID),
    FOREIGN KEY (UsuarioID) REFERENCES Usuarios(UsuarioID)
);

CREATE TABLE Mensajes (
    MensajeID INT PRIMARY KEY IDENTITY,
    RemitenteID INT,
    MensajeOriginal VARCHAR(MAX),   
    MensajeTraducido VARCHAR(MAX),  
    Contenido VARCHAR(MAX),          
    FechaEnvio DATETIME,
    FechaProgramada DATETIME NULL,
    FOREIGN KEY (RemitenteID) REFERENCES Usuarios(UsuarioID)
);


CREATE TABLE MensajesDestinatarios (
    MensajeID INT,
    DestinatarioID INT,
    Estado VARCHAR(20),
    FechaEstado DATETIME,
    PRIMARY KEY (MensajeID, DestinatarioID),
    FOREIGN KEY (MensajeID) REFERENCES Mensajes(MensajeID),
    FOREIGN KEY (DestinatarioID) REFERENCES Usuarios(UsuarioID)
);

CREATE TABLE Auditoria (
    AuditoriaID INT PRIMARY KEY IDENTITY,
    UsuarioID INT,
    Accion VARCHAR(100),
    Fecha DATETIME,
    Descripcion VARCHAR(255),
    FOREIGN KEY (UsuarioID) REFERENCES Usuarios(UsuarioID)
);

--PROCEDIMIENTOS DE ALMACENADO--

CREATE PROCEDURE sp_EnviarMensaje
    @RemitenteID INT,                  -- ID del usuario que envía el mensaje
    @Contenido VARCHAR(MAX),           -- Texto del mensaje a enviar
    @Destinatarios VARCHAR(MAX)        -- Lista de IDs de destinatarios separados por coma (ejemplo: '2,3,5')
AS
BEGIN
    SET NOCOUNT ON;                    -- Evita que el conteo de filas afectadas se muestre (mejora rendimiento)

    DECLARE @MensajeID INT;            -- Variable para guardar el ID del mensaje insertado
    DECLARE @FechaActual DATETIME = GETDATE();  -- Fecha y hora actual

    -- Insertar el mensaje en la tabla Mensajes
    INSERT INTO Mensajes (RemitenteID, Contenido, FechaEnvio)
    VALUES (@RemitenteID, @Contenido, @FechaActual);

    SET @MensajeID = SCOPE_IDENTITY(); -- Obtener el ID generado automáticamente del mensaje insertado

    -- Variables para el proceso de separación de IDs de destinatarios
    DECLARE @ID INT;                   -- Variable temporal para almacenar un ID de destinatario
    DECLARE @Pos INT = 1;              -- Posición inicial para buscar comas en la cadena
    DECLARE @DestinatariosTemp VARCHAR(MAX) = @Destinatarios + ','; -- Añadir coma al final para facilitar el procesamiento

    -- Ciclo para extraer cada ID separado por coma y hacer inserción en MensajesDestinatarios
    WHILE CHARINDEX(',', @DestinatariosTemp, @Pos) > 0
    BEGIN
        -- Extraer la subcadena entre @Pos y la siguiente coma, convertir a INT
        SET @ID = CAST(
            SUBSTRING(
                @DestinatariosTemp,
                @Pos,
                CHARINDEX(',', @DestinatariosTemp, @Pos) - @Pos
            ) AS INT
        );
        
        -- Insertar registro que relaciona el mensaje con el destinatario
        INSERT INTO MensajesDestinatarios (MensajeID, DestinatarioID, Estado, FechaEstado)
        VALUES (@MensajeID, @ID, 'Enviado', @FechaActual);
        
        -- Mover la posición justo después de la coma encontrada para la siguiente iteración
        SET @Pos = CHARINDEX(',', @DestinatariosTemp, @Pos) + 1;
    END

    -- Registrar la acción de envío en la tabla Auditoria para seguimiento
    INSERT INTO Auditoria (UsuarioID, Accion, Fecha, Descripcion)
    VALUES (
        @RemitenteID,
        'Envio de mensaje',
        @FechaActual,
        CONCAT('Envió el mensaje ID ', @MensajeID, ' a: ', @Destinatarios)
    );
END;

-- Procedimiento 2: Mostrar mensajes recibidos por un usuario
CREATE PROCEDURE sp_VerMensajesRecibidos 
    @UsuarioID INT -- Parámetro: ID del usuario que quiere ver sus mensajes recibidos
AS
BEGIN
    SET NOCOUNT ON; -- Evita que el servidor envíe mensajes adicionales sobre filas afectadas, optimiza ejecución

    SELECT 
        M.MensajeID,          -- ID del mensaje
        U.Nombre AS Remitente, -- Nombre del usuario que envió el mensaje
        M.Contenido,          -- Texto del mensaje
        M.FechaEnvio,         -- Fecha y hora en que se envió el mensaje
        MD.Estado,            -- Estado del mensaje para el destinatario (ej. 'Enviado', 'Leído')
        MD.FechaEstado        -- Fecha en que se actualizó el estado
    FROM MensajesDestinatarios MD -- Tabla que relaciona mensajes y destinatarios
    INNER JOIN Mensajes M ON MD.MensajeID = M.MensajeID -- Unimos para obtener detalles del mensaje
    INNER JOIN Usuarios U ON M.RemitenteID = U.UsuarioID -- Unimos para obtener el nombre del remitente
    WHERE MD.DestinatarioID = @UsuarioID -- Filtramos sólo los mensajes que llegaron al usuario
    ORDER BY M.FechaEnvio DESC; -- Ordenamos los mensajes desde el más reciente al más antiguo
END;


-- Procedimiento 3: Actualizar el estado de un mensaje recibido (por ejemplo, marcar como leído)
CREATE PROCEDURE sp_ActualizarEstadoMensaje
    @MensajeID INT,          -- ID del mensaje a actualizar
    @UsuarioID INT,          -- ID del usuario que está actualizando el estado
    @NuevoEstado VARCHAR(20) -- Nuevo estado que se asignará (ej. 'Leído', 'Archivado')
AS
BEGIN
    SET NOCOUNT ON; -- Evita mensajes extras de filas afectadas

    UPDATE MensajesDestinatarios
    SET Estado = @NuevoEstado, -- Cambia el estado del mensaje
        FechaEstado = GETDATE() -- Actualiza la fecha de cambio al momento actual
    WHERE MensajeID = @MensajeID AND DestinatarioID = @UsuarioID; -- Solo para ese usuario y mensaje específico

    -- Registrar esta acción en auditoría para control y seguimiento
    INSERT INTO Auditoria (UsuarioID, Accion, Fecha, Descripcion)
    VALUES (@UsuarioID, 'Actualización de estado', GETDATE(), 
           CONCAT('Mensaje ', @MensajeID, ' actualizado a "', @NuevoEstado, '"'));
END;


-- Procedimiento 4: Ver historial de auditoría de un usuario específico
CREATE PROCEDURE sp_VerHistorialAuditoria
    @UsuarioID INT -- ID del usuario cuyo historial queremos ver
AS
BEGIN
    SET NOCOUNT ON; -- Sin mensajes extras de filas afectadas

    SELECT 
        AuditoriaID, -- ID del registro de auditoría
        Accion,     -- Acción realizada
        Fecha,      -- Fecha y hora en que ocurrió la acción
        Descripcion -- Detalles adicionales sobre la acción
    FROM Auditoria
    WHERE UsuarioID = @UsuarioID -- Filtra solo registros del usuario dado
    ORDER BY Fecha DESC; -- Ordena desde el más reciente al más antiguo
END;




--TRIGGERS--



CREATE TRIGGER trg_Auditoria_EliminacionMensaje --Este trigger guarda un registro en la auditoría cada vez que se elimina un mensaje de la tabla Mensajes.
ON Mensajes
AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO Auditoria (UsuarioID, Accion, Fecha, Descripcion)
    SELECT 
        d.RemitenteID, -- Usuario que envió el mensaje eliminado
        'Eliminación de mensaje', 
        GETDATE(), 
        CONCAT('Se eliminó el mensaje con ID ', d.MensajeID, ': "', LEFT(d.MensajeTraducido, 100), '..."') 
    FROM deleted d; -- 'deleted' contiene los registros eliminados
END;

--Este trigger registra en la auditoría automáticamente cuando cambia el estado de un mensaje para un destinatario.

CREATE TRIGGER trg_Auditoria_EstadoMensaje
ON MensajesDestinatarios
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO Auditoria (UsuarioID, Accion, Fecha, Descripcion)
    SELECT 
        u.UsuarioID, -- El destinatario afectado
        'Cambio de estado de mensaje', 
        GETDATE(), 
        CONCAT('Estado del mensaje ', i.MensajeID, ' cambiado de "', d.Estado, '" a "', i.Estado, '"')
    FROM inserted i
    INNER JOIN deleted d ON i.MensajeID = d.MensajeID AND i.DestinatarioID = d.DestinatarioID
    INNER JOIN Usuarios u ON i.DestinatarioID = u.UsuarioID
    WHERE i.Estado <> d.Estado; -- Solo si realmente cambió el estado
END;




--FUNCIONES



-- 1. BUSCAR MENSAJES POR TEXTO
CREATE FUNCTION fn_BuscarMensajesPorTexto (@palabraClave NVARCHAR(100))
RETURNS TABLE
AS
RETURN (
    SELECT 
        M.MensajeID,
        U.Nombre AS Remitente,
        M.Contenido,
        M.FechaEnvio
    FROM Mensajes M
    INNER JOIN Usuarios U ON M.RemitenteID = U.UsuarioID
    WHERE M.Contenido LIKE '%' + @palabraClave + '%'
);



-- 2. BUSCAR MENSAJES POR FECHA
CREATE FUNCTION fn_BuscarMensajesPorFecha (@fecha DATE)
RETURNS TABLE
AS
RETURN (
    SELECT 
        M.MensajeID,
        U.Nombre AS Remitente,
        M.Contenido,
        M.FechaEnvio
    FROM Mensajes M
    INNER JOIN Usuarios U ON M.RemitenteID = U.UsuarioID
    WHERE CAST(M.FechaEnvio AS DATE) = @fecha
);


-- 3. BUSCAR MENSJAES POR REMITENTE (NOMBRE)
CREATE FUNCTION fn_BuscarMensajesPorRemitente (@nombreRemitente NVARCHAR(100))
RETURNS TABLE
AS
RETURN (
    SELECT 
        M.MensajeID,
        U.Nombre AS Remitente,
        M.Contenido,
        M.FechaEnvio
    FROM Mensajes M
    INNER JOIN Usuarios U ON M.RemitenteID = U.UsuarioID
    WHERE U.Nombre LIKE '%' + @nombreRemitente + '%'
);


-- 4. BUSQUEDA AVANZADA COMBINADA (TEXT, FECHA, REMITENTE)
CREATE FUNCTION fn_BuscarMensajesAvanzado (
    @palabraClave NVARCHAR(100) = NULL,
    @fecha DATE = NULL,
    @nombreRemitente NVARCHAR(100) = NULL
)
RETURNS TABLE
AS
RETURN (
    SELECT 
        M.MensajeID,
        U.Nombre AS Remitente,
        M.Contenido,
        M.FechaEnvio
    FROM Mensajes M
    INNER JOIN Usuarios U ON M.RemitenteID = U.UsuarioID
    WHERE (@palabraClave IS NULL OR M.Contenido LIKE '%' + @palabraClave + '%')
      AND (@fecha IS NULL OR CAST(M.FechaEnvio AS DATE) = @fecha)
      AND (@nombreRemitente IS NULL OR U.Nombre LIKE '%' + @nombreRemitente + '%')
);




--roles

-- Crear logins
CREATE LOGIN JuanLogin1 WITH PASSWORD = 'ContraseñaSegura123!';
CREATE LOGIN AdminLogin1 WITH PASSWORD = 'AdminSegura123!';

-- Crear usuarios de base de datos asociados a esos logins
CREATE USER Juan FOR LOGIN JuanLogin1;
CREATE USER Admin FOR LOGIN AdminLogin1;

-- Crear roles
CREATE ROLE rol_usuario1;
CREATE ROLE rol_admin1;

-- Asignar usuarios a roles
ALTER ROLE rol_usuario1 ADD MEMBER Juan;
ALTER ROLE rol_admin1 ADD MEMBER Admin;

-- Permisos para rol_usuario
GRANT SELECT, INSERT ON Mensajes TO rol_usuario1;
GRANT SELECT ON MensajesDestinatarios TO rol_usuario1;
GRANT EXECUTE ON sp_EnviarMensaje TO rol_usuario1;
GRANT EXECUTE ON sp_ActualizarEstadoMensaje TO rol_usuario1;

-- Permisos para rol_admin
GRANT SELECT, INSERT, UPDATE, DELETE ON Usuarios TO rol_admin1;
GRANT SELECT, INSERT, UPDATE, DELETE ON Mensajes TO rol_admin1;
GRANT SELECT, INSERT, UPDATE, DELETE ON MensajesDestinatarios TO rol_admin1;
GRANT SELECT, INSERT, UPDATE, DELETE ON Auditoria TO rol_admin1;

GRANT EXECUTE ON GestionarUsuarios TO rol_admin1;
GRANT EXECUTE ON sp_EnviarMensaje TO rol_admin1;
GRANT EXECUTE ON sp_ActualizarEstadoMensaje TO rol_admin1;




--TRANSACCIONES--



--Enviar mensaje

ALTER PROCEDURE sp_EnviarMensaje
    @RemitenteID INT,
    @Contenido VARCHAR(MAX),
    @Destinatarios VARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @MensajeID INT;
    DECLARE @FechaActual DATETIME = GETDATE();
    DECLARE @ID INT;
    DECLARE @Pos INT = 1;
    DECLARE @DestinatariosTemp VARCHAR(MAX) = @Destinatarios + ',';

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Insertar mensaje
        INSERT INTO Mensajes (RemitenteID, Contenido, FechaEnvio)
        VALUES (@RemitenteID, @Contenido, @FechaActual);

        SET @MensajeID = SCOPE_IDENTITY();

        -- Insertar destinatarios
        WHILE CHARINDEX(',', @DestinatariosTemp, @Pos) > 0
        BEGIN
            SET @ID = CAST(SUBSTRING(
                @DestinatariosTemp,
                @Pos,
                CHARINDEX(',', @DestinatariosTemp, @Pos) - @Pos
            ) AS INT);

            INSERT INTO MensajesDestinatarios (MensajeID, DestinatarioID, Estado, FechaEstado)
            VALUES (@MensajeID, @ID, 'Enviado', @FechaActual);

            SET @Pos = CHARINDEX(',', @DestinatariosTemp, @Pos) + 1;
        END

        -- Insertar auditoría
        INSERT INTO Auditoria (UsuarioID, Accion, Fecha, Descripcion)
        VALUES (
            @RemitenteID,
            'Envio de mensaje',
            @FechaActual,
            CONCAT('Envié el mensaje ID ', @MensajeID, ' a: ', @Destinatarios)
        );

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;

        THROW;
    END CATCH
END;


--Actualizar el estado del mensaje

ALTER PROCEDURE sp_ActualizarEstadoMensaje
    @MensajeID INT,
    @UsuarioID INT,
    @NuevoEstado VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE MensajesDestinatarios
        SET Estado = @NuevoEstado,
            FechaEstado = GETDATE()
        WHERE MensajeID = @MensajeID AND DestinatarioID = @UsuarioID;

        INSERT INTO Auditoria (UsuarioID, Accion, Fecha, Descripcion)
        VALUES (
            @UsuarioID,
            'Actualización de estado',
            GETDATE(),
            CONCAT('Mensaje ', @MensajeID, ' actualizado a "', @NuevoEstado, '"')
        );

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;

        THROW;
    END CATCH
END;




--INDEXS--

CREATE INDEX idx_Mensajes_FechaEnvio ON Mensajes(FechaEnvio);

CREATE INDEX idx_Destinatarios_Estado ON MensajesDestinatarios(Estado);

CREATE INDEX idx_Auditoria_UsuarioFecha ON Auditoria(UsuarioID, Fecha);

CREATE INDEX idx_Mensajes_RemitenteID ON Mensajes(RemitenteID);

CREATE INDEX idx_MensajesDestinatarios_MensajeID ON MensajesDestinatarios(MensajeID);

CREATE INDEX idx_MensajesDestinatarios_DestinatarioID ON MensajesDestinatarios(DestinatarioID);

CREATE INDEX idx_Usuarios_Nombre ON Usuarios(Nombre);

--CONSULTAS PARA VER LOS RESULTADOS--

-- consulta 1: Registrar usuario (ver usuarios)
SELECT UsuarioID, Nombre, Telefono, Email, Rol
FROM Usuarios;

-- consulta 2: Ver lista de usuarios (igual que función 1)
SELECT UsuarioID, Nombre, Telefono, Email, Rol
FROM Usuarios;

-- consulta 3: Enviar mensaje (ver mensajes enviados)
SELECT m.MensajeID, u.Nombre AS Remitente, m.Contenido, m.FechaEnvio, m.FechaProgramada
FROM Mensajes m
JOIN Usuarios u ON m.RemitenteID = u.UsuarioID
ORDER BY m.FechaEnvio DESC;

-- consulta 4: Ver mensajes enviados (detalle con destinatarios y estado)
SELECT m.MensajeID, u.Nombre AS Remitente, m.Contenido, m.FechaEnvio, md.Estado, du.Nombre AS Destinatario
FROM Mensajes m
JOIN Usuarios u ON m.RemitenteID = u.UsuarioID
JOIN MensajesDestinatarios md ON m.MensajeID = md.MensajeID
JOIN Usuarios du ON md.DestinatarioID = du.UsuarioID
ORDER BY m.FechaEnvio DESC;

-- consulta 5: Crear grupo (ver grupos)
SELECT GrupoID, Nombre
FROM Grupos;

-- consulta 6: Agregar usuario a grupo (ver miembros de grupos)
SELECT mg.GrupoID, g.Nombre AS NombreGrupo, mg.UsuarioID, u.Nombre AS NombreUsuario
FROM MiembrosGrupo mg
JOIN Grupos g ON mg.GrupoID = g.GrupoID
JOIN Usuarios u ON mg.UsuarioID = u.UsuarioID
ORDER BY mg.GrupoID;

-- consulta 7: Enviar mensaje a grupo (ver mensajes y destinatarios en grupo)
SELECT m.MensajeID, u.Nombre AS Remitente, m.Contenido, m.FechaEnvio, g.GrupoID, g.Nombre AS NombreGrupo
FROM Mensajes m
JOIN Usuarios u ON m.RemitenteID = u.UsuarioID
JOIN MensajesDestinatarios md ON m.MensajeID = md.MensajeID
JOIN MiembrosGrupo mg ON md.DestinatarioID = mg.UsuarioID
JOIN Grupos g ON mg.GrupoID = g.GrupoID
ORDER BY m.FechaEnvio DESC;

-- consulta 8: Ver historial de auditoría
SELECT a.AuditoriaID, u.Nombre AS Usuario, a.Accion, a.Fecha, a.Descripcion
FROM Auditoria a
JOIN Usuarios u ON a.UsuarioID = u.UsuarioID
ORDER BY a.Fecha DESC;

--consultas para borrar los datos de las tablas cuando deseemos--

DELETE FROM MensajesDestinatarios;
DELETE FROM Mensajes;
DELETE FROM MiembrosGrupo;
DELETE FROM Grupos;
DELETE FROM Auditoria;
DELETE FROM Usuarios;
DELETE FROM Mensajes;



--(JOB Y DIAGRAMA YA CREADO)--

--CODIGO DEL BACKUP--

BACKUP DATABASE [MensajeriaProyecto]
TO DISK = N'C:\mensajeria\MensajeriaProyectoA.bak'
WITH NOFORMAT, NOINIT, NAME = N'MensajeriaProyecto-Full Database Backup',
SKIP, NOREWIND, NOUNLOAD, STATS = 10;



