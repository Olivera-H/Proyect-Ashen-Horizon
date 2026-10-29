# Cómo obtener el APK de Ashen Horizon (solo con el móvil)

El APK se compila solo en GitHub; no necesitas PC ni Android Studio.

1. Abre el repositorio en el navegador del móvil (github.com/Olivera-H/Proyect-Ashen-Horizon) e inicia sesión.
2. Pestaña **Actions** → en la lista de la izquierda elige **Compilar APK Android** → **Run workflow** → **Run workflow**.
3. Espera 5–10 minutos (el círculo amarillo pasa a verde ✔).
4. Ve a la pestaña **Code** → a la derecha, **Releases** → **Ashen Horizon (APK Android)** → descarga **AshenHorizon.apk**.
5. Ábrelo desde Descargas. Android pedirá permitir "instalar apps desconocidas" para el navegador: acéptalo (solo esta vez) e instala.

Notas
- Es un APK de *depuración* firmado con una llave de pruebas: sirve para jugar e instalar en tu móvil, no para subir a Google Play.
- Cada vez que cambies el juego, vuelve a lanzar el workflow para generar un APK nuevo (instalar encima actualiza la app).
- Si el workflow falla (✖), abre el trabajo fallido y copia el final del registro para corregirlo.
- Para Google Play haría falta un `.aab` firmado con una llave propia (se puede añadir luego).
