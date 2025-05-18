CREATE TRIGGER trg_Auditoria_EliminacionMensaje --Este trigger guarda un registro en la auditor�a cada vez que se elimina un mensaje de la tabla Mensajes.
ON Mensajes
AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO Auditoria (UsuarioID, Accion, Fecha, Descripcion)
    SELECT 
        d.RemitenteID, -- Usuario que envi� el mensaje eliminado
        'Eliminaci�n de mensaje', 
        GETDATE(), 
        CONCAT('Se elimin� el mensaje con ID ', d.MensajeID, ': "', LEFT(d.Contenido, 100), '..."') 
    FROM deleted d; -- 'deleted' contiene los registros eliminados
END;

--Este trigger registra en la auditor�a autom�ticamente cuando cambia el estado de un mensaje para un destinatario.

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
    WHERE i.Estado <> d.Estado; -- Solo si realmente cambi� el estado
END;
