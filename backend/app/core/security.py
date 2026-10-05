#Este archivo contiene funciones de seguridad relacionadas con el hashing y la verificación de contraseñas.
from pwdlib import PasswordHash
#Se instancia un objeto PasswordHash recomendado para el hashing de contraseñas.
password_hasher = PasswordHash.recommended()

#Se toma la contraseña en texto plano y se genera un hash seguro utilizando el objeto PasswordHash.
def hash_password(password: str) -> str:
    return password_hasher.hash(password)

#Se toma la contraseña en texto plano y el hash de la contraseña almacenado, y se verifica si coinciden utilizando el objeto PasswordHash.
def verify_password(password: str, password_hash: str) -> bool:
    return password_hasher.verify(password, password_hash)
