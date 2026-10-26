# Análisis de Correspondencia en R – Estadísticas NBA 2021-2022

## Contenido

| Archivo | Descripción |
|---|---|
| `datos/` | CSV originales (temporada regular y playoffs). Separador `;`, decimal `.`, codificación Windows-1252. |
| `analisis_correspondencia.R` | Script completo del análisis. |
| `resultados/` | Gráficos (`.png`) y salida de consola (`salida_consola.txt`). |

Ejecutar desde la carpeta del proyecto:

```r
source("analisis_correspondencia.R")
```

Paquetes: `FactoMineR`, `factoextra`, `gplots`, `ggplot2` (el script los instala si faltan).

## Planteamiento

El análisis de correspondencia trabaja sobre una **tabla de contingencia** (frecuencias). Los datos
vienen como promedios por partido, así que se multiplicó cada estadística por los partidos jugados (`G`)
para obtener el **total de acciones** de cada jugador y luego se sumó por grupo.

Preparación:
- Los jugadores traspasados aparecen varias veces (una fila por equipo y una fila `TOT`). Para el
  análisis por posición se usa una sola fila por jugador (la `TOT`); para el análisis por equipo se
  usan las filas de cada equipo y se descarta `TOT`.
- Las posiciones dobles (`SG-PG`, `C-PF`, …) se reducen a la posición principal → PG, SG, SF, PF, C.
- Acciones (columnas): triples, dobles, tiros libres, rebotes ofensivos y defensivos, asistencias,
  robos, tapones, pérdidas y faltas.

Se hacen dos análisis:
1. **AC 1 – Posición × Acción** (temporada regular). Las posiciones en *playoffs* se proyectan como
   **filas suplementarias** (no influyen en los ejes, solo se ubican en el mapa).
2. **AC 2 – Equipo × Acción** (30 equipos), para ver estilos de juego.

## Resultados AC 1: Posición × Acción

**Prueba Chi-cuadrado:** χ² = 26 074, gl = 36, p < 2.2e-16 → se rechaza la independencia: el tipo
de acción depende de la posición. Inercia total = 0.0617.

**Inercia por dimensión:**

| Dimensión | Valor propio | % inercia | % acumulado |
|---|---|---|---|
| 1 | 0.0535 | 86.8 % | 86.8 % |
| 2 | 0.0076 | 12.3 % | 99.1 % |

Con dos dimensiones se explica el **99 %** de la asociación, así que el mapa plano es prácticamente
exacto (todos los cos² en el plano 1-2 son > 0.94).

![Biplot posición](resultados/03_biplot_posicion.png)

**Dimensión 1 (86.8 %) – "juego exterior vs. juego interior".**
- Lado negativo: *Asistencias* (32 % de contribución), *Triples* (15 %), robos y pérdidas → **PG** y **SG**.
- Lado positivo: *Rebotes ofensivos* (25 %), *Rebotes defensivos* (12 %), *Tapones* (9 %) → **C** y **PF**.
- **C** (48 %) y **PG** (34 %) son las posiciones que definen el eje; SF queda en el centro (cos² en Dim 1 = 0.01).

**Dimensión 2 (12.3 %) – "tirador vs. organizador".**
- Separa *Triples* (50 % de contribución, arriba) de *Asistencias* (35 %, abajo).
- Distingue al **SG** (más triples y robos) del **PG** (más asistencias y pérdidas). El **SF** está
  representado casi solo en esta dimensión (cos² = 0.91): es un perfil intermedio con algo de sesgo
  hacia el tiro exterior.

**Perfiles fila destacados (%)**: el 23.5 % de las acciones de los PG son asistencias (8.5 % en C);
los triples son el 11.2 % de las acciones de los SG y solo el 2.4 % de las de los C; los rebotes
ofensivos son el 10.8 % en C frente al 2.8 % en PG.

**Playoffs (suplementarias):** cada posición en playoffs queda junto a su homóloga de temporada
regular, es decir, los roles se mantienen. Los PG y SG en playoffs se desplazan ligeramente hacia
el centro (perfil algo menos extremo), mientras que los C conservan exactamente su posición.

**Tiros libres** y **dobles** están cerca del origen: se reparten de forma similar entre posiciones y
no discriminan.

## Resultados AC 2: Equipo × Acción

**Prueba Chi-cuadrado:** χ² = 1 963, gl = 261, p < 2.2e-16. Es significativo por el tamaño muestral
enorme, pero la **inercia total es muy baja (≈ 0.005, unas 13 veces menor que en AC 1)**: los equipos
se parecen mucho entre sí; las diferencias de estilo existen pero son sutiles. Las dos primeras
dimensiones explican el 54 % (31 % + 23.4 %).

![Biplot equipo](resultados/07_biplot_equipo.png)

- **Dim 1 (31 %) – triples vs. dobles:** *Dobles* (40 %) y *Triples* (34 %). A la izquierda los
  equipos de juego de media distancia/pintura: **SAS, MEM, PHO, CHI, WAS**. A la derecha los más
  volcados al triple: **HOU, UTA, NYK, MIA, GSW**.
- **Dim 2 (23.4 %) – rebote ofensivo y defensa activa:** dominada por *Rebotes ofensivos* (57 %),
  junto a robos y tapones. Arriba destacan **TOR** y **MEM** (equipos de segundas oportunidades y
  mucha actividad defensiva); abajo **DEN, CHI, PHO**, con más peso relativo de asistencias.

## Gráficos generados

| Archivo | Contenido |
|---|---|
| `01_balloonplot_posicion.png` | Tabla de contingencia Posición × Acción |
| `02_scree_posicion.png` | Inercia por dimensión (AC 1) |
| `03_biplot_posicion.png` | Biplot simétrico AC 1 con playoffs suplementarios |
| `04/05_contrib_dim*_posicion.png` | Contribución de las acciones a Dim 1 y Dim 2 |
| `06_scree_equipo.png` | Inercia por dimensión (AC 2) |
| `07_biplot_equipo.png` | Biplot simétrico AC 2 |

## Notas

- En el biplot simétrico las distancias **fila-fila** y **columna-columna** se interpretan
  directamente; la cercanía fila-columna indica asociación de forma aproximada (dirección desde el origen).
- Los totales son aproximados: los promedios vienen redondeados a un decimal antes de multiplicar por `G`.
