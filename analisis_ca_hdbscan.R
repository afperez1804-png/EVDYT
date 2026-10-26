# =============================================================================
# Análisis de Correspondencia + HDBSCAN - Estadísticas NBA 2021-2022
# -----------------------------------------------------------------------------
# 1. AC con jugadores como filas y acciones de juego como columnas
#    (la posición se agrega como fila suplementaria para orientar el mapa).
# 2. HDBSCAN sobre las coordenadas de los jugadores en las primeras
#    dimensiones del AC para descubrir "arquetipos" de jugador.
# 3. Visualización con factoextra.
#
# Paquetes: FactoMineR, factoextra, dbscan, ggplot2
# =============================================================================

paquetes <- c("FactoMineR", "factoextra", "dbscan", "ggplot2")
faltan <- paquetes[!paquetes %in% rownames(installed.packages())]
if (length(faltan)) install.packages(faltan)

library(FactoMineR)
library(factoextra)
library(dbscan)
library(ggplot2)

dir.create("resultados_hdbscan", showWarnings = FALSE)
set.seed(2022)

# -----------------------------------------------------------------------------
# 1. Lectura y limpieza
# -----------------------------------------------------------------------------
regular <- read.csv2("datos/2021-2022 NBA Player Stats - Regular.csv",
                     dec = ".", encoding = "latin1", check.names = FALSE)
regular$Player <- iconv(regular$Player, "WINDOWS-1252", "UTF-8")

# Una fila por jugador (la "TOT" si fue traspasado) y posición principal
reg <- regular[order(regular$Rk, regular$Tm != "TOT"), ]
reg <- reg[!duplicated(reg$Rk), ]
reg$Pos <- factor(sub("-.*", "", reg$Pos), levels = c("PG", "SG", "SF", "PF", "C"))

# Solo jugadores con suficiente muestra: perfiles de pocos minutos son ruido
reg <- reg[reg$G >= 20 & reg$MP >= 15, ]
cat("Jugadores analizados:", nrow(reg), "\n")

# -----------------------------------------------------------------------------
# 2. Tabla de contingencia Jugador x Acción (totales = promedio x partidos)
# -----------------------------------------------------------------------------
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

tab <- round(sapply(acciones, function(v) reg[[v]] * reg$G))
colnames(tab) <- names(acciones)
rownames(tab) <- make.unique(reg$Player)

# Filas suplementarias: total por posición
tab_pos <- round(sapply(acciones, function(v) tapply(reg[[v]] * reg$G, reg$Pos, sum)))
colnames(tab_pos) <- names(acciones)

tab_ac <- rbind(tab, tab_pos)
n_jug <- nrow(tab)

chi <- chisq.test(tab)
cat("\n===== Chi-cuadrado Jugador x Acción =====\n")
print(chi)

# -----------------------------------------------------------------------------
# 3. Análisis de Correspondencia
# -----------------------------------------------------------------------------
ac <- CA(tab_ac, row.sup = (n_jug + 1):nrow(tab_ac), ncp = 5, graph = FALSE)

cat("\n===== Valores propios =====\n")
print(round(ac$eig, 4))

g <- fviz_screeplot(ac, addlabels = TRUE, ncp = 9) +
  labs(title = "Porcentaje de inercia por dimensión")
ggsave("resultados_hdbscan/01_scree.png", g, width = 8, height = 5, dpi = 120)

g <- fviz_ca_col(ac, col.col = "contrib", repel = TRUE,
                 gradient.cols = c("#00AFBB", "#E7B800", "#FC4E07")) +
  labs(title = "Acciones de juego (color = contribución)")
ggsave("resultados_hdbscan/02_columnas.png", g, width = 8, height = 6, dpi = 120)

g1 <- fviz_contrib(ac, choice = "col", axes = 1) + labs(title = "Contribución a la Dim 1")
g2 <- fviz_contrib(ac, choice = "col", axes = 2) + labs(title = "Contribución a la Dim 2")
ggsave("resultados_hdbscan/03_contrib_dim1.png", g1, width = 7, height = 5, dpi = 120)
ggsave("resultados_hdbscan/04_contrib_dim2.png", g2, width = 7, height = 5, dpi = 120)

g <- fviz_ca_row(ac, col.row = "cos2", geom = "point", alpha.row = 0.7,
                 gradient.cols = c("#00AFBB", "#E7B800", "#FC4E07")) +
  labs(title = "Jugadores (color = calidad de representación cos2)",
       subtitle = "Triángulos: posiciones (filas suplementarias)")
ggsave("resultados_hdbscan/05_jugadores_cos2.png", g, width = 9, height = 7, dpi = 120)

cat("\n===== Coordenadas de columnas (Dim 1-3) =====\n")
print(round(ac$col$coord[, 1:3], 3))
cat("\n===== Contribución de columnas (%) (Dim 1-3) =====\n")
print(round(ac$col$contrib[, 1:3], 2))
cat("\n===== Posiciones (suplementarias) =====\n")
print(round(ac$row.sup$coord[, 1:3], 3))

