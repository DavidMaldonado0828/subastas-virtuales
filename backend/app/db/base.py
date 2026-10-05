#Define la clase base para los modelos de SQLAlchemy. 
from sqlalchemy.orm import DeclarativeBase

#Esta clase se utiliza como base para todas las demás clases de modelos en la aplicación. Al heredar de esta clase, los modelos obtienen automáticamente las funcionalidades de SQLAlchemy.
class Base(DeclarativeBase):
    pass
