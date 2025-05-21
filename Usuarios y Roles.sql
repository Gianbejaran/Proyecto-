-- Crear los roles necesarios
CREATE ROLE rol_usuario;
CREATE ROLE rol_admin;


-- Crear usuarios sin login (solo para esta base de datos)
CREATE USER Juan WITHOUT LOGIN;
CREATE USER Admin WITHOUT LOGIN;


-- Asignar los usuarios a sus roles correspondientes
ALTER ROLE rol_usuario ADD MEMBER Juan;
ALTER ROLE rol_admin ADD MEMBER Admin;


-- Permisos para el rol de usuario (solo enviar y ver mensajes)
GRANT SELECT, INSERT ON Mensajes TO rol_usuario;
GRANT EXECUTE ON EnviarMensaje TO rol_usuario;

-- Permisos para el rol de administrador (gestiona todo)
GRANT SELECT, INSERT, UPDATE, DELETE ON Usuarios TO rol_admin;
GRANT EXECUTE ON GestionarUsuarios TO rol_admin;

