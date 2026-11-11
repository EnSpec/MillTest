##################################################
# Title: Particle-size distribution figure (manuscript Fig. 5)
# Project: Mill Test 2024
# Volume-weighted particle-size distributions (LS 13 320) of oven-dried
# material, mean across the individuals of each species, per milling
# treatment. Input: per-bin exports in particle_size/data/distribution/
# <date>_Zach/ (columns um, Volume, Treatment, Type, Sample); the Jun13
# pilot folder is excluded. Species from field_data/sample_info.csv.
# Output: derived/particle_size/Figure5_particle_size_distributions.png
##################################################
library(tidyverse)
data_root <- Sys.getenv("MILL24_DATA_ROOT", unset = "/Volumes/Enspec/projects/Mill24")
out_dir <- file.path(data_root, "derived", "particle_size")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

files <- list.files(file.path(data_root, "particle_size", "data", "distribution"),
                    pattern = "\\.csv$", recursive = TRUE, full.names = TRUE)
files <- files[!grepl("/Jun13/", files)]
stopifnot(!any(duplicated(basename(files))))
bins <- map_dfr(files, \(f) read_csv(f, show_col_types = FALSE) |> mutate(file = basename(f)))

si <- read_csv(file.path(data_root, "field_data", "sample_info.csv"), show_col_types = FALSE) |>
  transmute(Sample = Sample_ID, Species_Code, Species)
trees <- bins |> left_join(si, by = "Sample") |>
  mutate(Sci = str_remove(str_extract(Species, "\\(.*\\)"), "[()]") |> str_remove("\\)$"),
         Sci = str_remove(Sci, "^\\("))
d <- trees |>
  group_by(Sci, Treatment, um) |>
  summarise(Volume = mean(Volume), n_trees = n_distinct(Sample), .groups = "drop")
# Species shown in the manuscript figure (n >= 2 trees per species; Rhamnus
# cathartica (n = 2) and the three single-tree species are not shown -- the
# legend's "five of the 22 measurements are not shown").
show_spp <- c("Acer saccharum", "Celtis occidentalis", "Quercus rubra",
              "Picea abies", "Pinus strobus", "Juniperus virginiana")
print(d |> distinct(Sci, Treatment, n_trees) |> arrange(Sci, Treatment), n = 60)
d <- d |> filter(Sci %in% show_spp)
trees <- trees |> filter(Sci %in% show_spp)
write_csv(d, file.path(out_dir, "particle_size_species_mean_distributions.csv"))

# One panel per species (shared y axis, so heights are comparable and rows never overlap).
# Thick lines = species mean; thin lines = individual trees.
d <- d |> mutate(Sci = factor(Sci, show_spp),
                 Treatment = factor(Treatment, c("Ball", "Fine", "Twenty")))
trees <- trees |> mutate(Sci = factor(Sci, show_spp),
                         Treatment = factor(Treatment, c("Ball", "Fine", "Twenty")))
p <- ggplot(d, aes(um, Volume, colour = Treatment)) +
  geom_line(data = trees, aes(group = interaction(Sample, Treatment)),
            linewidth = 0.35, alpha = 0.55) +
  geom_line(linewidth = 1.2) +
  facet_grid(Sci ~ ., switch = "y") +
  scale_colour_brewer(palette = "Dark2") +
  coord_cartesian(xlim = c(0, 2000)) +
  labs(x = expression("Particle size ("*mu*"m)"), y = "Volume (%)") +
  theme_bw(base_size = 14) +
  theme(strip.placement = "outside",
        strip.background = element_blank(),
        strip.text.y.left = element_text(face = "italic", angle = 0, hjust = 1, size = 12),
        panel.spacing.y = unit(0.4, "lines"))
ggsave(file.path(out_dir, "Figure5_particle_size_distributions.png"), p,
       width = 10, height = 8, dpi = 300)