# -----------------------------------------------------------------------------
# 4. HDBSCAN sobre las coordenadas del AC
# -----------------------------------------------------------------------------
# Se usa el plano principal (Dim 1-2, ~65 % de la inercia). Con 3-4 dimensiones
# los puntos quedan demasiado dispersos y HDBSCAN marca casi todo como ruido.
k <- 2
coords <- ac$row$coord[, 1:k]
cat("\nDimensiones usadas en HDBSCAN:", k, "\n")

# minPts: tamaño mínimo de un grupo. Se revisa cómo cambia la solución.
cat("\n===== Sensibilidad a minPts =====\n")
sens <- t(sapply(5:25, function(m) {
  h <- hdbscan(coords, minPts = m)
  c(minPts = m, grupos = length(unique(h$cluster[h$cluster > 0])),
    ruido_pct = round(mean(h$cluster == 0) * 100, 1),
    estabilidad = round(mean(h$cluster_scores), 2))
}))
print(sens)

# minPts = 12 da la solución más interpretable (base, exterior, interior) y
# estable en el rango 11-14.
minPts <- 12
hdb <- hdbscan(coords, minPts = minPts)
print(hdb)

png("resultados_hdbscan/06_hdbscan_arbol.png", width = 900, height = 600)
plot(hdb, show_flat = TRUE)
mtext(paste("Árbol condensado - minPts =", minPts), side = 3, line = 0.3)
dev.off()

grupo <- factor(ifelse(hdb$cluster == 0, "Ruido", paste("Grupo", hdb$cluster)))

# fviz_cluster necesita una lista con $data y $cluster (se excluye el ruido)
en_grupo <- hdb$cluster > 0
obj_cluster <- list(data = coords[en_grupo, 1:2], cluster = hdb$cluster[en_grupo])
g <- fviz_cluster(obj_cluster, geom = "point", ellipse.type = "convex",
                  stand = FALSE, ggtheme = theme_minimal(),
                  main = "Grupos HDBSCAN en el plano del AC (sin puntos de ruido)") +
  labs(x = sprintf("Dim1 (%.1f%%)", ac$eig[1, 2]), y = sprintf("Dim2 (%.1f%%)", ac$eig[2, 2]))
ggsave("resultados_hdbscan/07_fviz_cluster.png", g, width = 9, height = 7, dpi = 120)

# Biplot: jugadores coloreados por grupo + acciones + posiciones
# (los puntos grandes son el centroide de cada grupo)
pos_sup <- data.frame(ac$row.sup$coord[, 1:2], etiqueta = rownames(ac$row.sup$coord))
g <- fviz_ca_biplot(ac, geom.row = "point", col.row = grupo, palette = "Dark2",
                    col.col = "black", col.row.sup = "red", repel = TRUE,
                    alpha.row = 0.8, pointsize = 1.8) +
  labs(title = "Biplot AC: jugadores por grupo HDBSCAN",
       subtitle = "Negro: acciones | Rojo: posiciones (suplementarias)",
       colour = "Grupo", shape = "Grupo") +
  ggrepel::geom_text_repel(data = pos_sup, aes(Dim.1, Dim.2, label = etiqueta),
                           inherit.aes = FALSE, colour = "red", fontface = "bold")
ggsave("resultados_hdbscan/08_biplot_grupos.png", g, width = 10, height = 8, dpi = 120)

# -----------------------------------------------------------------------------
# 5. Caracterización de los grupos
# -----------------------------------------------------------------------------
reg$Grupo <- grupo
reg$Prob  <- round(hdb$membership_prob, 2)
reg$Outlier <- round(hdb$outlier_scores, 2)

cat("\n===== Tamaño de los grupos =====\n")
print(table(reg$Grupo))

cat("\n===== Grupo x Posición =====\n")
print(table(reg$Grupo, reg$Pos))

cat("\n===== Perfil de acciones por grupo (%) =====\n")
perfil <- prop.table(rowsum(tab, as.character(grupo)), 1) * 100
print(round(perfil, 1))

cat("\n===== Promedios por partido por grupo =====\n")
prom <- aggregate(cbind(MP, PTS, `3P`, TRB, AST, STL, BLK) ~ Grupo, data = reg, mean)
prom[-1] <- round(prom[-1], 1)
print(prom)

cat("\n===== Jugadores más representativos de cada grupo (mayor prob. y minutos) =====\n")
for (gr in levels(grupo)) {
  d <- reg[reg$Grupo == gr, ]
  d <- d[order(-d$Prob, -d$MP), ]
  cat("\n", gr, ": ", paste(head(d$Player, 8), collapse = ", "), "\n", sep = "")
}

cat("\n===== Jugadores más atípicos (outlier score GLOSH) =====\n")
print(head(reg[order(-reg$Outlier), c("Player", "Pos", "Tm", "Grupo", "Outlier")], 10), row.names = FALSE)

write.csv(reg[, c("Player", "Pos", "Tm", "G", "MP", "PTS", "Grupo", "Prob", "Outlier")],
          "resultados_hdbscan/jugadores_grupos.csv", row.names = FALSE, fileEncoding = "UTF-8")
