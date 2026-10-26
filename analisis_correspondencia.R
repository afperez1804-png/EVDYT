# =============================================================================
# Análisis de Correspondencia (AC) - Estadísticas NBA 2021-2022
# -----------------------------------------------------------------------------
# Pregunta: ¿qué perfil estadístico (tiros, rebotes, asistencias, defensa...)
# caracteriza a cada posición y a cada equipo?
#
#   AC 1: Posición (filas) x Acciones de juego (columnas), temporada regular.
#         Las posiciones en Playoffs se proyectan como filas suplementarias.
#   AC 2: Equipo (filas) x Acciones de juego (columnas) -> estilos de juego.
#
# Paquetes: FactoMineR, factoextra, gplots
# =============================================================================

paquetes <- c("FactoMineR", "factoextra", "gplots", "ggplot2")
faltan <- paquetes[!paquetes %in% rownames(installed.packages())]
if (length(faltan)) install.packages(faltan)

library(FactoMineR)
library(factoextra)
library(gplots)
library(ggplot2)

dir.create("resultados", showWarnings = FALSE)

# -----------------------------------------------------------------------------
# 1. Lectura y limpieza
# -----------------------------------------------------------------------------
# Los CSV usan ";" como separador, "." como decimal y codificación Windows-1252.
leer_nba <- function(ruta) {
  d <- read.csv2(ruta, dec = ".", encoding = "latin1", check.names = FALSE)
  d$Player <- iconv(d$Player, "WINDOWS-1252", "UTF-8")
  d
}

regular  <- leer_nba("datos/2021-2022 NBA Player Stats - Regular.csv")
playoffs <- leer_nba("datos/2021-2022 NBA Player Stats - Playoffs.csv")

limpiar <- function(d) {
  # Jugadores traspasados aparecen varias veces (una fila por equipo + "TOT").
  # Para el análisis por posición nos quedamos con una sola fila por jugador:
  # la fila "TOT" si existe, si no la única fila.
  d <- d[order(d$Rk, d$Tm != "TOT"), ]
  d <- d[!duplicated(d$Rk), ]
  # Posiciones dobles ("SG-PG") -> posición principal ("SG")
  d$Pos <- factor(sub("-.*", "", d$Pos), levels = c("PG", "SG", "SF", "PF", "C"))
  d
}

reg <- limpiar(regular)
po  <- limpiar(playoffs)

# -----------------------------------------------------------------------------
# 2. Construcción de la tabla de contingencia
# -----------------------------------------------------------------------------
# Las estadísticas vienen "por partido"; multiplicando por G (partidos jugados)
# obtenemos el total de acciones de cada jugador, es decir, frecuencias.
acciones <- c(
  "Triples"      = "3P",
  "Dobles"       = "2P",
  "Tiros libres" = "FT",
  "Reb. ofens."  = "ORB",
  "Reb. defens." = "DRB",
  "Asistencias"  = "AST",
  "Robos"        = "STL",
  "Tapones"      = "BLK",
  "Perdidas"     = "TOV",
  "Faltas"       = "PF"
)

tabla_contingencia <- function(d, grupo) {
  totales <- sapply(acciones, function(v) tapply(d[[v]] * d$G, d[[grupo]], sum))
  colnames(totales) <- names(acciones)
  round(totales)
}

tab_pos    <- tabla_contingencia(reg, "Pos")
tab_pos_po <- tabla_contingencia(po,  "Pos")
rownames(tab_pos_po) <- paste(rownames(tab_pos_po), "(Playoffs)")

cat("\n===== Tabla de contingencia: Posición x Acción (temporada regular) =====\n")
print(tab_pos)

# Perfiles fila (% de cada acción dentro de cada posición)
cat("\n===== Perfiles fila (%) =====\n")
print(round(prop.table(tab_pos, 1) * 100, 1))

# -----------------------------------------------------------------------------
# 3. Prueba de independencia Chi-cuadrado
# -----------------------------------------------------------------------------
# H0: el tipo de acción es independiente de la posición.
chi_pos <- chisq.test(tab_pos)
cat("\n===== Prueba Chi-cuadrado (Posición x Acción) =====\n")
print(chi_pos)
# Inercia total = Chi2 / n
cat("Inercia total:", round(chi_pos$statistic / sum(tab_pos), 4), "\n")

png("resultados/01_balloonplot_posicion.png", width = 1000, height = 600)
balloonplot(as.table(tab_pos), main = "Posición x Acción (frecuencias)",
            xlab = "", ylab = "", label = FALSE, show.margins = FALSE)
dev.off()

