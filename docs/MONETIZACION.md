# Cómo cobrar las mascotas premium (compra real)

Ahora mismo `Premium.DEMO = true` en `scripts/premium.gd`: "comprar" desbloquea gratis y el panel muestra **MODO DEMO**. Es solo para probar el flujo. Para cobrar de verdad:

1. **Cuenta de desarrollador de Google Play** (pago único de 25 USD) y la app publicada como AAB (el APK de `docs/APK.md` sirve para pruebas; Play exige AAB para publicar).
2. **Play Console → Monetizar → Productos integrados**: crea 4 productos *no consumibles* con los ID de `Pets.LIST[*].sku`: `pet_ceniza`, `pet_sombra`, `pet_presagio`, `pet_ambar`, y fija el precio de cada uno.
3. **Plugin Godot Google Play Billing** (`GodotGooglePlayBilling`, instalado en la plantilla Android de Godot 4.3). Implementa `Premium._store_purchase(sku)`: conectar, `purchase(sku)`, esperar `purchase_updated`, hacer `acknowledge_purchase` y devolver `true`. Al abrir el juego, consulta `queryPurchases` y vuelve a conceder lo ya comprado (restaurar compras).
4. **Valida el recibo en un servidor** (Google Play Developer API `purchases.products.get`). Lo guardado en `user://premium.cfg` se puede editar en un móvil con root; sin validación en servidor, cualquiera puede desbloquear gratis.
5. Pon `DEMO := false` antes de publicar.

Notas:
- La versión web de GitHub Pages **no** puede cobrar con Google Play; allí solo sirve el modo demo. Si quieres cobrar en web hace falta otra pasarela (Stripe, etc.) y una cuenta/servidor.
- Google se queda con 15–30% de cada venta; hay que declarar compras integradas en la ficha de la tienda y cumplir las políticas de pago.
- Alternativa más simple: venta única de "Pack de mascotas" o anuncios recompensados.

## Anuncios con recompensa (skins y mascota Tizón)
Las skins distintas de Mateo y la mascota **Tizón** se desbloquean viendo 1 anuncio (`scripts/ads.gd`). Ahora es un anuncio **de prueba** de 5 s (`Ads.DEMO = true`). Para anuncios reales:
1. Crea una cuenta de **AdMob** y una app Android; crea un bloque de anuncio **Con recompensa** (te da un ID).
2. Instala el plugin de AdMob para Godot 4.3 (p. ej. *Poing Studios godot-admob*) en la plantilla Android.
3. Implementa `Ads._network_show(on_reward)` (cargar, mostrar y llamar a `on_reward` en el evento "user earned reward") y pon `DEMO := false`.
4. Usa IDs de prueba mientras desarrollas (no hagas clic en tus propios anuncios reales: AdMob puede suspender la cuenta). Hace falta política de privacidad y declarar anuncios en Play Console.
5. En la web (GitHub Pages) AdMob no funciona; allí queda el anuncio de prueba.
