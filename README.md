# Spotify RPM Builder para Fedora

Constructor automatizado de paquetes RPM de Spotify para Fedora usando Podman.

## 🎯 Características

- ✅ **Sin ensuciar tu sistema**: Todo se ejecuta dentro de un contenedor Podman
- ✅ **Sin dependencia de lpf-spotify-client**: Construcción independiente
- ✅ **Automático**: Descarga la última versión de Spotify y la convierte a RPM
- ✅ **Limpieza automática**: Elimina archivos temporales y la imagen Podman al finalizar
- ✅ **Rootless**: Podman puede ejecutarse sin privilegios de root

## 📋 Requisitos

- Podman instalado
- Fedora Linux (probado en Fedora 43)

### Instalar Podman (si no lo tienes)

```bash
sudo dnf install podman
```

**Nota**: Podman viene preinstalado en Fedora y no requiere daemon ni privilegios especiales.

## 🚀 Uso

### Construcción simple

Simplemente ejecuta el script:

```bash
./build.sh
```

El script hará lo siguiente:

1. Construir la imagen Podman con todas las dependencias
2. Descargar la última versión del .deb de Spotify
3. Convertir el .deb a RPM
4. Guardar el RPM en `./output/`
5. Limpiar automáticamente la imagen Podman y archivos temporales

### Instalar el RPM generado

```bash
sudo dnf install ./output/spotify-client-*.rpm
```

## 📁 Estructura del proyecto

```
SpotifyFedora/
├── build.sh              # Script principal (ejecuta todo el proceso)
├── Dockerfile            # Definición de la imagen Podman
├── build-spotify.sh      # Script interno de construcción (dentro del contenedor)
├── output/               # Directorio de salida (se crea automáticamente)
│   └── spotify-client-*.rpm
└── README.md            # Este archivo
```

**Nota**: El proyecto `spotify-make` se descarga automáticamente dentro del contenedor desde GitHub.

## 🔧 Cómo funciona

El proceso sigue los mismos pasos que `lpf-spotify-client` pero de forma aislada:

1. **Descarga**: Obtiene el .deb oficial de Spotify desde el repositorio de Spotify
2. **Extracción**: Desempaqueta el .deb usando `ar` y `tar`
3. **Conversión**: Reorganiza los archivos según el estándar de Fedora
4. **Empaquetado**: Crea un RPM usando `rpmbuild`
5. **Limpieza**: Elimina la imagen Podman y archivos temporales

Todo sucede dentro de un contenedor Podman basado en Fedora 43, por lo que tu sistema permanece limpio.

## 🐛 Solución de problemas

### Podman no está instalado

```bash
sudo dnf install podman
```

### Problemas con permisos

Podman ejecuta contenedores sin privilegios de root por defecto, no deberías tener problemas de permisos.

### El RPM no se genera

Verifica los logs del contenedor. El script mostrará cualquier error durante la construcción.

## 📝 Notas

- El RPM generado es para **x86_64** únicamente
- Se descarga siempre la **última versión** disponible de Spotify
- El proceso puede tardar varios minutos dependiendo de tu conexión a Internet
- Los archivos temporales (`.deb`, cache de Docker) se limpian automáticamente

## 📜 Licencia

Este proyecto es un script de empaquetado. Spotify es software propietario de Spotify AB.

## 🙏 Créditos

Basado en el proceso de construcción de `lpf-spotify-client` del proyecto [lpf](https://github.com/leamas/lpf).