# -----------------------------------------------------------------------------
# 4. AC 1: Posición x Acción (+ Playoffs como filas suplementarias)
# -----------------------------------------------------------------------------
tab_ac1 <- rbind(tab_pos, tab_pos_po)
n_activas <- nrow(tab_pos)
ac1 <- CA(tab_ac1, row.sup = (n_activas + 1):nrow(tab_ac1), graph = FALSE)

cat("\n===== AC 1: Valores propios (inercia por dimensión) =====\n")
print(round(ac1$eig, 4))

g <- fviz_screeplot(ac1, addlabels = TRUE) +
  geom_hline(yintercept = 100 / (min(dim(tab_pos)) - 1), linetype = 2, colour = "red") +
  labs(title = "AC 1 - Porcentaje de inercia por dimensión",
       subtitle = "Línea roja: inercia media esperada si todas las dimensiones pesaran igual")
ggsave("resultados/02_scree_posicion.png", g, width = 8, height = 5, dpi = 120)

g <- fviz_ca_biplot(ac1, repel = TRUE, col.row = "steelblue", col.col = "darkred",
                    col.row.sup = "darkgreen") +
  labs(title = "AC 1 - Biplot simétrico: Posición x Acción",
       subtitle = "Azul: posiciones (regular) | Verde: posiciones en Playoffs (suplementarias) | Rojo: acciones")
ggsave("resultados/03_biplot_posicion.png", g, width = 9, height = 7, dpi = 120)

# Contribuciones y calidad de representación (cos2)
cat("\n===== AC 1: Coordenadas de filas =====\n");      print(round(ac1$row$coord, 3))
cat("\n===== AC 1: Contribución de filas (%) =====\n");  print(round(ac1$row$contrib, 2))
cat("\n===== AC 1: cos2 de filas =====\n");             print(round(ac1$row$cos2, 3))
cat("\n===== AC 1: Coordenadas de columnas =====\n");   print(round(ac1$col$coord, 3))
cat("\n===== AC 1: Contribución de columnas (%) =====\n"); print(round(ac1$col$contrib, 2))
cat("\n===== AC 1: cos2 de columnas =====\n");          print(round(ac1$col$cos2, 3))
cat("\n===== AC 1: Filas suplementarias (Playoffs) =====\n"); print(round(ac1$row.sup$coord, 3))

g1 <- fviz_contrib(ac1, choice = "col", axes = 1) + labs(title = "Contribución de acciones a la Dim 1")
g2 <- fviz_contrib(ac1, choice = "col", axes = 2) + labs(title = "Contribución de acciones a la Dim 2")
ggsave("resultados/04_contrib_dim1_posicion.png", g1, width = 7, height = 5, dpi = 120)
ggsave("resultados/05_contrib_dim2_posicion.png", g2, width = 7, height = 5, dpi = 120)

# -----------------------------------------------------------------------------
# 5. AC 2: Equipo x Acción (estilos de juego por equipo)
# -----------------------------------------------------------------------------
# Aquí se usan las filas por equipo (se excluye "TOT" para no duplicar totales).
reg_eq <- regular[regular$Tm != "TOT", ]
tab_eq <- tabla_contingencia(reg_eq, "Tm")

chi_eq <- chisq.test(tab_eq)
cat("\n===== Prueba Chi-cuadrado (Equipo x Acción) =====\n")
print(chi_eq)

ac2 <- CA(tab_eq, graph = FALSE)
cat("\n===== AC 2: Valores propios =====\n")
print(round(ac2$eig, 4))

g <- fviz_screeplot(ac2, addlabels = TRUE) + labs(title = "AC 2 - Porcentaje de inercia por dimensión")
ggsave("resultados/06_scree_equipo.png", g, width = 8, height = 5, dpi = 120)

g <- fviz_ca_biplot(ac2, repel = TRUE, col.row = "steelblue", col.col = "darkred") +
  labs(title = "AC 2 - Biplot simétrico: Equipo x Acción")
ggsave("resultados/07_biplot_equipo.png", g, width = 10, height = 8, dpi = 120)

cat("\n===== AC 2: Contribución de columnas (%) =====\n"); print(round(ac2$col$contrib[, 1:2], 2))
cat("\n===== AC 2: Equipos con mayor contribución a Dim 1 y Dim 2 =====\n")
print(round(head(ac2$row$contrib[order(-ac2$row$contrib[, 1]), 1:2], 8), 2))
print(round(head(ac2$row$contrib[order(-ac2$row$contrib[, 2]), 1:2], 8), 2))
cat("\n===== AC 2: Coordenadas de equipos (Dim 1-2) =====\n")
print(round(ac2$row$coord[order(ac2$row$coord[, 1]), 1:2], 3))
